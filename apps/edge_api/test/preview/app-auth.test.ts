import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { GitHubAppAuth } from "../../src/github/app-auth";
import { createApp } from "../../src/index";
import type { PreviewCache } from "../../src/preview/cache";
import type { PreviewBindings } from "../../src/preview/routes";

const APP_ID = "12345";
const REPOSITORY_ID = 1466047676;
const account = "TestOwner";
const now = Date.parse("2026-11-23T12:00:00Z");
const hour = 3_600_000;
let publicKey: CryptoKey;
let pem: string;

beforeAll(async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: Uint8Array.of(1, 0, 1), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  if (!("privateKey" in pair)) throw new Error("Expected an RSA key pair.");
  publicKey = pair.publicKey;
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  if (!(pkcs8 instanceof ArrayBuffer)) throw new Error("Expected a DER-encoded PKCS#8 key.");
  const der = new Uint8Array(pkcs8);
  const lines = btoa(String.fromCharCode(...der)).match(/.{1,64}/gu)?.join("\n");
  pem = `-----BEGIN PRIVATE KEY-----\n${lines}\n-----END PRIVATE KEY-----\n`;
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function bindings(): PreviewBindings {
  return {
    GH_APP_ID: APP_ID, GH_APP_PRIVATE_KEY: pem, GH_APP_INSTALLATION_ACCOUNT: account,
    GH_APP_TOKEN_REPOSITORY_ID: String(REPOSITORY_ID),
  } as PreviewBindings;
}

function installations(login = account): Response {
  return Response.json([{ id: 1, account: { login: "AnotherAccount" } }, { id: 42, account: { login } }]);
}

function tokenResponse(token: string, issuedAt = now, overrides: Record<string, unknown> = {}): Response {
  return Response.json({
    token,
    expires_at: new Date(issuedAt + hour).toISOString(),
    repository_selection: "selected",
    repositories: [{ id: REPOSITORY_ID, name: "lectale", private: false }],
    permissions: { contents: "read", metadata: "read" },
    ...overrides,
  }, { status: 201 });
}

function authorization(options?: RequestInit): string | null {
  return new Headers(options?.headers).get("Authorization");
}

function importCourse(app: ReturnType<typeof createApp>, name: string, env: PreviewBindings): Promise<Response> {
  return Promise.resolve(app.request("/api/courses/import", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: `https://github.com/owner/${name}` }),
  }, env));
}

