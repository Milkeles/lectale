import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GitHubReadError } from "../../src/github/reader";
import type { PreviewCache } from "../../src/preview/cache";
import { createApp } from "../../src/index";
import { FakeGitHubReader } from "./fake-github-reader";

const root = "https://lectale.test";
const repoUrl = "https://github.com/Course-Author/Example";
const sha = "a".repeat(40);
const preview = `/api/preview/42/${sha}`;
const content = `${preview}/content`;
const readme = `${preview}/readme`;
const files = `${preview}/files`;
const folders = `${preview}/folders`;
const csp = "default-src 'none'; sandbox; frame-ancestors 'none'";
const replacement = { id: 77, owner: "Course-Author", name: "Example", defaultBranch: "main", private: false };
const manifestData = {
  schemaVersion: 3,
  course: { id: "example", title: "Example", summary: "A course", language: "en", version: "1.0.0" },
  outline: [
    {
      id: "first-lesson", kind: "lesson", title: "First lesson",
      resources: [
        { id: "slides", title: "Slides", type: "pdf", path: "materials/slides.pdf" },
        { id: "data", title: "Data", type: "file", path: "data.unknown" },
        { id: "markup", title: "Markup", type: "file", path: "example.html" },
        { id: "outline", title: "File named outline", type: "file", path: "outline" },
        { id: "folder", title: "Folder", type: "folder", path: "materials", maxEntries: 2 },
        { id: "submodule", title: "Submodule", type: "file", path: "submodule.txt" },
        { id: "link", title: "Link", type: "external", url: "https://example.org/" },
        { id: "symlink", title: "Linked file", type: "file", path: "symlink.txt" },
      ],
    },
    {
      id: "second-lesson", kind: "lesson", title: "Second lesson",
      resources: [{ id: "slides", title: "Slides", type: "pdf", path: "more/SLIDES.PDF" }],
    },
    { id: "assignment-link", kind: "assignment", assignmentId: "first-lesson" },
  ],
  assignments: [{
    id: "first-lesson", title: "Assignment",
    materials: [{ id: "slides", title: "Assignment slides", type: "pdf", path: "assignment.pdf" }],
    submission: {
      allowedExtensions: [".pdf"], maxFileBytes: 1, maxAttemptBytes: 1, maxFiles: 1, maxAttempts: 1,
      openAt: "2026-11-22T00:00:00Z", dueAt: "2026-11-23T00:00:00Z", closeAt: "2026-11-24T00:00:00Z",
    },
    grading: { mode: "manual", maxPoints: 10 },
  }],
};
const manifest = JSON.stringify(manifestData);

let reader: FakeGitHubReader;
let app: ReturnType<typeof createApp>;
let stored: Map<string, { response: Response; expires: number }>;
let cache: PreviewCache;
let now: number;

afterEach(() => vi.restoreAllMocks());

beforeEach(() => {
  reader = new FakeGitHubReader();
  reader.setFile("course.yaml", manifest);
  reader.setFile("README.md", "# Example");
  reader.setFile("materials/slides.pdf", "first slides");
  reader.setFile("more/SLIDES.PDF", "second slides");
  reader.setFile("assignment.pdf", "assignment slides");
  reader.setFile("data.unknown", "raw bytes");
  reader.setFile("example.html", "<h1>Markup</h1>");
  reader.setFile("outline", "separate file");
  reader.setFile("symlink.txt", "README.md", "120000");
  reader.setFile("submodule.txt", "gitlink", "160000");
  stored = new Map();
  now = Date.now();
  vi.spyOn(Date, "now").mockImplementation(() => now);
  cache = {
    async match(key: Request | string) {
      const hit = stored.get(typeof key === "string" ? key : key.url);
      if (hit && now < hit.expires) return hit.response.clone();
    },
    async put(key: Request | string, response: Response) {
      const ttl = Number(/max-age=(\d+)/u.exec(response.headers.get("Cache-Control") ?? "")?.[1]);
      stored.set(typeof key === "string" ? key : key.url, { response, expires: now + ttl * 1_000 });
    },
    async delete(key: Request | string) {
      return stored.delete(typeof key === "string" ? key : key.url);
    },
  };
  app = createApp(reader, cache);
});

function importCourse(url = repoUrl, ip = "192.0.2.1") {
  return app.request(`${root}/api/courses/import`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Request-Id": "preview-test", "CF-Connecting-IP": ip },
    body: JSON.stringify({ url }),
  });
}

function getFile(path: string, headers?: HeadersInit) {
  const requestHeaders = new Headers(headers);
  requestHeaders.set("X-Request-Id", "preview-test");
  return app.request(`${root}${path}`, { headers: requestHeaders });
}

async function expectError(response: Response, status: number, code: string) {
  expect(response.status).toBe(status);
  expect(response.headers.get("Cache-Control")).toBe("no-store");
  const body = await response.json();
  expect(body).toMatchObject({ code, requestId: "preview-test", retryable: expect.any(Boolean) });
  return body;
}

