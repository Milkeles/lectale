import { isSafeRepoPath } from "../contract/repo-path";
import { readBoundedBody } from "../net/bounded-body";
import { fetchGitHub } from "../net/fetch";
import {
  commitShaPattern, GitHubReadError, isRepoId,
  type GitHubDirectoryEntry, type GitHubReader, type GitHubRepository,
} from "./reader";

const REST = "https://api.github.com";
const RAW = "https://raw.githubusercontent.com";
const METADATA_BYTES = 128 * 1024;
const DIRECTORY_BYTES = 2 * 1024 * 1024;
const MAX_FALLBACK_SECONDS = 86_400;

class AddressUnavailable extends GitHubReadError {
  constructor() {
    super("not_found");
  }
}

interface MetadataOptions {
  accept?: string;
  repositoryRedirect?: boolean;
  publicRepoId?: number;
}

function repositoryPath(owner: string, name: string): string {
  if (/^[A-Za-z0-9-]{1,39}$/u.exec(owner)?.[0] !== owner || /^[A-Za-z0-9_.-]{1,100}$/u.exec(name)?.[0] !== name
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
  if (isPrivate || (visibility !== undefined && visibility !== "public")) {
    throw new GitHubReadError("not_found");
  }
  return { id, owner: login, name, defaultBranch: default_branch, private: false };
}

function retryDelay(headers: Headers): number | undefined {
  const retryAfter = headers.get("Retry-After");
  if (retryAfter !== null) {
    const seconds = /^\d+$/u.test(retryAfter) ? Number(retryAfter) : (Date.parse(retryAfter) - Date.now()) / 1_000;
    if (Number.isFinite(seconds)) return Math.max(1, Math.ceil(seconds));
  }
  const reset = headers.get("X-RateLimit-Reset");
  if (headers.get("X-RateLimit-Remaining") === "0" && reset && /^\d+$/u.test(reset)) {
    const seconds = Number(reset) - Date.now() / 1_000;
    if (Number.isFinite(seconds)) return Math.max(1, Math.ceil(seconds));
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
  if (status === 403 || status === 404) {
    // Keep denials on the same bounded read path. Secondary limits can be body-only (ERR-004).
    const bytes = await readBoundedBody(response.body, 4096).catch(() => undefined);
    if (status === 403 && bytes && /secondary rate limit/iu.test(new TextDecoder().decode(bytes))) {
      throw new GitHubReadError("rate_limited", 60);
    }
    throw new AddressUnavailable();
  } else {
    void response.body?.cancel().catch(() => undefined);
  }
  const unavailable = status === 409 || status === 451;
  throw new GitHubReadError(unavailable ? "not_found" : "upstream");
}

async function request(address: string, options: Parameters<typeof fetchGitHub>[1]): Promise<Response> {
  try {
    return await fetchGitHub(address, options);
  } catch {
    throw new GitHubReadError("upstream");
  }
}

async function readText(response: Response, cap: number): Promise<string> {
  try {
    const bytes = await readBoundedBody(response.body, cap);
    if (bytes) return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes);
  } catch {
    // Provider bodies and decoder errors are never reflected to the client.
  }
  throw new GitHubReadError("upstream");
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new GitHubReadError("upstream");
  }
}

/** What the reader needs to know about its credential's scope (V4-SEC-04). */
export interface TokenScope {
  /** The only repository the token can read. Its visibility is re-checked after each read. */
  repositoryId?: number | undefined;
  /** Called with a token that GitHub refused with 401, so the provider can drop it. */
  rejected?: (token: string) => void;
  /** Pauses anonymous retries after one hit a rate limit. Shared across requests. */
  fallbackCooldown?: { until: number };
}

/** Reads public REST metadata and anonymous, SHA-pinned raw files (V4-CORE-01, ADR-0008). */
export class GitHubRestReader implements GitHubReader {
  constructor(
    private readonly tokenProvider: () => Promise<string | undefined> = async () => undefined,
    private readonly scope: TokenScope = {},
  ) {}

