import { readBoundedBody } from "../net/bounded-body";
import { fetchGitHub } from "../net/fetch";
import {
  commitShaPattern, GitHubReadError, isRepoId,
  type GitHubReader, type GitHubRepository, type GitHubTree, type GitHubTreeEntry,
} from "./reader";

const REST = "https://api.github.com";
const RAW = "https://raw.githubusercontent.com";

function repositoryPath(owner: string, name: string): string {
  if (!/^[A-Za-z0-9-]+$/u.test(owner) || !/^[A-Za-z0-9_.-]+$/u.test(name)
      || name === "." || name === "..") {
    throw new GitHubReadError("upstream");
  }
  return `${owner}/${name}`;
}

function parseRepository(payload: unknown): GitHubRepository {
  if (typeof payload !== "object" || payload === null) throw new GitHubReadError("upstream");
  const { id, name, default_branch, owner, private: isPrivate, visibility } = payload as Record<string, unknown>;
  const login: unknown = (owner as { login?: unknown } | null | undefined)?.login;
  if (!isRepoId(id) || typeof name !== "string" || typeof default_branch !== "string"
      || typeof login !== "string" || typeof isPrivate !== "boolean") {
    throw new GitHubReadError("upstream");
  }
  repositoryPath(login, name);
  return {
    id, owner: login, name, defaultBranch: default_branch,
    private: isPrivate || (visibility !== undefined && visibility !== "public"),
  };
}

function retryDelay(headers: Headers): number | undefined {
  const retryAfter = headers.get("Retry-After");
  if (retryAfter !== null) {
    const seconds = /^\d+$/u.test(retryAfter) ? Number(retryAfter) : (Date.parse(retryAfter) - Date.now()) / 1_000;
    if (Number.isFinite(seconds)) return Math.max(0, Math.ceil(seconds));
  }
  const reset = headers.get("X-RateLimit-Reset");
  if (headers.get("X-RateLimit-Remaining") === "0" && reset && /^\d+$/u.test(reset)) {
    const seconds = Number(reset) - Date.now() / 1_000;
    if (Number.isFinite(seconds)) return Math.max(0, Math.ceil(seconds));
  }
}

async function readFailure(response: Response): Promise<never> {
  const { status, headers } = response;
  const throttled = status === 429 || (status === 403
    && (headers.has("Retry-After") || headers.get("X-RateLimit-Remaining") === "0"));
  if (throttled) {
    void response.body?.cancel().catch(() => undefined);
    throw new GitHubReadError("rate_limited", retryDelay(headers) ?? 60);
  }
  if (status === 403) {
    // GitHub can report secondary throttling in the body alone (ERR-004).
    const bytes = await readBoundedBody(response.body, 4096);
    if (bytes && /secondary rate limit/iu.test(new TextDecoder().decode(bytes))) {
      throw new GitHubReadError("rate_limited", 60);
    }
  } else {
    void response.body?.cancel().catch(() => undefined);
  }
  throw new GitHubReadError(status === 403 || status === 404 || status === 451 ? "not_found" : "upstream");
}

async function request(address: string, options: Parameters<typeof fetchGitHub>[1]): Promise<Response> {
  try {
    return await fetchGitHub(address, options);
  } catch {
    throw new GitHubReadError("upstream");
  }
}

/** Reads GitHub REST metadata and unauthenticated, SHA-pinned raw files (ADR-0008). */
export class GitHubRestReader implements GitHubReader {
  constructor(private readonly tokenProvider: () => Promise<string | undefined> = async () => undefined) {}

  private async metadata(path: string): Promise<unknown> {
    const token = await this.tokenProvider();
    const response = await request(`${REST}${path}`, token ? { token } : {});
    if (response.status !== 200) return readFailure(response);
    try {
      return await response.json();
    } catch {
      throw new GitHubReadError("upstream");
    }
  }

  async resolveRepository(owner: string, name: string): Promise<GitHubRepository> {
    return parseRepository(await this.metadata(`/repos/${repositoryPath(owner, name)}`));
  }

  async resolveRepositoryById(id: number): Promise<GitHubRepository> {
    if (!isRepoId(id)) throw new GitHubReadError("not_found");
    const repository = parseRepository(await this.metadata(`/repositories/${id}`));
    if (repository.id !== id) throw new GitHubReadError("not_found");
    return repository;
  }

  async headCommit(owner: string, name: string): Promise<string> {
    const payload = await this.metadata(`/repos/${repositoryPath(owner, name)}/commits/HEAD`);
    const sha = (payload as { sha?: unknown } | null)?.sha;
    if (typeof sha !== "string" || !commitShaPattern.test(sha)) throw new GitHubReadError("upstream");
    return sha;
  }

  async tree(owner: string, name: string, sha: string): Promise<GitHubTree> {
    if (!commitShaPattern.test(sha)) throw new GitHubReadError("not_found");
    const payload = await this.metadata(`/repos/${repositoryPath(owner, name)}/git/trees/${sha}?recursive=1`);
    const { tree, truncated } = (payload ?? {}) as { tree?: unknown; truncated?: unknown };
    if (!Array.isArray(tree) || typeof truncated !== "boolean") throw new GitHubReadError("upstream");
    const entries: GitHubTreeEntry[] = [];
    for (const item of tree as unknown[]) {
      if (typeof item !== "object" || item === null) throw new GitHubReadError("upstream");
      const { path, type, size, mode } = item as Record<string, unknown>;
      if (typeof path !== "string" || typeof mode !== "string"
          || (type !== "blob" && type !== "tree" && type !== "commit")) {
        throw new GitHubReadError("upstream");
      }
      entries.push({ path, type, mode, ...(isRepoId(size) || size === 0 ? { size } : {}) });
    }
    return { entries, truncated };
  }

  async openFile(owner: string, name: string, sha: string, path: string, range?: string): Promise<Response> {
    if (!commitShaPattern.test(sha) || !/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*$/u.test(path)
        || path.split("/").some((segment) => segment.endsWith(".") || (segment.startsWith(".") && segment !== ".well-known"))) {
      throw new GitHubReadError("not_found");
    }
    const response = await request(`${RAW}/${repositoryPath(owner, name)}/${sha}/${path}`,
      range === undefined ? {} : { range });
    if (response.status === 200 || response.status === 206 || response.status === 416) return response;
    return readFailure(response);
  }
}