function decodeSegment(segment: string): Uint8Array<ArrayBuffer> {
  const value = segment.replaceAll("-", "+").replaceAll("_", "/");
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

describe("GitHub App authentication", () => {
  it("signs a short RS256 JWT and uses it only for discovery and a read-only exchange", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const token = crypto.randomUUID();
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations(account.toLowerCase()))
      .mockResolvedValueOnce(tokenResponse(token));
    vi.stubGlobal("fetch", outbound);

    expect((await new GitHubAppAuth().tokenFor(bindings())) === token).toBe(true);
    expect(outbound.mock.calls.map(([url, init]) => [String(url), init?.method ?? "GET"])).toEqual([
      ["https://api.github.com/app/installations?per_page=100&page=1", "GET"],
      ["https://api.github.com/app/installations/42/access_tokens", "POST"],
    ]);
    const jwtHeader = authorization(outbound.mock.calls[0]?.[1]);
    expect(jwtHeader?.startsWith("Bearer ")).toBe(true);
    expect(authorization(outbound.mock.calls[1]?.[1]) === jwtHeader).toBe(true);
    const [header = "", claims = "", signature = ""] = jwtHeader?.slice("Bearer ".length).split(".") ?? [];
    const decoder = new TextDecoder();
    expect(JSON.parse(decoder.decode(decodeSegment(header)))).toEqual({ alg: "RS256", typ: "JWT" });
    const seconds = now / 1_000;
    expect(JSON.parse(decoder.decode(decodeSegment(claims)))).toEqual({
      iat: seconds - 60, exp: seconds + 540, iss: APP_ID,
    });
    expect(await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", publicKey, decodeSegment(signature), new TextEncoder().encode(`${header}.${claims}`),
    )).toBe(true);
    expect(JSON.parse(String(outbound.mock.calls[1]?.[1]?.body))).toEqual({
      repository_ids: [REPOSITORY_ID],
      permissions: { contents: "read", metadata: "read" },
    });
    for (const [, options] of outbound.mock.calls) {
      expect(options?.cache).toBe("no-store");
      expect(options?.redirect).toBe("manual");
    }
  });

  it("reuses its token until five minutes before expiry, then refreshes it", async () => {
    const refreshAt = now + hour - 5 * 60_000;
    const clock = vi.spyOn(Date, "now").mockReturnValue(now);
    const first = crypto.randomUUID();
    const second = crypto.randomUUID();
    const outbound = vi.fn()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(first))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(second, refreshAt));
    vi.stubGlobal("fetch", outbound);
    const auth = new GitHubAppAuth();
    const env = bindings();

    expect((await auth.tokenFor(env)) === first).toBe(true);
    clock.mockReturnValue(refreshAt - 1);
    expect((await auth.tokenFor(env)) === first).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(2);

    clock.mockReturnValue(refreshAt);
    expect((await auth.tokenFor(env)) === second).toBe(true);
    expect((await auth.tokenFor(env)) === second).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(4);
  });

  it("sends the App token on preview REST reads, takes its 404 as final and redacts failures", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const token = crypto.randomUUID();
    const warning = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const error = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const info = vi.spyOn(console, "info").mockImplementation(() => undefined);
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(token))
      .mockResolvedValueOnce(Response.json({ message: `${token} ${pem}` }, { status: 404 }));
    vi.stubGlobal("fetch", outbound);
    const app = createApp();

    const denied = await importCourse(app, "missing", bindings());
    expect(denied.status).toBe(404);
    expect(await denied.json()).toEqual({
      code: "course_not_found", message: "This public course or file is unavailable.",
      retryable: false, requestId: expect.any(String),
    });
    // A scoped token reads public repositories outside its scope, so its 404
    // is GitHub's real answer and no anonymous retry follows.
    expect(outbound).toHaveBeenCalledTimes(3);
    expect(authorization(outbound.mock.calls[2]?.[1]) === `Bearer ${token}`).toBe(true);
    expect([warning, error, info].every((log) => log.mock.calls.length === 0)).toBe(true);
  });

  it("falls back after a failed exchange, retries a minute later and warns once", async () => {
    const clock = vi.spyOn(Date, "now").mockReturnValue(now);
    const token = crypto.randomUUID();
    const warning = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockRejectedValueOnce(new Error(`${pem}\n${token}`))
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(token, now + 60_000))
      .mockResolvedValueOnce(new Response(null, { status: 404 }));
    vi.stubGlobal("fetch", outbound);
    const app = createApp();
    // A fresh bindings object per request, as the runtime may pass, must not
    // reset the retry delay or the cached token.
    // Each request names a new repository: workerd's Cache API keeps cached
    // misses between tests, and a cached miss answers without a GitHub request.

    expect((await importCourse(app, "absent-1", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(3);
    expect(authorization(outbound.mock.calls[2]?.[1])).toBeNull();

    expect((await importCourse(app, "absent-2", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(4);
    expect(authorization(outbound.mock.calls[3]?.[1])).toBeNull();
    expect(warning).toHaveBeenCalledExactlyOnceWith("GitHub App authentication unavailable. Using anonymous reads.");

    clock.mockReturnValue(now + 60_000);
    expect((await importCourse(app, "absent-3", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(7);
    expect(authorization(outbound.mock.calls[6]?.[1]) === `Bearer ${token}`).toBe(true);
    expect(warning).toHaveBeenCalledOnce();
  });

  it("stays anonymous without making requests when a binding is missing", async () => {
    const outbound = vi.fn<typeof fetch>();
    vi.stubGlobal("fetch", outbound);
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const auth = new GitHubAppAuth();
    for (const missing of [
      "GH_APP_ID", "GH_APP_PRIVATE_KEY", "GH_APP_INSTALLATION_ACCOUNT", "GH_APP_TOKEN_REPOSITORY_ID",
    ] as const) {
      const env = { ...bindings(), [missing]: undefined };
      expect(await auth.tokenFor(env)).toBeUndefined();
    }
    expect(await auth.tokenFor({ ...bindings(), GH_APP_ID: "12a" })).toBeUndefined();
    expect(await auth.tokenFor({ ...bindings(), GH_APP_TOKEN_REPOSITORY_ID: "12a" })).toBeUndefined();
    expect(outbound).not.toHaveBeenCalled();
  });

  it.each([
    ["a wrong repository_selection", { repository_selection: "all" }],
    ["a missing repository_selection", { repository_selection: undefined }],
    ["an extra repository", { repositories: [
      { id: REPOSITORY_ID, private: false }, { id: 7, private: false },
    ] }],
    ["a different repository", { repositories: [{ id: 7, private: false }] }],
    ["no repositories", { repositories: [] }],
    ["a private scoped repository", { repositories: [{ id: REPOSITORY_ID, private: true }] }],
    ["an unknown visibility", { repositories: [{ id: REPOSITORY_ID }] }],
    ["extra permissions", { permissions: { contents: "read", metadata: "read", issues: "read" } }],
    ["write permission", { permissions: { contents: "write", metadata: "read" } }],
    ["a missing permission", { permissions: { contents: "read" } }],
  ])("refuses an exchange with %s and stays anonymous", async (_label, overrides) => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const warning = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(crypto.randomUUID(), now, overrides));
    vi.stubGlobal("fetch", outbound);

    expect(await new GitHubAppAuth().tokenFor(bindings())).toBeUndefined();
    expect(outbound).toHaveBeenCalledTimes(2);
    expect(warning).toHaveBeenCalledExactlyOnceWith("GitHub App authentication unavailable. Using anonymous reads.");
  });

  it("caps reuse at 55 minutes even when GitHub reports a later expiry", async () => {
    const clock = vi.spyOn(Date, "now").mockReturnValue(now);
    const first = crypto.randomUUID();
    const second = crypto.randomUUID();
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(first, now + 23 * hour))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(second, now + 55 * 60_000));
    vi.stubGlobal("fetch", outbound);
    const auth = new GitHubAppAuth();
    const env = bindings();

    expect((await auth.tokenFor(env)) === first).toBe(true);
    clock.mockReturnValue(now + 55 * 60_000 - 1);
    expect((await auth.tokenFor(env)) === first).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(2);
    clock.mockReturnValue(now + 55 * 60_000);
    expect((await auth.tokenFor(env)) === second).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(4);
  });

  it("drops only the token that GitHub rejected and mints a new one on the next call", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const first = crypto.randomUUID();
    const second = crypto.randomUUID();
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(first))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(second));
    vi.stubGlobal("fetch", outbound);
    const auth = new GitHubAppAuth();
    const env = bindings();

    expect((await auth.tokenFor(env)) === first).toBe(true);
    auth.dropToken(crypto.randomUUID());
    expect((await auth.tokenFor(env)) === first).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(2);
    auth.dropToken(first);
    expect((await auth.tokenFor(env)) === second).toBe(true);
    expect(outbound).toHaveBeenCalledTimes(4);
  });

  it("drops the cached token after a 401 on a preview read, and the next import mints a new one", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const first = crypto.randomUUID();
    const second = crypto.randomUUID();
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(first))
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(second))
      .mockResolvedValueOnce(new Response(null, { status: 404 }));
    vi.stubGlobal("fetch", outbound);
    const app = createApp();

    // The rejected token is dropped, and its read is retried anonymously.
    expect((await importCourse(app, "revoked-1", bindings())).status).toBe(404);
    expect(authorization(outbound.mock.calls[2]?.[1]) === `Bearer ${first}`).toBe(true);
    expect(authorization(outbound.mock.calls[3]?.[1])).toBeNull();
    expect((await importCourse(app, "revoked-2", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(7);
    expect(authorization(outbound.mock.calls[6]?.[1]) === `Bearer ${second}`).toBe(true);
  });

  it("answers a private and a missing repository alike, with the same GitHub calls", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const token = crypto.randomUUID();
    const outbound = vi.fn<typeof fetch>(async (url) => {
      const { pathname } = new URL(String(url));
      if (pathname === "/app/installations") return installations();
      if (pathname.endsWith("/access_tokens")) return tokenResponse(token);
      // A token scoped to another repository cannot see a private one, so
      // GitHub answers 404 for both, with or without credentials.
      return Response.json({ message: "Not Found" }, { status: 404 });
    });
    vi.stubGlobal("fetch", outbound);
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const app = createApp();
    const record = () => outbound.mock.calls.map(([url, options]) => [
      options?.method ?? "GET", new URL(String(url)).pathname.replace(/\/(?:private|missing)-repo$/u, "/NAME"),
      authorization(options) === null ? "anonymous" : "authenticated",
    ]);

    const privateResponse = await importCourse(app, "private-repo", bindings());
    const privateCalls = record();
    outbound.mockClear();
    const missingResponse = await importCourse(app, "missing-repo", bindings());
    const missingCalls = record();

    expect(privateResponse.status).toBe(404);
    expect(missingResponse.status).toBe(404);
    const privateBody = await privateResponse.json() as { requestId: string };
    const missingBody = await missingResponse.json() as { requestId: string };
    expect({ ...privateBody, requestId: "" }).toEqual({ ...missingBody, requestId: "" });
    // The first import also discovered the installation and minted the token.
    expect(privateCalls.slice(-1)).toEqual(missingCalls);
    expect(missingCalls).toEqual([["GET", "/repos/owner/NAME", "authenticated"]]);
  });

  it("pauses the anonymous retry after a revoked token meets a rate limit, and token reads go on", async () => {
    const clock = vi.spyOn(Date, "now").mockReturnValue(now);
    const [first, second, third] = [crypto.randomUUID(), crypto.randomUUID(), crypto.randomUUID()];
    const outbound = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(first))
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(new Response(null, { status: 403, headers: { "Retry-After": "120" } }))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(second, now + 60_000))
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(installations())
      .mockResolvedValueOnce(tokenResponse(third, now + 121_000))
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(new Response(null, { status: 404 }));
    vi.stubGlobal("fetch", outbound);
    const app = createApp();

    // A revoked token falls back to an anonymous read. When that read is
    // rate-limited, the answer is a retryable 429: the repository's state is
    // unknown, so it is never "not found".
    const limited = await importCourse(app, "throttled-1", bindings());
    expect(limited.status).toBe(429);
    expect(limited.headers.get("Retry-After")).toBe("120");
    expect(await limited.json()).toMatchObject({ code: "rate_limited", retryable: true });
    expect(outbound).toHaveBeenCalledTimes(4);

    // The shared cooldown stays closed: a new token is minted and its read
    // answers as usual.
    clock.mockReturnValue(now + 60_000);
    expect((await importCourse(app, "throttled-2", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(7);
    expect(authorization(outbound.mock.calls[6]?.[1]) === `Bearer ${second}`).toBe(true);

    // Another 401 while the pause runs makes no anonymous call.
    expect((await importCourse(app, "throttled-3", bindings())).status).toBe(429);
    expect(outbound).toHaveBeenCalledTimes(8);

    // After the pause, a 401 falls back to an anonymous read again.
    clock.mockReturnValue(now + 121_000);
    expect((await importCourse(app, "throttled-4", bindings())).status).toBe(404);
    expect(outbound).toHaveBeenCalledTimes(12);
    expect(authorization(outbound.mock.calls[10]?.[1]) === `Bearer ${third}`).toBe(true);
    expect(authorization(outbound.mock.calls[11]?.[1])).toBeNull();
  });

  it("never lets the token reach the Cache API, in keys or stored bodies", async () => {
    vi.spyOn(Date, "now").mockReturnValue(now);
    const token = crypto.randomUUID();
    const keys: string[] = [];
    const bodies: string[] = [];
    const real = caches.default;
    const cache: PreviewCache = {
      match: (key) => real.match(key),
      delete: (key) => real.delete(key),
      async put(key, response) {
        keys.push(new Request(key).url);
        bodies.push(await response.clone().text());
        await real.put(key, response);
      },
    };
    const repository = {
      id: 9_001, name: "cached-repo", default_branch: "main", private: false, owner: { login: "owner" },
    };
    const outbound = vi.fn<typeof fetch>(async (url) => {
      const { pathname } = new URL(String(url));
      if (pathname === "/app/installations") return installations();
      if (pathname.endsWith("/access_tokens")) return tokenResponse(token);
      if (pathname.endsWith("/commits/HEAD")) return new Response("c".repeat(40));
      if (pathname.startsWith("/repos/owner/cached-repo") || pathname.startsWith("/repositories/9001")) {
        return Response.json(repository);
      }
      return Response.json({ message: "Not Found" }, { status: 404 });
    });
    vi.stubGlobal("fetch", outbound);
    vi.spyOn(console, "info").mockImplementation(() => undefined);
    const app = createApp(undefined, cache);

    await importCourse(app, "cached-repo", bindings());
    await importCourse(app, "cached-missing", bindings());

    expect(outbound.mock.calls.some(([, options]) => authorization(options) === `Bearer ${token}`)).toBe(true);
    expect(keys.some((key) => key.includes("repo-preview:v2:owner:cached-repo"))).toBe(true);
    expect(keys.some((key) => key.includes("cached-missing"))).toBe(true);
    expect(bodies.length).toBe(keys.length);
    for (const entry of [...keys, ...bodies]) {
      expect(entry.includes(token)).toBe(false);
      expect(entry).not.toMatch(/ghs_|Bearer|PRIVATE KEY/u);
    }
  });
});
