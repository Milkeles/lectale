import {
  GitHubReadError, type GitHubReader, type GitHubRepository, type GitHubTree,
} from "../../src/github/reader";

interface FakeFile {
  text: string;
  mode: "100644" | "100755" | "120000";
}

/** In-memory GitHub port for preview route tests. */
export class FakeGitHubReader implements GitHubReader {
  repository: GitHubRepository | undefined = {
    id: 42, owner: "Course-Author", name: "Example", defaultBranch: "main", private: false,
  };
  sha = "a".repeat(40);
  truncated = false;
  private readonly commits = new Map<string, Map<string, FakeFile>>();

  setFile(path: string, text: string, mode: FakeFile["mode"] = "100644"): void {
    const files = this.commits.get(this.sha) ?? new Map();
    files.set(path, { text, mode });
    this.commits.set(this.sha, files);
  }

  removeFile(path: string): void {
    this.commits.get(this.sha)?.delete(path);
  }

  async resolveRepository(_owner: string, _name: string): Promise<GitHubRepository> {
    if (!this.repository) throw new GitHubReadError("not_found");
    return this.repository;
  }

  async resolveRepositoryById(id: number): Promise<GitHubRepository> {
    if (this.repository?.id !== id) throw new GitHubReadError("not_found");
    return this.repository;
  }

  async headCommit(_owner: string, _name: string): Promise<string> {
    return this.sha;
  }

  async tree(_owner: string, _name: string, sha: string): Promise<GitHubTree> {
    const files = this.commits.get(sha);
    if (!files) throw new GitHubReadError("not_found");
    return {
      entries: Array.from(files, ([path, file]) => ({
        path, type: "blob", mode: file.mode, size: new TextEncoder().encode(file.text).length,
      })),
      truncated: this.truncated,
    };
  }

  async openFile(_owner: string, _name: string, sha: string, path: string, _range?: string): Promise<Response> {
    const file = this.commits.get(sha)?.get(path);
    if (!file) throw new GitHubReadError("not_found");
    return new Response(file.text, {
      headers: { "Content-Length": String(new TextEncoder().encode(file.text).length) },
    });
  }
}
