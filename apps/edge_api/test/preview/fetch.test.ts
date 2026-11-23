import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchGitHub } from "../../src/net/fetch";

afterEach(() => vi.unstubAllGlobals());

describe("GitHub outbound fetch", () => {
  it.each([
    "https://example.org/",
    "https://api.github.com.example.org/",
    "http://api.github.com/",
    "https://api.github.com:8443/",
    "https://user:password@api.github.com/",
  ])("rejects %s before making an outbound request", async (url) => {
    const outbound = vi.fn();
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub(url)).rejects.toThrow("allowlist");
    expect(outbound).not.toHaveBeenCalled();
  });

  it.each([
    "https://example.org/",
    "https://raw.githubusercontent.com/owner/repo/main/file.txt",
    "http://api.github.com/repos/owner/repo",
    "https://api.github.com/repos/owner/another-repo",
    "https://api.github.com/repositories/42/contents",
    "https://api.github.com/repositories/42?unexpected",

  ])("blocks an unsafe redirect to %s", async (location) => {
    const outbound = vi.fn().mockResolvedValue(new Response(null, { status: 302, headers: { Location: location } }));
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub("https://api.github.com/repos/owner/repo", { repositoryRedirect: true })).rejects.toThrow();
    expect(outbound).toHaveBeenCalledOnce();
  });

  it("follows only a repository lookup redirect by ID with a timeout and constructed headers", async () => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(new Response(null, { status: 301, headers: { Location: "/repositories/42" } }))
      .mockResolvedValueOnce(new Response("{}"));
    vi.stubGlobal("fetch", outbound);
    await fetchGitHub("https://api.github.com/repos/owner/repo", { token: "server-token", repositoryRedirect: true });

    expect(outbound.mock.calls.map(([url]) => String(url))).toEqual([
      "https://api.github.com/repos/owner/repo",
      "https://api.github.com/repositories/42",
    ]);
    for (const [, options] of outbound.mock.calls) {
      expect(options?.redirect).toBe("manual");
      expect(options?.cache).toBe("no-store");
      expect(options?.signal).toBeInstanceOf(AbortSignal);
      const headers = new Headers(options?.headers);
      expect(headers.get("Authorization")).toBe("Bearer server-token");
      expect(headers.get("Cookie")).toBeNull();
    }
  });

  it("refuses a raw redirect to a different path on the same host", async () => {
    const outbound = vi.fn().mockResolvedValue(new Response(null, {
      status: 302, headers: { Location: "/someone/another-repo/main/README.md" },
    }));
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub("https://raw.githubusercontent.com/owner/repo/main/README.md"))
      .rejects.toThrow("redirect");
    expect(outbound).toHaveBeenCalledOnce();
  });

  it("omits Authorization on raw reads even when a credential is supplied", async () => {
    const outbound = vi.fn<typeof fetch>().mockResolvedValue(new Response("file"));
    vi.stubGlobal("fetch", outbound);
    await fetchGitHub("https://raw.githubusercontent.com/owner/repo/main/README.md", { token: crypto.randomUUID() });
    expect(new Headers(outbound.mock.calls[0]?.[1]?.headers).get("Authorization")).toBeNull();
  });

  it("rejects POSTs outside the installation exchange and refuses exchange redirects", async () => {
    const outbound = vi.fn().mockResolvedValue(new Response(null, {
      status: 307, headers: { Location: "https://raw.githubusercontent.com/owner/repo/main/README.md" },
    }));
    vi.stubGlobal("fetch", outbound);
    const options = { method: "POST", token: crypto.randomUUID() } as const;
    await expect(fetchGitHub("https://api.github.com/repos/owner/repo", options)).rejects.toThrow("exchange URL");
    expect(outbound).not.toHaveBeenCalled();
    await expect(fetchGitHub("https://api.github.com/app/installations/42/access_tokens", options))
      .rejects.toThrow("redirect");
    expect(outbound).toHaveBeenCalledOnce();
  });

  it("bounds a same-host redirect loop", async () => {
    const outbound = vi.fn().mockImplementation(async () =>
      new Response(null, { status: 302, headers: { Location: "/repositories/42" } }));
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub("https://api.github.com/repos/owner/repo", { repositoryRedirect: true }))
      .rejects.toThrow("redirect");
    expect(outbound).toHaveBeenCalledTimes(2);
  });
});
