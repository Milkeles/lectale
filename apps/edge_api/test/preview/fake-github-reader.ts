import {
  GitHubReadError, type GitHubDirectoryEntry, type GitHubReader, type GitHubRepository,
} from "../../src/github/reader";
import { isSafeRepoPath } from "../../src/contract/repo-path";
import { byteInterval, parseRange } from "../../src/preview/range";

interface FakeFile {
  bytes: Uint8Array;
  mode: "100644" | "100755" | "120000" | "160000";
}

interface FakeRepository {
  metadata: GitHubRepository;
  head: string;
  history: Map<string, Set<string>>;
  network: number;
}

const DEFAULT_REPO = { id: 42, owner: "Course-Author", name: "Example", defaultBranch: "main", private: false };

/** Models both default-branch history and GitHub's fork-network object visibility. */
export class FakeGitHubReader implements GitHubReader {
  private readonly repositories = new Map<number, FakeRepository>();
  private readonly objects = new Map<number, Map<string, Map<string, FakeFile>>>();

  constructor() {
    this.addRepository(DEFAULT_REPO, "a".repeat(40));
  }

  addRepository(metadata: GitHubRepository, head: string, network = metadata.id): void {
    this.repositories.set(metadata.id, { metadata: { ...metadata }, head, history: new Map([[head, new Set([head])]]), network });
  }

  rename(id: number, owner: string, name: string): void {
    const repo = this.findById(id);
    repo.metadata = { ...repo.metadata, owner, name };
  }

  setVisibility(id: number, isPrivate: boolean): void {
    const repo = this.findById(id);
    repo.metadata = { ...repo.metadata, private: isPrivate };
  }

  forcePush(id: number, head: string): void {
    const repo = this.findById(id);
    repo.head = head;
    if (!repo.history.has(head)) repo.history.set(head, new Set([head]));
  }

  switchDefaultBranch(id: number, branch: string, head: string): void {
    const repo = this.findById(id);
    repo.metadata = { ...repo.metadata, defaultBranch: branch };
    this.forcePush(id, head);
  }

  advance(id: number, sha: string): void {
    const repo = this.findById(id);
    repo.history.set(sha, new Set([...(repo.history.get(repo.head) ?? []), sha]));
    repo.head = sha;
  }

  setFile(path: string, text: string | number[], mode: FakeFile["mode"] = "100644", id = 42): void {
    const { head, network } = this.findById(id);
    const commits = this.objects.get(network) ?? new Map<string, Map<string, FakeFile>>();
    const files = commits.get(head) ?? new Map<string, FakeFile>();
    const bytes = typeof text === "string" ? new TextEncoder().encode(text) : new Uint8Array(text);
    files.set(path, { bytes, mode });
    commits.set(head, files);
    this.objects.set(network, commits);
  }

  removeFile(path: string, id = 42): void {
    const { head, network } = this.findById(id);
    this.objects.get(network)?.get(head)?.delete(path);
  }

  private findById(id: number): FakeRepository {
    const repository = this.repositories.get(id);
    if (!repository) throw new GitHubReadError("not_found");
    return repository;
  }

  private findByName(owner: string, name: string): FakeRepository {
    for (const repository of this.repositories.values()) {
      if (repository.metadata.owner.toLowerCase() === owner.toLowerCase()
        && repository.metadata.name.toLowerCase() === name.toLowerCase()) return repository;
    }
    throw new GitHubReadError("not_found");
  }

  private files(repository: FakeRepository, sha: string): Map<string, FakeFile> {
    const files = this.objects.get(repository.network)?.get(sha);
    if (repository.metadata.private || !files) throw new GitHubReadError("not_found");
    return files;
  }

  async resolveRepository(owner: string, name: string): Promise<GitHubRepository> {
    return { ...this.findByName(owner, name).metadata };
  }

  async resolveRepositoryById(id: number): Promise<GitHubRepository> {
    return { ...this.findById(id).metadata };
  }

  async headCommit({ id }: GitHubRepository): Promise<string> {
    const repository = this.findById(id);
    if (repository.metadata.private) throw new GitHubReadError("not_found");
    return repository.head;
  }

  async isReachable({ id }: GitHubRepository, sha: string, defaultHead: string): Promise<boolean> {
    const repository = this.findById(id);
    if (repository.metadata.private) throw new GitHubReadError("not_found");
    return repository.history.get(defaultHead)?.has(sha) ?? false;
  }

  async listDirectory({ id }: GitHubRepository, sha: string, path: string): Promise<GitHubDirectoryEntry[]> {
    const entries = new Map<string, GitHubDirectoryEntry>();
    const prefix = path ? `${path}/` : "";
    for (const [file, { bytes, mode }] of this.files(this.findById(id), sha)) {
      if (!file.startsWith(prefix) || !isSafeRepoPath(file)) continue;
      const suffix = file.slice(prefix.length);
      const slash = suffix.indexOf("/");
      if (slash !== -1) {
        const dirname = suffix.slice(0, slash);
        entries.set(dirname, { name: dirname, type: "directory", size: 0 });
      } else if (mode === "100644" || mode === "100755") {
        entries.set(suffix, { name: suffix, type: "file", size: bytes.length });
      }
    }
    if (path && entries.size === 0) throw new GitHubReadError("not_found");
    return [...entries.values()];
  }

  async openFile(owner: string, name: string, sha: string, path: string, range?: string): Promise<Response> {
    const file = this.files(this.findByName(owner, name), sha).get(path);
    if (!file) throw new GitHubReadError("not_found");
    const size = file.bytes.length;
    if (range === undefined) return new Response(file.bytes, { headers: { "Content-Length": String(size) } });
    const requested = parseRange(range);
    const interval = requested && byteInterval(requested, size);
    if (!interval) return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${size}` } });
    const bytes = file.bytes.subarray(interval.start, interval.end + 1);
    return new Response(bytes, { status: 206, headers: {
      "Content-Range": `bytes ${interval.start}-${interval.end}/${size}`,
      "Content-Length": String(bytes.length),
    } });
  }
}
