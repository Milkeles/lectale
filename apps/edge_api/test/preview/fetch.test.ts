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
  ])("blocks an unsafe redirect to %s", async (location) => {
    const outbound = vi.fn().mockResolvedValue(new Response(null, { status: 302, headers: { Location: location } }));
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub("https://api.github.com/repos/owner/repo")).rejects.toThrow();
    expect(outbound).toHaveBeenCalledOnce();
  });

  it("follows same-host redirects with a timeout and constructed headers", async () => {
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(new Response(null, { status: 301, headers: { Location: "/repositories/42" } }))
      .mockResolvedValueOnce(new Response("{}"));
    vi.stubGlobal("fetch", outbound);
    await fetchGitHub("https://api.github.com/repos/owner/repo", { token: "server-token" });

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

  it("bounds a same-host redirect loop", async () => {
    const outbound = vi.fn().mockImplementation(async () =>
      new Response(null, { status: 302, headers: { Location: "/repositories/42" } }));
    vi.stubGlobal("fetch", outbound);
    await expect(fetchGitHub("https://api.github.com/repositories/42")).rejects.toThrow("redirect");
    expect(outbound).toHaveBeenCalledTimes(4);
  });
});
