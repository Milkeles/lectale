import { afterEach, describe, expect, it, vi } from "vitest";
import { GitHubRestReader } from "../../src/github/rest-reader";
import { createApp } from "../../src/index";

const sha = "a".repeat(40);
const repo = { id: 42, owner: { login: "Owner" }, name: "Repository", default_branch: "main", private: false };

afterEach(() => vi.unstubAllGlobals());

describe("GitHub REST preview reader", () => {
  it("uses REST for canonical metadata and raw for unauthenticated pinned ranges", async () => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(Response.json(repo))
      .mockResolvedValueOnce(Response.json({ sha }))
      .mockResolvedValueOnce(Response.json({
        tree: [{ path: "files/slides.pdf", type: "blob", mode: "100644", size: 10 }],
        truncated: false,
      }))
      .mockResolvedValueOnce(new Response("123", { status: 206 }));
    vi.stubGlobal("fetch", outbound);

    const reader = new GitHubRestReader(async () => "server-token");
    expect(await reader.resolveRepository("owner", "repository")).toEqual({
      id: 42, owner: "Owner", name: "Repository", defaultBranch: "main", private: false,
    });
    expect(await reader.resolveRepositoryById(42)).toMatchObject({ id: 42 });
    expect(await reader.headCommit("Owner", "Repository")).toBe(sha);
    expect(await reader.tree("Owner", "Repository", sha)).toEqual({
      entries: [{ path: "files/slides.pdf", type: "blob", mode: "100644", size: 10 }],
      truncated: false,
    });
    const file = await reader.openFile("Owner", "Repository", sha, "files/slides.pdf", "bytes=0-2");
    expect(file.status).toBe(206);
    expect(await file.text()).toBe("123");
    expect(outbound.mock.calls.map(([url]) => String(url))).toEqual([
      "https://api.github.com/repos/owner/repository",
      "https://api.github.com/repositories/42",
      "https://api.github.com/repos/Owner/Repository/commits/HEAD",
      `https://api.github.com/repos/Owner/Repository/git/trees/${sha}?recursive=1`,
      `https://raw.githubusercontent.com/Owner/Repository/${sha}/files/slides.pdf`,
    ]);
    const headers = new Headers(outbound.mock.calls[4]?.[1]?.headers);
    expect(headers.get("Range")).toBe("bytes=0-2");
    expect(headers.get("Authorization")).toBeNull();
    expect(headers.get("Cookie")).toBeNull();
  });

  it("defaults to anonymous GitHub calls regardless of client credentials", async () => {
    const outbound = vi.fn<typeof fetch>().mockResolvedValueOnce(Response.json({ ...repo, private: true }));
    vi.stubGlobal("fetch", outbound);
    const response = await createApp().request("/api/courses/import", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Cookie": "example=client-cookie",
        "Authorization": "Bearer client-token",
      },
      body: JSON.stringify({ url: "https://github.com/owner/repository" }),
    });
    expect(response.status).toBe(404);
    expect(outbound).toHaveBeenCalledOnce();
    const headers = new Headers(outbound.mock.calls[0]?.[1]?.headers);
    expect(headers.get("Cookie")).toBeNull();
    expect(headers.get("Authorization")).toBeNull();
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