  private readonly ownCooldown = { until: 0 };

  private get fallbackCooldown(): { until: number } {
    return this.scope.fallbackCooldown ?? this.ownCooldown;
  }

  /**
   * The token was rejected and the anonymous retry is paused, so the
   * resource's state is unknown. A retryable 429 says so honestly and answers a private
   * and a missing repository alike (SEC-005).
   */
  private fallbackPaused(): GitHubReadError {
    const remaining = Math.max(1, Math.ceil((this.fallbackCooldown.until - Date.now()) / 1_000));
    return new GitHubReadError("rate_limited", remaining, "fallback");
  }

  private async metadata(
    path: string, cap = METADATA_BYTES, { publicRepoId, ...options }: MetadataOptions = {},
  ): Promise<string> {
    const token = await this.tokenProvider();
    // The token is scoped to one repository, which can turn private within
    // the hour, so its visibility is confirmed before the read: a private
    // listing must not even be fetched or size-checked. Other repositories
    // are unreadable to the token while private.
    if (token && publicRepoId !== undefined && publicRepoId === this.scope.repositoryId) {
      await this.resolveRepositoryById(publicRepoId);
    }
    const url = `${REST}${path}`;
    const response = await request(url, token ? { ...options, token } : options);
    if (response.status === 200) return readText(response, cap);
    // A scoped token reads public repositories outside its scope (HTTP 200 in
    // the 2026-11-23 deploy check), so its 403 or 404 is GitHub's real answer,
    // the same an anonymous read would get. Only a rejected token (401) falls
    // back to an anonymous read.
    if (!token || response.status !== 401) return readFailure(response);
    void response.body?.cancel().catch(() => undefined);
    this.scope.rejected?.(token);
    if (this.fallbackCooldown.until > Date.now()) throw this.fallbackPaused();
    const anonymous = await request(url, options);
    if (anonymous.status === 200) return readText(anonymous, cap);
    try {
      return await readFailure(anonymous);
    } catch (error) {
      if (!(error instanceof GitHubReadError) || error.kind !== "rate_limited") throw error;
      // Anonymous budget is shared by every visitor. Pausing only this path
      // keeps token reads running and stops one flood of missing names from
      // opening the global cooldown (V4-CACHE-05).
      const seconds = Math.max(1, Math.min(error.retryAfterSeconds ?? 60, MAX_FALLBACK_SECONDS));
      this.fallbackCooldown.until = Math.max(this.fallbackCooldown.until, Date.now() + seconds * 1_000);
      throw this.fallbackPaused();
    }
  }

  async resolveRepository(owner: string, name: string): Promise<GitHubRepository> {
    return parseRepository(parseJson(await this.metadata(`/repos/${repositoryPath(owner, name)}`,
      METADATA_BYTES, { repositoryRedirect: true })));
  }

  async resolveRepositoryById(id: number): Promise<GitHubRepository> {
    if (!isRepoId(id)) throw new GitHubReadError("not_found");
    const repository = parseRepository(parseJson(await this.metadata(`/repositories/${id}`)));
    if (repository.id !== id) throw new GitHubReadError("not_found");
    console.info("GitHub preview metadata", { operation: "repository", address: "id" });
    return repository;
  }

  private async confirmName({ id, owner, name }: GitHubRepository): Promise<void> {
    try {
      const current = await this.resolveRepository(owner, name);
      if (current.id === id && current.owner.toLowerCase() === owner.toLowerCase()
          && current.name.toLowerCase() === name.toLowerCase()) return;
    } catch (error) {
      if (error instanceof GitHubReadError && error.kind === "rate_limited") throw error;
    }
    throw new GitHubReadError("repo_changed");
  }

