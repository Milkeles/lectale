import type { components } from "../generated/api";

type RepoId = components["schemas"]["GitHubRepoId"];
type Sha = components["schemas"]["CommitSha"];

export interface GitHubRepository {
  id: RepoId;
  owner: string;
  name: string;
  defaultBranch: string;
  private: boolean;
}

export interface GitHubDirectoryEntry {
  name: string;
  type: "file" | "directory";
  size: number;
}

/** Read access to repository metadata and pinned bytes (V4-CORE-01, V4-SEC-03). */
export interface GitHubReader {
  /** Resolves a name, including GitHub's canonical casing or rename. */
  resolveRepository(owner: string, name: string): Promise<GitHubRepository>;
  /** Resolves a stable repository ID for a current visibility check. */
  resolveRepositoryById(id: RepoId): Promise<GitHubRepository>;
  /** Resolves the repository's current default tip to a full SHA. */
  headCommit(repository: GitHubRepository): Promise<Sha>;
  /** Checks whether the SHA equals the supplied default tip or is its ancestor. */
  isReachable(repository: GitHubRepository, sha: Sha, defaultHead: Sha): Promise<boolean>;
  /** Returns public regular files and directories directly under the pinned path. */
  listDirectory(repository: GitHubRepository, sha: Sha, path: string): Promise<GitHubDirectoryEntry[]>;
  /** Opens a canonical pinned file without buffering. Returns 200, 206 or 416. */
  openFile(owner: string, name: string, sha: Sha, path: string, range?: string): Promise<Response>;
}

/** Provider failures that the API can translate without exposing upstream data. */
export class GitHubReadError extends Error {
  constructor(
    readonly kind: "not_found" | "rate_limited" | "upstream" | "repo_changed",
    readonly retryAfterSeconds?: number,
  ) {
    super("GitHub read failed.");
    this.name = "GitHubReadError";
  }
}

/** The corrected OpenAPI contract identifies commits by a full lowercase SHA. */
export const commitShaPattern = /^[0-9a-f]{40}$/u;

/** Only IDs that round trip safely as the generated JavaScript number are supported. */
export function isRepoId(id: unknown): id is RepoId {
  return typeof id === "number" && Number.isSafeInteger(id) && id > 0;
}
