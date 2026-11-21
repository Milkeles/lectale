import { afterEach, describe, expect, it, vi } from "vitest";
import { GitHubRestReader } from "../../src/github/rest-reader";
import { createApp } from "../../src/index";

const sha = "a".repeat(40);
const head = "b".repeat(40);
const repo = { id: 42, owner: { login: "Owner" }, name: "Repository", default_branch: "main", private: false };
const repository = { id: 42, owner: "Owner", name: "Repository", defaultBranch: "main", private: false };

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("GitHub REST preview reader", () => {
  it("uses bounded REST metadata and raw for unauthenticated pinned ranges", async () => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(new Response(head))
      .mockResolvedValueOnce(Response.json([
        { name: "slides.pdf", path: "files/slides.pdf", type: "file", size: 10, download_url: "ignored" },
        { name: "folder", path: "files/folder", type: "dir", size: 0 },
        { name: "linked", path: "files/linked", type: "symlink", size: 0 },
        { name: "gitlink", path: "files/gitlink", type: "file", size: 0, submodule_git_url: "ignored" },
        { name: "gitlink2", path: "files/gitlink2", type: "submodule", size: 0 },
        { name: ".hidden", path: "files/.hidden", type: "file", size: 7 },
        { name: "unexpected", path: "other/unexpected", type: "file", size: 5 },
      ]))
      .mockResolvedValueOnce(new Response("123", { status: 206 }));
    vi.stubGlobal("fetch", outbound);

    const reader = new GitHubRestReader(async () => "ghs_test_token");
    expect(await reader.resolveRepository("owner", "repository")).toEqual(repository);
    expect(await reader.resolveRepositoryById(42)).toEqual(repository);
    expect(await reader.headCommit(repository)).toBe(head);
    expect(await reader.listDirectory(repository, sha, "files")).toEqual([
      { name: "slides.pdf", type: "file", size: 10 },
      { name: "folder", type: "directory", size: 0 },
    ]);
    const file = await reader.openFile("Owner", "Repository", sha, "files/slides.pdf", "bytes=0-2");
    expect(file.status).toBe(206);
    expect(await file.text()).toBe("123");
    expect(outbound.mock.calls.map(([url]) => String(url))).toEqual([
      "https://api.github.com/repos/owner/repository",
      "https://api.github.com/repositories/42",
      "https://api.github.com/repositories/42/commits/HEAD",
      `https://api.github.com/repositories/42/contents/files?ref=${sha}`,
      `https://raw.githubusercontent.com/Owner/Repository/${sha}/files/slides.pdf`,
    ]);
    const headHeaders = new Headers(outbound.mock.calls[2]?.[1]?.headers);
    expect(headHeaders.get("Accept")).toBe("application/vnd.github.sha");
    expect(headHeaders.get("Authorization")).toBe("Bearer ghs_test_token");
    const headers = new Headers(outbound.mock.calls[4]?.[1]?.headers);
    expect(headers.get("Range")).toBe("bytes=0-2");
    expect(headers.get("Authorization")).toBeNull();
    expect(headers.get("Cookie")).toBeNull();
  });

  it.each([["behind", true], ["identical", true], ["ahead", false], ["diverged", false]])(
    "uses the default head as compare base and accepts %s = %s",
    async (status, reachable) => {
      const outbound = vi.fn<typeof fetch>().mockResolvedValueOnce(Response.json({ status }));
      vi.stubGlobal("fetch", outbound);
      expect(await new GitHubRestReader().isReachable(repository, sha, head)).toBe(reachable);
      expect(String(outbound.mock.calls[0]?.[0])).toBe(
        `https://api.github.com/repositories/42/compare/${head}...${sha}?per_page=1&page=2`,
      );
    },
  );

  it("keeps head and reachability bound to the ID when a name changes hands and back", async () => {
    let nameHolder = repo.id;
    const foreignId = 77;
    const outbound = vi.fn<typeof fetch>(async (url) => {
      const { pathname } = new URL(String(url));
      if (pathname === "/repos/Owner/Repository") return Response.json({ ...repo, id: nameHolder });
      nameHolder = foreignId;
      try {
        const id = pathname.startsWith("/repositories/42/") ? repo.id : nameHolder;
        if (pathname.endsWith("/commits/HEAD")) return new Response(id === repo.id ? head : sha);
        return Response.json({ status: id === repo.id ? "diverged" : "behind" });
      } finally {
        nameHolder = repo.id;
      }
    });
    vi.stubGlobal("fetch", outbound);
    const reader = new GitHubRestReader();
    const original = await reader.resolveRepository("Owner", "Repository");
    expect(await reader.headCommit(original)).toBe(head);
    expect(await reader.isReachable(original, sha, head)).toBe(false);
    expect(await reader.resolveRepository("Owner", "Repository")).toEqual(original);
    expect(outbound.mock.calls.map(([url]) => new URL(String(url)).pathname)).toEqual([
      "/repos/Owner/Repository", "/repositories/42/commits/HEAD",
      `/repositories/42/compare/${head}...${sha}`, "/repos/Owner/Repository",
    ]);
  });

  it.each([403, 404])("brackets a name fallback after ID-addressed %s and logs the address used", async (status) => {
    const log = vi.spyOn(console, "info").mockImplementation(() => undefined);
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(new Response(null, { status }))
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(new Response(head))
      .mockResolvedValueOnce(Response.json(repo));
    vi.stubGlobal("fetch", outbound);
    expect(await new GitHubRestReader().headCommit(repository)).toBe(head);
    expect(outbound.mock.calls.map(([url]) => new URL(String(url)).pathname)).toEqual([
      "/repositories/42/commits/HEAD", "/repos/Owner/Repository",
      "/repos/Owner/Repository/commits/HEAD", "/repos/Owner/Repository",
    ]);
    expect(log).toHaveBeenCalledExactlyOnceWith("GitHub preview metadata", { operation: "head", address: "name-fallback" });
  });

  it.each([404, 502, 200])("discards fallback metadata when the final name check returns %s or a different ID", async (status) => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(new Response(head))
      .mockResolvedValueOnce(Response.json({ ...repo, id: 77 }, { status }));
    vi.stubGlobal("fetch", outbound);
    await expect(new GitHubRestReader().headCommit(repository)).rejects.toMatchObject({ kind: "repo_changed" });
  });

  it.each([[409, "not_found"], [429, "rate_limited"], [502, "upstream"]])(
    "does not fall back after an ID-addressed %s",
    async (status, kind) => {
      const outbound = vi.fn<typeof fetch>().mockResolvedValueOnce(new Response(null, { status }));
      vi.stubGlobal("fetch", outbound);
      await expect(new GitHubRestReader().headCommit(repository)).rejects.toMatchObject({ kind });
      expect(outbound).toHaveBeenCalledOnce();
    },
  );

  it.each(["../notes", "%2e%2e/notes", ".git/config", "a//b", "a\\b", "dir/.", "a%2Fb", "a".repeat(501)])(
    "rejects unsafe raw paths %s at the adapter",
    async (path) => {
      const outbound = vi.fn();
      vi.stubGlobal("fetch", outbound);
      await expect(new GitHubRestReader().openFile("Owner", "Repository", sha, path))
        .rejects.toMatchObject({ kind: "not_found" });
      expect(outbound).not.toHaveBeenCalled();
    },
  );

  it("cancels oversized directory JSON before parsing it", async () => {
    const cancel = vi.fn();
    const body = new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array(2 * 1024 * 1024 + 1));
      },
      cancel,
    });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(new Response(body)));
    await expect(new GitHubRestReader().listDirectory(repository, sha, ""))
      .rejects.toMatchObject({ kind: "upstream" });
    expect(cancel).toHaveBeenCalledOnce();
  });

  it("defaults to anonymous GitHub calls and returns identical denials across provider status codes", async () => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json({ message: "private Bearer ghs_secret" }, { status: 403 }))
      .mockResolvedValueOnce(Response.json({ message: "missing Bearer ghs_secret" }, { status: 404 }))
      .mockResolvedValueOnce(Response.json({ ...repo, private: true }));
    vi.stubGlobal("fetch", outbound);
    const app = createApp();
    const denied = await Promise.all(["private", "missing", "authenticated-private"].map((name) => app.request("/api/courses/import", {
      method: "POST",
      headers: {
        "Content-Type": "application/json", Cookie: "example=client-cookie", Authorization: "Bearer client-token",
      },
      body: JSON.stringify({ url: `https://github.com/owner/${name}` }),
    })));
    const headers = Object.fromEntries(denied[0]!.headers.entries());
    for (const response of denied) {
      expect(response.status).toBe(404);
      expect(Object.fromEntries(response.headers.entries())).toEqual(headers);
      const text = await response.text();
      expect(text).not.toMatch(/ghs_|Bearer/u);
      expect(JSON.parse(text)).toEqual({
        code: "course_not_found", message: "This public course or file is unavailable.",
        retryable: false, requestId: expect.any(String),
      });
    }
    expect(outbound).toHaveBeenCalledTimes(3);
    for (const [, options] of outbound.mock.calls) {
      const upstream = new Headers(options?.headers);
      expect(upstream.get("Cookie")).toBeNull();
      expect(upstream.get("Authorization")).toBeNull();
    }
  });

  it("treats an empty repository as unavailable", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(new Response(null, { status: 409 })));
    await expect(new GitHubRestReader().headCommit(repository)).rejects.toMatchObject({ kind: "not_found" });
  });

  it("maps GitHub's 403 primary rate limit to a retry delay", async () => {
    const reset = Math.ceil(Date.now() / 1000) + 30;
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(new Response(null, {
      status: 403,
      headers: { "X-RateLimit-Remaining": "0", "X-RateLimit-Reset": String(reset) },
    })));
    await expect(new GitHubRestReader().resolveRepositoryById(42)).rejects.toMatchObject({
      kind: "rate_limited", retryAfterSeconds: expect.any(Number),
    });
  });

  it("recognizes secondary rate limiting without Retry-After", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce(Response.json({
      message: "You have exceeded a secondary rate limit.",
    }, { status: 403 })));
    await expect(new GitHubRestReader().resolveRepositoryById(42)).rejects.toMatchObject({
      kind: "rate_limited", retryAfterSeconds: 60,
    });
  });
});