describe("POST /api/courses/import", () => {
  it("normalizes the URL, pins the canonical repository, and reuses a warm preview", async () => {
    const resolve = vi.spyOn(reader, "resolveRepository");
    const head = vi.spyOn(reader, "headCommit");
    const list = vi.spyOn(reader, "listDirectory");
    const open = vi.spyOn(reader, "openFile");

    const response = await importCourse(`${repoUrl}.git/`);
    expect(response.status).toBe(200);
    expect(response.headers.get("Set-Cookie")).toBeNull();
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    const first = await response.json();
    expect(first).toMatchObject({
      repoId: 42, sha, readmePresent: true,
      outline: { course: { title: "Example" }, nodes: expect.arrayContaining([
        expect.objectContaining({ id: "first-lesson", resources: expect.arrayContaining([
          expect.objectContaining({ id: "slides", href: `${content}/first-lesson/slides` }),
        ]) }),
      ]) },
    });
    expect(resolve).toHaveBeenCalledExactlyOnceWith("course-author", "example");
    const githubRepo = expect.objectContaining({ owner: "Course-Author", name: "Example", id: 42 });
    expect(head).toHaveBeenCalledExactlyOnceWith(githubRepo);
    expect(list).toHaveBeenCalledExactlyOnceWith(githubRepo, sha, "");
    expect(open).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha, "course.yaml", undefined);

    expect(await (await importCourse(repoUrl.toLowerCase())).json()).toEqual(first);
    expect(resolve).toHaveBeenCalledOnce();
    expect(head).toHaveBeenCalledTimes(1);
    expect(list).toHaveBeenCalledTimes(1);
    expect(open).toHaveBeenCalledTimes(1);
    expect(stored.get(`${root}/_lectale-cache/repo-preview:v2:course-author:example`)?.response.headers.get("Cache-Control"))
      .toBe("public, max-age=60");
    expect(stored.has(`${root}/_lectale-cache/public-course-outline:v4:42:${sha}`)).toBe(true);
  });

  describe("course covers (O2)", () => {
    const path = "assets/cover.png";
    const png = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 2, 88, 0, 0, 3, 132, 8, 2, 0, 0, 0, 0, 0, 0, 0];
    const smallPng = [...png];
    smallPng[23] = 131;

    beforeEach(() => {
      reader.setFile("course.yaml", JSON.stringify({ ...manifestData, course: { ...manifestData.course, cover: path } }));
    });

    it("checks only the first 64 KiB at the pinned SHA and retains a cover at the limits", async () => {
      const bytes = new Array<number>(2_000_000).fill(0);
      bytes.splice(0, png.length, ...png);
      reader.setFile(path, bytes);
      const open = vi.spyOn(reader, "openFile");

      const response = await importCourse();
      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data).toMatchObject({ sha, outline: { course: { cover: path } } });
      expect(data).not.toHaveProperty("warnings");
      expect(open).toHaveBeenCalledTimes(2);
      expect(open).toHaveBeenLastCalledWith("Course-Author", "Example", sha, path, "bytes=0-65535");
      expect(await (await getFile(preview)).json()).toEqual(data);
      expect(open).toHaveBeenCalledTimes(2);
    });

    it.each([
      ["cover_too_small", (): number[] => smallPng],
      ["cover_format", (): string => "GIF89a"],
      ["cover_too_large", (): string => "x".repeat(2_000_001)],
    ] as const)("returns %s and the placeholder without blocking import", async (code, contents) => {
      reader.setFile(path, contents());
      const open = vi.spyOn(reader, "openFile");
      const response = await importCourse();

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data).toMatchObject({ warnings: [{ code, path, message: expect.any(String) }] });
      expect(data).not.toHaveProperty("outline.course.cover");
      if (code === "cover_too_large") expect(open).toHaveBeenCalledOnce();
    });

    it("uses the placeholder when the cover path is a symlink", async () => {
      reader.setFile(path, "README.md", "120000");
      const open = vi.spyOn(reader, "openFile");
      const response = await importCourse();

      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({ warnings: [{ code: "cover_format", path }] });
      expect(open).toHaveBeenCalledOnce();
    });
  });

  it("returns the same response for private and missing repositories", async () => {
    const head = vi.spyOn(reader, "headCommit");
    reader.setVisibility(42, true);
    const privateResponse = await importCourse();
    const missingResponse = await importCourse("https://github.com/course-author/missing");
    expect(Object.fromEntries(privateResponse.headers)).toEqual(Object.fromEntries(missingResponse.headers));
    expect(await expectError(privateResponse, 404, "course_not_found"))
      .toEqual(await expectError(missingResponse, 404, "course_not_found"));
    expect(head).not.toHaveBeenCalled();
    expect(stored.size).toBe(2);
  });

  it.each([
    "http://github.com/owner/repo",
    "https://github.com/owner/repo?x=1",
    "https://github.com/owner/repo#readme",
    "https://github.com/owner/repo/tree/main",
    "https://github.com:443/owner/repo",
    "https://user@github.com/owner/repo",
    "https://github.com.example.com/owner/repo",
    "https://github.com/owner/..",
    "https://github.com/owner/%72epo",
    "https://github.com/owner/repo\n",
  ])("rejects a noncanonical URL %j before resolving GitHub", async (url) => {
    const resolve = vi.spyOn(reader, "resolveRepository");
    await expectError(await importCourse(url), 400, "invalid_url");
    expect(resolve).not.toHaveBeenCalled();
  });

  it("returns the validator diagnostics on invalid YAML", async () => {
    reader.setFile("course.yaml", "schemaVersion: [");
    const error = await expectError(await importCourse(), 422, "invalid_manifest");
    expect(error).toMatchObject({ details: { errors: [{ code: "YAML_INVALID", path: "", message: expect.any(String) }] } });
    const open = vi.spyOn(reader, "openFile");
    await expectError(await importCourse(), 422, "invalid_manifest");
    expect(open).not.toHaveBeenCalled();
  });

  it("reports a missing manifest and an absent README through their contract fields", async () => {
    reader.removeFile("course.yaml");
    await expectError(await importCourse(), 422, "manifest_missing");
    now += 301_000;
    reader.setFile("course.yaml", manifest);
    reader.removeFile("README.md");
    const response = await importCourse();
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ readmePresent: false });
    await expectError(await getFile(readme), 404, "course_not_found");
  });

  it("rejects an oversized file from its root directory entry without opening it", async () => {
    reader.setFile("course.yaml", "x".repeat(1024 * 1024 + 1));
    const open = vi.spyOn(reader, "openFile");
    await expectError(await importCourse(), 413, "manifest_too_large");
    expect(open).not.toHaveBeenCalled();
  });

  it("enforces the cap while reading even when GitHub provides no matching length", async () => {
    const cancel = vi.fn();
    const data = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(1024 * 1024));
        controller.enqueue(new Uint8Array(1));
      },
      cancel,
    });
    vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response(data));
    await expectError(await importCourse(), 413, "manifest_too_large");
    expect(cancel).toHaveBeenCalledOnce();
  });

  it("makes rate limits retryable and propagates the delay", async () => {
    vi.spyOn(reader, "resolveRepository").mockRejectedValueOnce(new GitHubReadError("rate_limited", 37));
    const response = await importCourse();
    expect(response.headers.get("Retry-After")).toBe("37");
    expect(await expectError(response, 429, "rate_limited")).toMatchObject({
      retryable: true, retryAfterSeconds: 37,
    });
  });

  it("coalesces simultaneous cold imports and warm preview requests", async () => {
    const resolve = vi.spyOn(reader, "resolveRepository");
    const resolveId = vi.spyOn(reader, "resolveRepositoryById");
    const head = vi.spyOn(reader, "headCommit");
    const open = vi.spyOn(reader, "openFile");
    const imports = await Promise.all(Array.from({ length: 20 }, () => importCourse()));
    expect(imports.every(({ status }) => status === 200)).toBe(true);
    expect(head).toHaveBeenCalledOnce();
    expect(resolve).toHaveBeenCalledOnce();
    expect(open).toHaveBeenCalledOnce();
    const reads = await Promise.all(Array.from({ length: 20 }, () => getFile(readme)));
    expect(reads.every(({ status }) => status === 200)).toBe(true);
    expect(await (await getFile(readme)).text()).toBe("# Example");
    expect(resolveId).toHaveBeenCalledOnce();
    expect(open).toHaveBeenCalledTimes(2);
  });

  it("limits import by client IP before contacting GitHub", async () => {
    const limit = vi.fn(async ({ key }: { key: string }) => ({ success: key !== "192.0.2.1" }));
    app = createApp(reader, cache, { limit });
    const resolve = vi.spyOn(reader, "resolveRepository");
    await expectError(await importCourse(), 429, "rate_limited");
    expect(resolve).not.toHaveBeenCalled();
    expect((await importCourse(repoUrl, "192.0.2.2")).status).toBe(200);
    expect(limit.mock.calls).toEqual([[{ key: "192.0.2.1" }], [{ key: "192.0.2.2" }]]);
  });

  it("opens a shared cooldown after throttling, even across app instances", async () => {
    const resolve = vi.spyOn(reader, "resolveRepository").mockRejectedValueOnce(new GitHubReadError("rate_limited", 37));
    await expectError(await importCourse(), 429, "rate_limited");
    now += 12_000;
    app = createApp(reader, cache);
    const response = await getFile(preview);
    expect(response.headers.get("Retry-After")).toBe("25");
    expect(await expectError(response, 429, "rate_limited")).toMatchObject({ retryAfterSeconds: 25 });
    expect(resolve).toHaveBeenCalledOnce();
    now += 25_000;
    expect((await importCourse()).status).toBe(200);
  });

  it("serves fully cached imports, previews, folders and file ranges during cooldown", async () => {
    const file = `${files}/materials/slides.pdf`;
    const folder = `${folders}/first-lesson/folder`;
    const imported = await (await importCourse()).json();
    expect(await (await getFile(file)).text()).toBe("first slides");
    const listing = await (await getFile(folder)).json();
    const resolve = vi.spyOn(reader, "resolveRepository").mockRejectedValueOnce(new GitHubReadError("rate_limited", 90));
    await expectError(await importCourse("https://github.com/owner/cold"), 429, "rate_limited");

    app = createApp(reader, cache);
    const resolveId = vi.spyOn(reader, "resolveRepositoryById");
    const head = vi.spyOn(reader, "headCommit");
    const open = vi.spyOn(reader, "openFile");
    const list = vi.spyOn(reader, "listDirectory");
    expect(await (await importCourse()).json()).toEqual(imported);
    expect(await (await getFile(preview)).json()).toEqual(imported);
    expect(await (await getFile(folder)).json()).toEqual(listing);
    expect(await (await getFile(file)).text()).toBe("first slides");
    const range = await getFile(file, { Range: "bytes=-6" });
    expect(range.status).toBe(206);
    expect(await range.text()).toBe("slides");
    await expectError(await getFile(`${files}/more/SLIDES.PDF`), 429, "rate_limited");
    now += 60_000;
    await expectError(await getFile(file), 429, "rate_limited");
    expect(resolve).toHaveBeenCalledOnce();
    for (const call of [resolveId, head, open, list]) expect(call).not.toHaveBeenCalled();
  });

  it("rechecks warm name visibility when the class D entry expires", async () => {
    expect((await importCourse()).status).toBe(200);
    reader.setVisibility(42, true);
    now += 59_000;
    expect((await importCourse()).status).toBe(200);
    now += 1_000;
    await expectError(await importCourse(), 404, "course_not_found");
  });

  it("rechecks warm name-to-ID mapping before reusing an outline", async () => {
    expect((await importCourse()).status).toBe(200);
    reader.rename(42, "Course-Author", "Renamed");
    const next = "b".repeat(40);
    reader.addRepository(replacement, next);
    reader.setFile("course.yaml", manifest.replace('"title":"Example"', '"title":"Replacement"'), "100644", 77);
    now += 60_000;
    expect(await (await importCourse()).json()).toMatchObject({
      repoId: 77, sha: next, outline: { course: { title: "Replacement" } },
    });
  });

  it("retries an import after the adapter rejects a changed repository name", async () => {
    const resolve = vi.spyOn(reader, "resolveRepository");
    vi.spyOn(reader, "headCommit").mockRejectedValueOnce(new GitHubReadError("repo_changed"));
    await expectError(await importCourse(), 503, "repository_changed");
    expect([...stored.keys()].some((key) => key.includes("repo-head:"))).toBe(false);
    expect((await importCourse()).status).toBe(200);
    expect(resolve).toHaveBeenCalledTimes(2);
  });
});

