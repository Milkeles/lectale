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

  private async assertAvailable(): Promise<void> {
    const stored = await this.store.get<number>(COOLDOWN_KEY);
    const until = Math.max(this.cooldown.until, stored ?? 0);
    const remaining = Math.ceil((until - Date.now()) / 1_000);
    if (remaining > 0) throw new GitHubReadError("rate_limited", remaining);
  }

  private async call<T>(operation: () => Promise<T>, repository?: GitHubRepository): Promise<T> {
    await this.assertAvailable();
    try {
      return await operation();
    } catch (error) {
      // Only the anonymous retry is paused; reads with the token go on.
      if (error instanceof GitHubReadError && error.budget === "fallback") throw error;
      if (error instanceof GitHubReadError && error.kind === "rate_limited") {
        const seconds = Math.max(1, Math.min(error.retryAfterSeconds ?? 60, MAX_RETRY_SECONDS));
        this.cooldown.until = Math.max(this.cooldown.until, Date.now() + seconds * 1_000);
        const remaining = Math.ceil((this.cooldown.until - Date.now()) / 1_000);
        await this.store.save(COOLDOWN_KEY, this.cooldown.until, remaining);
        throw new GitHubReadError("rate_limited", remaining);
      }
      if (repository && error instanceof GitHubReadError && error.kind === "repo_changed") {
        const { id, owner, name } = repository;
        await Promise.all([
          this.store.delete(`public-repo:v2:${id}`),
          this.store.delete(`repo-preview:v2:${owner.toLowerCase()}:${name.toLowerCase()}`),
        ]);
      }
      throw error;
    }
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
    return this.store.cached(`repo-head:v3:${id}:${owner.toLowerCase()}:${name.toLowerCase()}`, VISIBILITY_TTL,
      () => this.freshHead(repository));
  }

  private async freshHead(repository: GitHubRepository): Promise<string> {
    const sha = await this.call(() => this.reader.headCommit(repository), repository);
    if (!commitShaPattern.test(sha)) throw new GitHubReadError("upstream");
    return sha;
  }

  recordPin(repoId: number, sha: string): Promise<void> {
    return this.store.save(`import-pin:v3:${repoId}:${sha}`, true, PINNED_TTL);
  }

  async requirePin(repository: GitHubRepository, sha: string): Promise<void> {
    const { id } = repository;
    if (await this.store.get<boolean>(`import-pin:v3:${id}:${sha}`)) return;
    const reachable = await this.store.cached(`reachable:v3:${id}:${sha}`, PINNED_TTL, async () => {
      // The import head can predate a force push. Compare against a fresh tip,
      // then check again so a concurrent default-branch change can be retried.
      const head = await this.store.once(`compare-head:v3:${id}`, () => this.freshHead(repository));
      let result: boolean;
      try {
        result = await this.call(() => this.reader.isReachable(repository, sha, head), repository);
      } catch (error) {
        if (!(error instanceof GitHubReadError) || error.kind !== "not_found") throw error;
        result = false;
      }
      if (await this.freshHead(repository) !== head) throw new GitHubReadError("repo_changed");
      return result;
    });
    if (!reachable) throw new GitHubReadError("not_found");
  }

  directory(repository: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[]> {
    return this.store.cached(`directory:v3:${repository.id}:${sha}:${path}`, PINNED_TTL, () =>
      this.call(() => this.reader.listDirectory(repository, sha, path), repository));
  }

  knownDirectory(repository: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[] | undefined> {
    return this.store.peek(`directory:v3:${repository.id}:${sha}:${path}`);
  }

  rememberMissingFile(repository: GitHubRepository, sha: string, path: string): Promise<void> {
    return this.store.save(`raw-failure:v3:${repository.id}:${sha}:${path}`, "not_found", NEGATIVE_TTL);
  }

  /**
   * Opens raw bytes after the caller proves reachability by repository ID (SEC-020).
   * The commit SHA fixes the tree and its blob bytes. If the GitHub name changes
   * hands, any repository that serves that commit supplies the same bytes, so
   * a separate name-to-ID lookup is unnecessary for the raw read.
   */
  async openFile(repository: GitHubRepository, sha: string, path: string, range?: string): Promise<Response> {
    const { id, owner, name } = repository;
    const failureKey = `raw-failure:v3:${id}:${sha}:${path}`;
    const failure = await this.store.get<"not_found" | "upstream">(failureKey);
    if (failure) throw new GitHubReadError(failure);
    try {
      return await this.call(() => this.reader.openFile(owner, name, sha, path, range));
    } catch (error) {
      if (error instanceof GitHubReadError && (error.kind === "not_found" || error.kind === "upstream")) {
        await this.store.save(failureKey, error.kind, NEGATIVE_TTL);
      }
      throw error;
    }
  }
}