  private async repositoryMetadata(
    repository: GitHubRepository, operation: string, suffix: string, cap?: number, accept?: string,
  ): Promise<string> {
    if (!isRepoId(repository.id)) throw new GitHubReadError("not_found");
    const options = accept === undefined ? {} : { accept };
    try {
      const body = await this.metadata(`/repositories/${repository.id}/${suffix}`, cap, {
        ...options, publicRepoId: repository.id,
      });
      console.info("GitHub preview metadata", { operation, address: "id" });
      return body;
    } catch (error) {
      if (!(error instanceof AddressUnavailable)) throw error;
    }

    await this.confirmName(repository);
    const { owner, name } = repository;
    let body: string;
    try {
      body = await this.metadata(`/repos/${repositoryPath(owner, name)}/${suffix}`, cap, options);
    } catch (error) {
      if (error instanceof GitHubReadError && error.kind !== "rate_limited") await this.confirmName(repository);
      throw error;
    }
    await this.confirmName(repository);
    console.info("GitHub preview metadata", { operation, address: "name-fallback" });
    return body;
  }

  async headCommit(repository: GitHubRepository): Promise<string> {
    const sha = (await this.repositoryMetadata(repository, "head", "commits/HEAD",
      128, "application/vnd.github.sha")).trim();
    if (!commitShaPattern.test(sha)) throw new GitHubReadError("upstream");
    return sha;
  }

  async isReachable(repository: GitHubRepository, sha: string, defaultHead: string): Promise<boolean> {
    if (!commitShaPattern.test(sha) || !commitShaPattern.test(defaultHead)) throw new GitHubReadError("not_found");
    // Comparing against the resolved default-branch tip avoids ref-name
    // ambiguity. GitHub returns file diffs only on the first page.
    const compare = `${defaultHead}...${sha}?per_page=1&page=2`;
    const payload = parseJson(await this.repositoryMetadata(repository, "compare", `compare/${compare}`));
    const status = (payload as { status?: unknown } | null)?.status;
    if (status === "behind" || status === "identical") return true;
    if (status === "ahead" || status === "diverged") return false;
    throw new GitHubReadError("upstream");
  }

  async listDirectory(repository: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[]> {
    if (!commitShaPattern.test(sha) || (path !== "" && !isSafeRepoPath(path))) {
      throw new GitHubReadError("not_found");
    }
    const payload = parseJson(await this.repositoryMetadata(
      repository, "contents", `contents/${path}?ref=${sha}`, DIRECTORY_BYTES));
    if (!Array.isArray(payload)) throw new GitHubReadError("not_found");
    if (payload.length > 1_000) throw new GitHubReadError("upstream");
    const entries: GitHubDirectoryEntry[] = [];
    for (const item of payload as unknown[]) {
      if (typeof item !== "object" || item === null) throw new GitHubReadError("upstream");
      const { name: entryName, type, size, path: entryPath, download_url, submodule_git_url } = item as Record<string, unknown>;
      if (typeof entryName !== "string" || entryName.includes("/") || !isSafeRepoPath(entryName)
          || entryPath !== (path ? `${path}/${entryName}` : entryName)
          || !isSafeRepoPath(entryPath) || submodule_git_url != null) continue;
      if (type === "dir") entries.push({ name: entryName, type: "directory", size: 0 });
      if (type === "file" && typeof download_url === "string" && (isRepoId(size) || size === 0)) {
        entries.push({ name: entryName, type: "file", size });
      }
    }
    return entries;
  }

  async openFile(owner: string, name: string, sha: string, path: string, range?: string): Promise<Response> {
    if (!commitShaPattern.test(sha) || !isSafeRepoPath(path)) throw new GitHubReadError("not_found");
    const response = await request(`${RAW}/${repositoryPath(owner, name)}/${sha}/${path}`,
      range === undefined ? {} : { range });
    if (response.status === 200 || response.status === 206 || response.status === 416) return response;
    return readFailure(response);
  }
}