describe("pinned preview files", () => {
  it.each([
    [readme, "# Example", "text/markdown; charset=utf-8"],
    [`${content}/first-lesson/slides`, "first slides", "application/pdf"],
    [`${content}/second-lesson/slides`, "second slides", "application/pdf"],
    [`${content}/assignment~first-lesson/slides`, "assignment slides", "application/pdf"],
  ])("serves %s at the pinned commit with public cache and security headers", async (path, body, mime) => {
    const response = await getFile(path);
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe(mime);
    expect(response.headers.get("Cache-Control")).toBe("public, max-age=60, immutable, must-revalidate");
    expect(response.headers.get("Content-Security-Policy")).toBe(csp);
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(await response.text()).toBe(body);
  });

  it("checks visibility by ID before accessing cached files and bounds downstream freshness", async () => {
    const resolve = vi.spyOn(reader, "resolveRepositoryById");
    const open = vi.spyOn(reader, "openFile");
    expect(await (await getFile(readme)).text()).toBe("# Example");
    reader.setVisibility(42, true);

    now += 59_999;
    const lastPublic = await getFile(readme);
    expect(await lastPublic.text()).toBe("# Example");
    const maxAge = Number(/max-age=(\d+)/u.exec(lastPublic.headers.get("Cache-Control") ?? "")?.[1]);
    expect(now + maxAge * 1_000).toBeLessThan(stored.get(`${root}/_lectale-cache/public-repo:v2:42`)!.expires + 60_000);

    now += 1;
    const denied = await getFile(readme);
    const missing = await getFile(readme.replace("/42/", "/99/"));
    expect(Object.fromEntries(denied.headers)).toEqual(Object.fromEntries(missing.headers));
    expect(await expectError(denied, 404, "course_not_found"))
      .toEqual(await expectError(missing, 404, "course_not_found"));
    expect(resolve.mock.calls).toEqual([[42], [42], [99]]);
    expect(open).toHaveBeenCalledTimes(2);
  });

  it("isolates file lookups and cache entries by commit SHA", async () => {
    expect(await (await getFile(readme)).text()).toBe("# Example");
    const updated = "b".repeat(40);
    reader.advance(42, updated);
    reader.setFile("course.yaml", manifest);
    reader.setFile("README.md", "# Updated");
    expect(await (await getFile(readme.replace(sha, updated))).text()).toBe("# Updated");
    expect(await (await getFile(readme)).text()).toBe("# Example");
  });

  it("keeps an extensionless file named outline distinct from the cached preview", async () => {
    await importCourse();
    expect(await (await getFile(`${content}/first-lesson/outline`)).text()).toBe("separate file");
    expect(await (await importCourse()).json()).toMatchObject({ repoId: 42, sha });
  });

  it.each(["first-lesson/missing", "first-lesson/link", "first-lesson/part%2Fname"])(
    "denies unavailable resource address %s without reading its bytes",
    async (address) => {
      await importCourse();
      const open = vi.spyOn(reader, "openFile");
      await expectError(await getFile(`${content}/${address}`), 404, "course_not_found");
      expect(open).not.toHaveBeenCalled();
    },
  );

  it("forwards the requested Range and streams the returned 206", async () => {
    await importCourse();
    const open = vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response("first", {
      status: 206, headers: { "Content-Range": "bytes 0-4/12", "Set-Cookie": "example=value" },
    }));
    const response = await getFile(`${content}/first-lesson/slides`, { Range: "bytes=0-4" });
    expect(open).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha, "materials/slides.pdf", "bytes=0-4");
    expect(response.status).toBe(206);
    expect(response.headers.get("Content-Range")).toBe("bytes 0-4/12");
    expect(response.headers.get("Accept-Ranges")).toBe("bytes");
    expect(response.headers.get("Content-Security-Policy")).toBe(csp);
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(response.headers.get("Set-Cookie")).toBeNull();
    expect(await response.text()).toBe("first");
  });

  it("preserves the upstream 416 and total size in the error response", async () => {
    await importCourse();
    const open = vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response(null, {
      status: 416, headers: { "Content-Range": "bytes */12" },
    }));
    const response = await getFile(`${content}/first-lesson/slides`, { Range: "bytes=999-" });
    expect(open).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha, "materials/slides.pdf", "bytes=999-");
    expect(response.headers.get("Content-Range")).toBe("bytes */12");
    expect(response.headers.get("Content-Security-Policy")).toBe(csp);
    await expectError(response, 416, "range_not_satisfiable");
  });

  it.each([["data", "data.unknown"], ["markup", "example.html"]])(
    "serves %s only as a download",
    async (id, name) => {
      const response = await getFile(`${content}/first-lesson/${id}`);
      expect(response.status).toBe(200);
      expect(response.headers.get("Content-Type")).toBe("application/octet-stream");
      expect(response.headers.get("Content-Disposition")).toBe(`attachment; filename="${name}"`);
      expect(response.headers.get("Content-Security-Policy")).toBe(csp);
      await response.arrayBuffer();
      },
  );
});

