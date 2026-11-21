import { beforeEach, describe, expect, it, vi } from "vitest";
import { GitHubReadError } from "../../src/github/reader";
import { createApp } from "../../src/index";
import { FakeGitHubReader } from "./fake-github-reader";

const root = "https://lectale.test";
const repoUrl = "https://github.com/Course-Author/Example";
const sha = "a".repeat(40);
const content = `/api/preview/42/${sha}/content`;
const readme = `/api/preview/42/${sha}/readme`;
const manifest = JSON.stringify({
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
});

let reader: FakeGitHubReader;
let app: ReturnType<typeof createApp>;
let stored: Map<string, Response>;
let tasks: Promise<unknown>[];

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
  stored = new Map();
  tasks = [];
  app = createApp(reader, {
    async match(key: Request | string) {
      return stored.get(typeof key === "string" ? key : key.url)?.clone();
    },
    async put(key: Request | string, response: Response) {
      stored.set(typeof key === "string" ? key : key.url, response);
    },
  });
});

function importCourse(url = repoUrl) {
  return app.request(`${root}/api/courses/import`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Request-Id": "preview-test" },
    body: JSON.stringify({ url }),
  });
}

function getFile(path: string, headers?: HeadersInit) {
  const requestHeaders = new Headers(headers);
  requestHeaders.set("X-Request-Id", "preview-test");
  return app.request(`${root}${path}`, { headers: requestHeaders }, undefined, {
    waitUntil: (promise) => { tasks.push(promise); },
    passThroughOnException: () => undefined,
    props: {},
  });
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
    const tree = vi.spyOn(reader, "tree");
    const open = vi.spyOn(reader, "openFile");

    const response = await importCourse(`${repoUrl}.git/`);
    expect(response.status).toBe(200);
    expect(response.headers.get("Set-Cookie")).toBeNull();
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
    expect(head).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example");
    expect(tree).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha);
    expect(open).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha, "course.yaml");

    expect(await (await importCourse(repoUrl.toLowerCase())).json()).toEqual(first);
    expect(resolve).toHaveBeenCalledTimes(1);
    expect(head).toHaveBeenCalledTimes(1);
    expect(tree).toHaveBeenCalledTimes(1);
    expect(open).toHaveBeenCalledTimes(1);
    expect(stored.get(`${root}/_lectale-cache/repo-preview:v1:course-author:example`)?.headers.get("Cache-Control"))
      .toBe("public, max-age=60");
    expect(stored.has(`${root}/_lectale-cache/public-course-outline:v1:42:${sha}`)).toBe(true);
  });

  it("returns the same response for private and missing repositories", async () => {
    const head = vi.spyOn(reader, "headCommit");
    const original = reader.repository!;
    reader.repository = { ...original, private: true };
    const denied = await expectError(await importCourse(), 404, "course_not_found");
    reader.repository = undefined;
    expect(await expectError(await importCourse(), 404, "course_not_found")).toEqual(denied);
    expect(head).not.toHaveBeenCalled();
    expect(stored.size).toBe(0);
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
    expect(stored.size).toBe(0);
  });

  it("reports a missing manifest and an absent README through their contract fields", async () => {
    reader.removeFile("course.yaml");
    await expectError(await importCourse(), 422, "manifest_missing");
    reader.setFile("course.yaml", manifest);
    reader.removeFile("README.md");
    const response = await importCourse();
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ readmePresent: false });
    await expectError(await getFile(readme), 404, "course_not_found");
  });

  it("rejects an oversized file from its Git tree entry without opening it", async () => {
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

  it("does not infer file absence from a truncated Git tree", async () => {
    reader.truncated = true;
    await expectError(await importCourse(), 502, "repository_tree_truncated");
    expect(stored.size).toBe(0);
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
    expect(response.headers.get("Cache-Control")).toBe("public, max-age=300, immutable");
    expect(response.headers.get("Content-Security-Policy")).toBe("sandbox");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(await response.text()).toBe(body);
    await Promise.all(tasks);
  });

  it("checks visibility by ID before accessing cached files, even after a public read", async () => {
    const resolve = vi.spyOn(reader, "resolveRepositoryById");
    const tree = vi.spyOn(reader, "tree");
    const open = vi.spyOn(reader, "openFile");
    expect(await (await getFile(readme)).text()).toBe("# Example");
    await Promise.all(tasks);
    expect(await (await getFile(readme)).text()).toBe("# Example");
    expect(tree).toHaveBeenCalledTimes(1);
    expect(open).toHaveBeenCalledTimes(2);

    reader.repository = { ...reader.repository!, private: true };
    const denied = await expectError(await getFile(readme), 404, "course_not_found");
    reader.repository = undefined;
    expect(await expectError(await getFile(readme), 404, "course_not_found")).toEqual(denied);
    expect(resolve.mock.calls).toEqual([[42], [42], [42], [42]]);
    expect(open).toHaveBeenCalledTimes(2);
  });

  it("isolates file lookups and cache entries by commit SHA", async () => {
    expect(await (await getFile(readme)).text()).toBe("# Example");
    await Promise.all(tasks);
    reader.sha = "b".repeat(40);
    reader.setFile("course.yaml", manifest);
    reader.setFile("README.md", "# Updated");
    expect(await (await getFile(readme.replace(sha, reader.sha))).text()).toBe("# Updated");
    await Promise.all(tasks);
    expect(await (await getFile(readme)).text()).toBe("# Example");
  });

  it("keeps an extensionless file named outline distinct from the cached preview", async () => {
    await importCourse();
    expect(await (await getFile(`${content}/first-lesson/outline`)).text()).toBe("separate file");
    await Promise.all(tasks);
    expect(await (await importCourse()).json()).toMatchObject({ repoId: 42, sha });
  });

  it.each(["first-lesson/missing", "first-lesson/link", "first-lesson/symlink", "first-lesson/part%2Fname"])(
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
    expect(response.headers.get("Content-Security-Policy")).toBe("sandbox");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(response.headers.get("Set-Cookie")).toBeNull();
    expect(await response.text()).toBe("first");
    expect(stored.size).toBe(2);
  });

  it("preserves the upstream 416 and total size in the error response", async () => {
    await importCourse();
    const open = vi.spyOn(reader, "openFile").mockResolvedValueOnce(new Response(null, {
      status: 416, headers: { "Content-Range": "bytes */12" },
    }));
    const response = await getFile(`${content}/first-lesson/slides`, { Range: "bytes=999-" });
    expect(open).toHaveBeenCalledExactlyOnceWith("Course-Author", "Example", sha, "materials/slides.pdf", "bytes=999-");
    expect(response.headers.get("Content-Range")).toBe("bytes */12");
    expect(response.headers.get("Content-Security-Policy")).toBe("sandbox");
    await expectError(response, 416, "range_not_satisfiable");
  });

  it.each([["data", "data.unknown"], ["markup", "example.html"]])(
    "serves %s only as a download",
    async (id, name) => {
      const response = await getFile(`${content}/first-lesson/${id}`);
      expect(response.status).toBe(200);
      expect(response.headers.get("Content-Type")).toBe("application/octet-stream");
      expect(response.headers.get("Content-Disposition")).toBe(`attachment; filename="${name}"`);
      expect(response.headers.get("Content-Security-Policy")).toBe("sandbox");
      await response.arrayBuffer();
      await Promise.all(tasks);
    },
  );
});
