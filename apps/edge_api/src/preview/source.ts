import {
  commitShaPattern, GitHubReadError, type GitHubDirectoryEntry, type GitHubReader, type GitHubRepository,
} from "../github/reader";
import { NEGATIVE_TTL, PINNED_TTL, type PreviewStore, VISIBILITY_TTL } from "./cache";

const COOLDOWN_KEY = "github-cooldown:v2";
const MAX_RETRY_SECONDS = 86_400;

function requirePublic(repository: GitHubRepository): GitHubRepository {
  if (repository.private !== false) throw new GitHubReadError("not_found");
  return repository;
}

/** A request's public GitHub lookups, with visibility, namespace and SHA binding (SEC-005, ADR-0008). */
export class PreviewSource {
  constructor(
    readonly store: PreviewStore,
    private readonly reader: GitHubReader,
    private readonly cooldown: { until: number },
  ) {}

  async assertAvailable(): Promise<void> {
    const stored = await this.store.get<number>(COOLDOWN_KEY);
    const until = Math.max(this.cooldown.until, stored ?? 0);
    const remaining = Math.ceil((until - Date.now()) / 1_000);
    if (remaining > 0) throw new GitHubReadError("rate_limited", remaining);
  }

  private async call<T>(operation: () => Promise<T>): Promise<T> {
    await this.assertAvailable();
    try {
      return await operation();
    } catch (error) {
      if (error instanceof GitHubReadError && error.kind === "rate_limited") {
        const seconds = Math.max(1, Math.min(error.retryAfterSeconds ?? 60, MAX_RETRY_SECONDS));
        this.cooldown.until = Math.max(this.cooldown.until, Date.now() + seconds * 1_000);
        const remaining = Math.ceil((this.cooldown.until - Date.now()) / 1_000);
        await this.store.save(COOLDOWN_KEY, this.cooldown.until, remaining);
        throw new GitHubReadError("rate_limited", remaining);
      }
      throw error;
    }
  }

  private async confirmName(repository: GitHubRepository): Promise<void> {
    try {
      const current = requirePublic(await this.call(() => this.reader.resolveRepository(repository.owner, repository.name)));
      if (current.id === repository.id && current.owner.toLowerCase() === repository.owner.toLowerCase()
          && current.name.toLowerCase() === repository.name.toLowerCase()) return;
    } catch (error) {
      if (!(error instanceof GitHubReadError) || error.kind === "rate_limited") throw error;
      if (error.kind !== "not_found") throw new GitHubReadError("repo_changed");
    }
    await Promise.all([
      this.store.delete(`public-repo:v2:${repository.id}`),
      this.store.delete(`repo-preview:v2:${repository.owner.toLowerCase()}:${repository.name.toLowerCase()}`),
    ]);
    throw new GitHubReadError("repo_changed");
  }

  private async namedRead<T>(
    repository: GitHubRepository,
    operation: () => Promise<T>,
    discard?: (value: T) => void,
  ): Promise<T> {
    let value: T;
    try {
      value = await this.call(operation);
    } catch (error) {
      // Cache failures from a name-scoped read only after ruling out a name change.
      if (error instanceof GitHubReadError && (error.kind === "not_found" || error.kind === "upstream")) {
        await this.confirmName(repository);
      }
      throw error;
    }
    try {
      await this.confirmName(repository);
    } catch (error) {
      discard?.(value);
      throw error;
    }
    return value;
  }

  repositoryByName(owner: string, name: string): Promise<GitHubRepository> {
    return this.store.cached(`repo-preview:v2:${owner}:${name}`, VISIBILITY_TTL, async () =>
      requirePublic(await this.call(() => this.reader.resolveRepository(owner, name))));
  }

  repositoryById(repoId: number): Promise<GitHubRepository> {
    return this.store.cached(`public-repo:v2:${repoId}`, VISIBILITY_TTL, async () => {
      const repository = requirePublic(await this.call(() => this.reader.resolveRepositoryById(repoId)));
      if (repository.id !== repoId) throw new GitHubReadError("not_found");
      return repository;
    });
  }

  head(repository: GitHubRepository): Promise<string> {
    const { id, owner, name } = repository;
    return this.store.cached(`repo-head:v2:${id}:${owner.toLowerCase()}:${name.toLowerCase()}`, VISIBILITY_TTL, async () => {
      const sha = await this.namedRead(repository, () => this.reader.headCommit(repository));
      if (!commitShaPattern.test(sha)) throw new GitHubReadError("upstream");
      return sha;
    });
  }

  recordPin(repoId: number, sha: string): Promise<void> {
    return this.store.save(`import-pin:v2:${repoId}:${sha}`, true, PINNED_TTL);
  }

  async requirePin(repository: GitHubRepository, sha: string): Promise<void> {
    if (await this.store.get<boolean>(`import-pin:v2:${repository.id}:${sha}`)) return;
    const reachable = await this.store.cached(`reachable:v2:${repository.id}:${sha}`, PINNED_TTL, async () => {
      return this.namedRead(repository, async () => {
        // A cached import head can be older than a force push. Take a fresh
        // snapshot for a SHA that has no import pin or comparison verdict.
        const { id, owner, name } = repository;
        const coordinates = `${id}:${owner.toLowerCase()}:${name.toLowerCase()}`;
        const head = await this.store.once(`compare-head:v2:${coordinates}`, () => this.reader.headCommit(repository));
        return this.call(() => this.reader.isReachable(repository, sha, head));
      });
    });
    if (!reachable) throw new GitHubReadError("not_found");
  }

  directory(repository: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[]> {
    return this.store.cached(`directory:v2:${repository.id}:${sha}:${path}`, PINNED_TTL, () =>
      this.namedRead(repository, () => this.reader.listDirectory(repository, sha, path)));
  }

  knownDirectory(repository: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[] | undefined> {
    return this.store.peek(`directory:v2:${repository.id}:${sha}:${path}`);
  }

  rememberMissingFile(repository: GitHubRepository, sha: string, path: string): Promise<void> {
    return this.store.save(`raw-failure:v2:${repository.id}:${sha}:${path}`, "not_found", NEGATIVE_TTL);
  }

  async openFile(repository: GitHubRepository, sha: string, path: string, range?: string): Promise<Response> {
    const { id, owner, name } = repository;
    const failureKey = `raw-failure:v2:${id}:${sha}:${path}`;
    const failure = await this.store.get<"not_found" | "upstream">(failureKey);
    if (failure) throw new GitHubReadError(failure);
    try {
      return await this.namedRead(repository, () => this.reader.openFile(owner, name, sha, path, range),
        (response) => { void response.body?.cancel().catch(() => undefined); });
    } catch (error) {
      if (error instanceof GitHubReadError && (error.kind === "not_found" || error.kind === "upstream")) {
        await this.store.save(failureKey, error.kind, NEGATIVE_TTL);
      }
      throw error;
    }
  }
}