describe("bound preview links", () => {
  it("admits preview requests through their separate per-client limiter", async () => {
    const resolve = vi.spyOn(reader, "resolveRepositoryById");
    const limit = vi.fn(async () => ({ success: false }));
    const response = await app.request(`${root}${preview}`, {
      headers: { "X-Request-Id": "preview-test", "CF-Connecting-IP": "192.0.2.7" },
    }, { PREVIEW_RATE_LIMIT: { limit } });
    await expectError(response, 429, "rate_limited");
    expect(limit).toHaveBeenCalledExactlyOnceWith({ key: "192.0.2.7" });
    expect(resolve).not.toHaveBeenCalled();
  });

  it("reloads the same CoursePreview as import after the imported SHA leaves the branch", async () => {
    const imported = await (await importCourse()).json();
    reader.forcePush(42, "b".repeat(40));
    const compare = vi.spyOn(reader, "isReachable");
    expect(await (await getFile(preview)).json()).toEqual(imported);
    expect(compare).not.toHaveBeenCalled();
  });

  it("allows a default-branch ancestor that has not been imported", async () => {
    reader.advance(42, "b".repeat(40));
    const compare = vi.spyOn(reader, "isReachable");
    expect((await getFile(preview)).status).toBe(200);
    expect((await getFile(readme)).status).toBe(200);
    expect(compare).toHaveBeenCalledOnce();
  });

  it("rejects fork-only commits even though raw serves the fork's bytes under both names", async () => {
    const forkSha = "b".repeat(40);
    reader.addRepository({ ...replacement, owner: "Fork-Author" }, forkSha, 42);
    reader.setFile("README.md", "fork-only", "100644", 77);
    const raw = await reader.openFile("Course-Author", "Example", forkSha, "README.md");
    expect(await raw.text()).toBe("fork-only");
    const compare = vi.spyOn(reader, "isReachable");
    const open = vi.spyOn(reader, "openFile");
    for (const path of [preview, readme, `${files}/README.md`, `${content}/first-lesson/slides`, `${folders}/first-lesson/folder`]) {
      await expectError(await getFile(path.replace(sha, forkSha)), 404, "course_not_found");
    }
    expect(compare).toHaveBeenCalledOnce();
    expect(open).not.toHaveBeenCalled();
    expect([...stored.keys()].some((key) => /import-pin:|public-course/u.test(key))).toBe(false);
  });

  it("rejects an unpinned SHA orphaned by a force push", async () => {
    reader.forcePush(42, "b".repeat(40));
    await expectError(await getFile(preview), 404, "course_not_found");
  });

  it("rechecks a positive comparison after its class B entry expires", async () => {
    expect((await getFile(preview)).status).toBe(200);
    reader.forcePush(42, "b".repeat(40));
    now += 299_999;
    expect((await getFile(preview)).status).toBe(200);
    now += 1;
    await expectError(await getFile(preview), 404, "course_not_found");
  });

  it("takes a fresh default tip for an unpinned SHA despite a warm import head", async () => {
    reader.advance(42, "b".repeat(40));
    reader.setFile("course.yaml", manifest);
    expect((await importCourse()).status).toBe(200);
    const head = vi.spyOn(reader, "headCommit");
    reader.forcePush(42, "c".repeat(40));
    await expectError(await getFile(preview), 404, "course_not_found");
    expect(head).toHaveBeenCalledTimes(2);
  });

  it("discards a comparison when the default branch switches during the compare", async () => {
    const tip = "b".repeat(40);
    const otherTip = "c".repeat(40);
    reader.advance(42, tip);
    const reachability = reader.isReachable.bind(reader);
    const compare = vi.spyOn(reader, "isReachable").mockImplementationOnce(async (...args) => {
      reader.switchDefaultBranch(42, "other", otherTip);
      expect(await reachability(...args)).toBe(true);
      return true;
    });
    const open = vi.spyOn(reader, "openFile");
    await expectError(await getFile(preview), 503, "repository_changed");
    expect([...stored.keys()].some((key) => key.includes("reachable:"))).toBe(false);
    await expectError(await getFile(preview), 404, "course_not_found");
    expect(compare.mock.calls.map(([, requested, base]) => [requested, base])).toEqual([[sha, tip], [sha, otherTip]]);
    expect(open).not.toHaveBeenCalled();
  });

  it("reads a reachable SHA without a name lookup when the old name serves the same commit", async () => {
    expect((await importCourse()).status).toBe(200);
    const resolve = vi.spyOn(reader, "resolveRepository");
    const open = reader.openFile.bind(reader);
    vi.spyOn(reader, "openFile").mockImplementationOnce((...args) => {
      reader.rename(42, "Course-Author", "Renamed");
      reader.addRepository(replacement, sha, 42);
      return open(...args);
    });
    expect(await (await getFile(readme)).text()).toBe("# Example");
    expect(resolve).not.toHaveBeenCalled();
  });
});

describe("pinned repository paths and folder resources", () => {
  it.each(["missing", "invalid", "oversized"])("denies file and folder requests for a %s manifest", async (kind) => {
    // A valid course at another SHA of the same repository cannot authorize these paths.
    expect((await importCourse()).status).toBe(200);
    const invalidSha = "d".repeat(40);
    reader.advance(42, invalidSha);
    reader.setFile("materials/slides.pdf", "not a course file");
    if (kind === "invalid") reader.setFile("course.yaml", "{");
    if (kind === "oversized") reader.setFile("course.yaml", "a".repeat(1024 * 1024 + 1));
    const open = vi.spyOn(reader, "openFile");
    const list = vi.spyOn(reader, "listDirectory");
    const missing = await expectError(await getFile(preview.replace("/42/", "/99/")), 404, "course_not_found");
    for (const path of [`${files}/materials/slides.pdf`, `${folders}/first-lesson/folder`]) {
      expect(await expectError(await getFile(path.replace(sha, invalidSha)), 404, "course_not_found")).toEqual(missing);
    }
    expect(open.mock.calls.map(([, , , path]) => path)).toEqual(kind === "invalid" ? ["course.yaml"] : []);
    expect(list.mock.calls.map(([, , path]) => path)).toEqual([""]);
  });

  it("decodes an allowed path once and serves unlisted files from a validated course", async () => {
    reader.setFile("assets/cover.png", [137, 80, 78, 71, 13, 10, 26, 10, 1]);
    const response = await getFile(`${files}/assets/%63over.png`);
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe("image/png");
    expect(response.headers.get("Content-Security-Policy")).toBe(csp);
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(new Uint8Array(await response.arrayBuffer())).toEqual(new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 1]));
  });

  it.each(["a%2fb", "a%5Cb", "a/%252e%252e/b", "a/%2E%2E%2Fb", ".git/config", "a//b", "%00", "%", "a".repeat(501)])(
    "rejects unsafe paths %s before contacting GitHub",
    async (path) => {
      const resolve = vi.spyOn(reader, "resolveRepositoryById");
      await expectError(await getFile(`${files}/${path}`), 404, "course_not_found");
      expect(resolve).not.toHaveBeenCalled();
    },
  );

  it("returns and briefly caches raw misses without listing the parent directory", async () => {
    expect((await importCourse()).status).toBe(200);
    const open = vi.spyOn(reader, "openFile");
    const list = vi.spyOn(reader, "listDirectory");
    const path = `${files}/missing/nope.txt`;
    await expectError(await getFile(path), 404, "course_not_found");
    await expectError(await getFile(path), 404, "course_not_found");
    expect(open).toHaveBeenCalledOnce();
    expect(list).not.toHaveBeenCalled();
    now += 30_000;
    await expectError(await getFile(path), 404, "course_not_found");
    expect(open).toHaveBeenCalledTimes(2);
  });

  it.each(["symlink", "submodule"])("never returns bytes for a %s", async (id) => {
    await expectError(await getFile(`${content}/first-lesson/${id}`), 404, "course_not_found");
    await expectError(await getFile(`${files}/${id}.txt`), 404, "course_not_found");
    expect([...stored.keys()].some((key) => key.includes("public-course:v1:"))).toBe(false);
  });

  it("advertises the folder route and lists only direct safe entries within maxEntries", async () => {
    reader.setFile("materials/subdir/child.txt", "nested");
    reader.setFile("materials/third.txt", "filtered by maxEntries");
    reader.setFile("materials/link.txt", "third.txt", "120000");
    const imported = await (await importCourse()).json();
    const folder = `${folders}/first-lesson/folder`;
    expect(imported).toMatchObject({ outline: { nodes: expect.arrayContaining([
      expect.objectContaining({ id: "first-lesson", resources: expect.arrayContaining([
        expect.objectContaining({ id: "folder", href: folder }),
      ]) }),
    ]) } });
    const list = vi.spyOn(reader, "listDirectory");
    expect(await (await getFile(folder)).json()).toEqual({ entries: [
      { name: "slides.pdf", type: "file", size: 12, href: `${files}/materials/slides.pdf` },
      { name: "subdir", type: "directory", size: 0 },
    ] });
    await expectError(await getFile(`${folders}/first-lesson/slides`), 404, "course_not_found");
    await expectError(await getFile(`${content}/first-lesson/folder`), 404, "course_not_found");
    expect(list).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({ id: 42 }), sha, "materials");
  });

  it("walks an opted-in folder in filename order and stops before descending at maxEntries", async () => {
    reader.setFile("course.yaml", manifest.replace('"maxEntries":2', '"maxEntries":3,"recursive":true'));
    reader.setFile("materials/nested/child.txt", "child");
    reader.setFile("materials/nested/deeper/other.txt", "outside the entry cap");
    reader.setFile("materials/nested/.hidden", "hidden");
    reader.setFile("materials/nested/alias", "child.txt", "120000");
    reader.setFile("outside/other.txt", "outside the folder root");
    const list = vi.spyOn(reader, "listDirectory");
    expect(await (await getFile(`${folders}/first-lesson/folder`)).json()).toEqual({ entries: [
      { name: "nested", type: "directory", size: 0 },
      { name: "nested/child.txt", type: "file", size: 5, href: `${files}/materials/nested/child.txt` },
      { name: "nested/deeper", type: "directory", size: 0 },
    ] });
    expect(list.mock.calls.map(([, , path]) => path)).toEqual(["", "materials", "materials/nested"]);
    expect(await (await getFile(`${files}/materials/nested/child.txt`)).text()).toBe("child");
  });

  it("defaults folders to 100 entries", async () => {
    reader.setFile("course.yaml", manifest.replace(',"maxEntries":2', ""));
    for (let count = 0; count < 101; count++) {
      reader.setFile(`materials/note-${String(count).padStart(3, "0")}.txt`, "notes");
    }
    const response = await getFile(`${folders}/first-lesson/folder`);
    expect(response.status).toBe(200);
    expect((await response.json<{ entries: unknown[] }>()).entries).toHaveLength(100);
  });

  it.each([
    ["markup.svg", "application/octet-stream"],
    ["markup.htm", "application/octet-stream"],
    ["markup.xhtml", "application/octet-stream"],
    ["disguised.png", "application/octet-stream"],
    ["example.js", "text/plain; charset=utf-8"],
    ["example.ipynb", "text/plain; charset=utf-8"],
  ])("assigns safe MIME to hostile bytes in %s", async (name, mime) => {
    reader.setFile(name, "<svg><script>throw 1</script></svg>");
    const response = await getFile(`${files}/${name}`);
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe(mime);
    expect(response.headers.get("Content-Security-Policy")).toBe(csp);
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    if (mime === "application/octet-stream") expect(response.headers.get("Content-Disposition")).toContain("attachment");
    expect(await response.text()).toContain("<svg>");
  });
});

describe("single ranges", () => {
  const path = `${content}/first-lesson/slides`;

  it.each([
    ["valid PNG", [137, 80, 78, 71, 13, 10, 26, 10, 42, 43], "image/png", null],
    ["disguised PNG", [60, 115, 118, 103, 62, 32, 32, 32, 42, 43], "application/octet-stream", 'attachment; filename="cover.png"'],
  ] as const)("keeps MIME and disposition stable for a %s across cold ranges, full reads and cache", async (_label, bytes, mime, disposition) => {
    reader.setFile("cover.png", [...bytes]);
    expect((await importCourse()).status).toBe(200);
    const open = vi.spyOn(reader, "openFile");
    for (const [range, status, expected] of [
      ["bytes=-2", 206, bytes.slice(8)],
      ["bytes=0-0", 206, bytes.slice(0, 1)],
      [null, 200, bytes],
      ["bytes=-2", 206, bytes.slice(8)],
      [null, 200, bytes],
    ] as const) {
      const response = await getFile(`${files}/cover.png`, range ? { Range: range } : undefined);
      expect(response.status).toBe(status);
      expect(response.headers.get("Content-Type")).toBe(mime);
      expect(response.headers.get("Content-Disposition")).toBe(disposition);
      expect([...new Uint8Array(await response.arrayBuffer())]).toEqual(expected);
    }
    expect(open.mock.calls.map(([, , , , range]) => range)).toEqual(["bytes=-2", "bytes=0-9", "bytes=0-0", undefined]);
  });

  it("rejects a cold raster range when the signature probe returns the wrong interval", async () => {
    reader.setFile("cover.png", [137, 80, 78, 71, 13, 10, 26, 10, 42, 43]);
    expect((await importCourse()).status).toBe(200);
    const open = reader.openFile.bind(reader);
    vi.spyOn(reader, "openFile").mockImplementation((...args) => args[4] === "bytes=0-9"
      ? Promise.resolve(new Response("bad probe", { status: 206, headers: { "Content-Range": "bytes 0-8/10" } }))
      : open(...args));
    await expectError(await getFile(`${files}/cover.png`, { Range: "bytes=-2" }), 502, "github_unavailable");
  });

  it.each(["bytes=0-1,5-8", "bytes=6-5", "bytes=-0", "bytes=-", "none=5-6", "bytes=9007199254740992-", `bytes=${"0".repeat(128)}-`])(
    "rejects invalid ranges %s before opening the file",
    async (range) => {
      await importCourse();
      const open = vi.spyOn(reader, "openFile");
      await expectError(await getFile(path, { Range: range }), 416, "range_not_satisfiable");
      expect(open).not.toHaveBeenCalled();
    },
  );

  it.each([
    ["bytes=0-3", "bytes 1-4/12", 206],
    ["bytes=0-3", "bytes 0-3/13", 206],
    ["bytes=0-3", "bytes 0-4/12", 206],
    ["bytes=0-3", "bytes */12", 416],
    ["bytes=0-3", "bytes 0-3/*", 206],
    ["bytes=0-3", "bytes 0-3/12", 200],
  ])("rejects upstream status or interval mismatch for %s and %s (%s)", async (range, actual, status) => {
    await importCourse();
    vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response("data", {
      status, headers: { "Content-Range": actual },
    }));
    await expectError(await getFile(path, { Range: range }), 502, "github_unavailable");
    expect([...stored.keys()].some((key) => key.includes("public-course:v1:"))).toBe(false);
  });

  it("rejects a known out-of-bounds interval before opening the file", async () => {
    expect((await getFile(`${folders}/first-lesson/folder`)).status).toBe(200);
    const open = vi.spyOn(reader, "openFile");
    const response = await getFile(path, { Range: "bytes=12-" });
    expect(response.headers.get("Content-Range")).toBe("bytes */12");
    await expectError(response, 416, "range_not_satisfiable");
    expect(open).not.toHaveBeenCalled();
  });

  it("stops a streamed upstream body that exceeds its advertised interval", async () => {
    await importCourse();
    vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response("too many bytes", {
      status: 206, headers: { "Content-Range": "bytes 0-3/12" },
    }));
    const response = await getFile(path, { Range: "bytes=0-3" });
    expect(response.status).toBe(206);
    await expect(response.arrayBuffer()).rejects.toThrow();
  });

  it("requests a normalized interval from a cache with native range support", async () => {
    expect(await (await getFile(path)).text()).toBe("first slides");
    const originalMatch = cache.match.bind(cache);
    const open = vi.spyOn(reader, "openFile");
    const match = vi.spyOn(cache, "match").mockImplementation((request, options) => {
      if (request instanceof Request && request.headers.get("Range") === "bytes=6-11") {
        return Promise.resolve(new Response("slides", {
          status: 206, headers: { "Content-Range": "bytes 6-11/12" },
        }));
      }
      return originalMatch(request, options);
    });
    const response = await getFile(path, { Range: "bytes=-6" });
    expect(response.status).toBe(206);
    expect(await response.text()).toBe("slides");
    expect(match.mock.calls.some(([request]) =>
      request instanceof Request && request.headers.get("Range") === "bytes=6-11")).toBe(true);
    expect(open).not.toHaveBeenCalled();
  });

  it("uses the complete cache for closed, open, suffix and unsatisfiable ranges", async () => {
    expect(await (await getFile(path)).text()).toBe("first slides");
    const open = vi.spyOn(reader, "openFile");
    for (const [range, interval, expected] of [
      ["bytes=0-0", "bytes 0-0/12", "f"],
      ["bytes=6-", "bytes 6-11/12", "slides"],
      ["bytes=-6", "bytes 6-11/12", "slides"],
      ["bytes=6-99", "bytes 6-11/12", "slides"],
    ] as const) {
      const response = await getFile(path, { Range: range });
      expect(response.status).toBe(206);
      expect(response.headers.get("Content-Range")).toBe(interval);
      expect(await response.text()).toBe(expected);
    }
    const rejected = await getFile(path, { Range: "bytes=12-" });
    expect(rejected.headers.get("Content-Range")).toBe("bytes */12");
    await expectError(rejected, 416, "range_not_satisfiable");
    expect(open).not.toHaveBeenCalled();
  });
});
