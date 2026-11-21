/// <reference types="vite/client" />

import { describe, expect, it } from "vitest";
import autoGrading from "../../../../spec/v4.0/examples/auto-grading.course.yaml?raw";
import complete from "../../../../spec/v4.0/examples/complete.course.yaml?raw";
import fullTemplate from "../../../../spec/v4.0/templates/course-full.template.yaml?raw";
import minimalTemplate from "../../../../spec/v4.0/templates/course.yaml?raw";
import {
  validateCourseManifest,
  type CourseManifest,
  type ValidationError,
} from "../../src/contract/course-manifest";

const course = {
  id: "sample",
  title: "Sample course",
  summary: "Course for validator fixtures",
  language: "en",
  version: "1.0.0",
};
const base = { schemaVersion: 3, course, outline: [], assignments: [] };
const lesson = { kind: "lesson", id: "lesson", title: "Lesson", resources: [] };
const assignment: CourseManifest["assignments"][number] = {
  id: "exercise",
  title: "Exercise",
  materials: [],
  submission: {
    allowedExtensions: [".pdf"],
    maxFileBytes: 100,
    maxAttemptBytes: 100,
    maxFiles: 1,
    maxAttempts: 1,
  },
  grading: { mode: "manual", maxPoints: 100 },
};
const reference = { kind: "assignment", id: "exercise-ref", assignmentId: "exercise" };
const resource = { id: "notes", title: "Notes", type: "pdf", path: "notes.pdf" };
const video = { id: "recording", title: "Recording", type: "video" };
const youtube = { ...video, provider: "youtube", url: "https://youtu.be/ABCDEFGHIJK" };
const vimeo = { ...video, provider: "vimeo", url: "https://player.vimeo.com/video/123" };

function document(fields: Record<string, unknown> = {}): string {
  // JSON syntax is valid YAML 1.2 and keeps generated boundary fixtures compact.
  return JSON.stringify({ ...base, ...fields });
}

function withResources(...resources: unknown[]): string {
  return document({ outline: [{ ...lesson, resources }] });
}

function withAssignment(fields: Record<string, unknown> = {}): string {
  return document({ outline: [reference], assignments: [{ ...assignment, ...fields }] });
}

function valid(text: string | Uint8Array): CourseManifest {
  const result = validateCourseManifest(text);
  if (!result.ok) throw new Error(JSON.stringify(result.errors));
  return result.manifest;
}

function invalid(text: string | Uint8Array, code: ValidationError["code"], path: string): ValidationError[] {
  const result = validateCourseManifest(text);
  if (result.ok) throw new Error(`Expected ${code} at ${path || "the document root"}`);
  expect(result.errors).toContainEqual(expect.objectContaining({ code, path }));
  return result.errors;
}

describe("bundled course fixtures", () => {
  it.each([
    ["complete.course.yaml", complete],
    ["auto-grading.course.yaml", autoGrading],
    ["course-full.template.yaml", fullTemplate],
    ["course.yaml", minimalTemplate],
  ])("accepts %s", (_name, text) => {
    expect(valid(text).schemaVersion).toBe(3);
  });
});

describe("input size and YAML 1.2", () => {
  const maxBytes = 1024 * 1024;
  const padded = `${minimalTemplate}\n#`;

  it("accepts exactly 1 MiB", () => {
    valid(padded + "x".repeat(maxBytes - new TextEncoder().encode(padded).length));
  });

  it("rejects oversize ASCII input before YAML syntax", () => {
    invalid("[".repeat(maxBytes + 1), "MANIFEST_TOO_LARGE", "");
  });

  it("counts UTF-8 bytes for the size limit", () => {
    invalid(padded + "🟣".repeat(maxBytes / 4), "MANIFEST_TOO_LARGE", "");
  });

  it("preserves YAML 1.2 scalar typing and treats quoted syntax as text", () => {
    const source = minimalTemplate
      .replace(/^  title: .+$/m, "  title: yes")
      .replace(/^  summary: .+$/m, "  summary: '&anchor *alias !tag <<'");
    expect(valid(`%YAML 1.2\n---\n${source}\n...\n`).course).toMatchObject({
      title: "yes",
      summary: "&anchor *alias !tag <<",
    });
  });

  it.each<{ name: string; text: string; code: ValidationError["code"]; path?: string }>([
    { name: "YAML 1.1", text: `%YAML 1.1\n---\n${minimalTemplate}`, code: "YAML_VERSION_UNSUPPORTED" },
    { name: "an empty stream", text: "# no document\n", code: "YAML_SINGLE_DOCUMENT" },
    { name: "a sequence at the root", text: "[]", code: "YAML_SINGLE_DOCUMENT" },
    { name: "multiple documents", text: `${minimalTemplate}\n---\n{}`, code: "YAML_SINGLE_DOCUMENT" },
    { name: "invalid syntax", text: "course: [\n", code: "YAML_INVALID" },
    { name: "ill-formed Unicode", text: "\ud800", code: "YAML_INVALID" },
    { name: "a complex mapping key", text: "{ [id]: course }", code: "YAML_INVALID" },
    { name: "a numeric mapping key", text: "{ 3: course }", code: "YAML_INVALID" },
    { name: "non-finite numbers", text: "course: { estimatedMinutes: .nan }", code: "YAML_INVALID", path: "/course/estimatedMinutes" },
    { name: "duplicate keys", text: "course: { title: First, 'title': Second }", code: "YAML_DUPLICATE_KEY", path: "/course/title" },
    { name: "an anchor alone", text: "course: &course {}", code: "YAML_REFERENCE_FORBIDDEN", path: "/course" },
    { name: "an alias alone", text: "course: *course", code: "YAML_REFERENCE_FORBIDDEN", path: "/course" },
    { name: "a nested alias bomb", text: "a: &a [item]\nb: &b [*a, *a, *a]\nc: [*b, *b, *b]", code: "YAML_REFERENCE_FORBIDDEN", path: "/a" },
    { name: "a literal merge key", text: "course: { <<: { title: Example } }", code: "YAML_MERGE_KEY_FORBIDDEN", path: "/course/<<" },
    { name: "a custom tag", text: "course: { title: !custom Example }", code: "YAML_TAG_FORBIDDEN", path: "/course/title" },
    { name: "a verbatim custom tag", text: "course: { title: !<tag:example.org,2026:custom> Example }", code: "YAML_TAG_FORBIDDEN", path: "/course/title" },
    { name: "an explicit built-in tag", text: "schemaVersion: !!int 3", code: "YAML_TAG_FORBIDDEN", path: "/schemaVersion" },
  ])("rejects $name", ({ text, code, path = "" }) => {
    invalid(text, code, path);
  });

  it("reports YAML syntax with a line and column without quoting the source", () => {
    const input = "stray-source-text-".repeat(20);
    const [error] = invalid(`course: "\n${input}`, "YAML_INVALID", "");
    expect(error?.message).toMatch(/line \d+, column \d+/);
    expect(error?.message).not.toContain(input.slice(0, 81));
  });

  it("rejects well-formed UTF-8 bytes above the byte cap before parsing", () => {
    invalid(new Uint8Array(maxBytes + 1), "MANIFEST_TOO_LARGE", "");
  });

  it("accepts UTF-8 bytes, including non-ASCII content and a BOM", () => {
    const text = document({ course: { ...course, title: "Leçon" } });
    expect(valid(new TextEncoder().encode(`\uFEFF${text}`)).course.title).toBe("Leçon");
  });

  it("rejects malformed UTF-8 bytes that replacement decoding would accept", () => {
    const bytes = new TextEncoder().encode(`${minimalTemplate}\n# `);
    invalid(new Uint8Array([...bytes, 0xc3, 0x28]), "YAML_INVALID", "");
  });

  it.each([
    `x: ${"[".repeat(10000)}0${"]".repeat(10000)}`,
    `x:\n  ${"- ".repeat(10000)}0`,
  ])("enforces the nesting budget before YAML composition (%#)", (text) => {
    const [error] = invalid(text, "YAML_INVALID", "");
    expect(error?.message).toContain("nesting budget");
  });

  it("enforces the node budget on wide YAML before composition", () => {
    const [error] = invalid(`x: [${"0,".repeat(250_000)}0]`, "YAML_INVALID", "");
    expect(error?.message).toContain("node budget");
  });
});

describe("Draft 2020-12 schema", () => {
  it.each<[string, string, string]>([
    ["schema version 1", document({ schemaVersion: 1 }), "/schemaVersion"],
    ["schema version 2", document({ schemaVersion: 2 }), "/schemaVersion"],
    ["a quoted schema version", document({ schemaVersion: "3" }), "/schemaVersion"],
    ["a missing field", document({ course: { ...course, title: undefined } }), "/course"],
    ["an unknown field", document({ course: { ...course, "a~/b": 1 } }), "/course/a~0~1b"],
    ["authorization fields", document({ course: { ...course, role: "admin" } }), "/course/role"],
    ["commerce terms", document({ price: 100 }), "/price"],
    ["an invalid outline kind", document({ outline: [{ ...lesson, kind: "unknown" }] }), "/outline/0"],
    ["a non-HTTPS homepage", document({ course: { ...course, homepage: "http://example.org" } }), "/course/homepage"],
    ["a non-HTTPS author URL", document({ course: { ...course, authors: [{ name: "Author", url: "http://example.org" }] } }), "/course/authors/0/url"],
    ["a non-HTTPS resource URL", withResources({ ...youtube, url: "http://youtu.be/ABCDEFGHIJK" }), "/outline/0/resources/0/url"],
    ["a missing resource location", withResources({ ...resource, path: undefined }), "/outline/0/resources/0"],
    ["two resource locations", withResources({ ...resource, url: "https://example.org" }), "/outline/0/resources/0"],
    ["a URL-backed folder", withResources({ ...resource, type: "folder", path: undefined, url: "https://example.org" }), "/outline/0/resources/0"],
    ["a repository-backed external resource", withResources({ ...resource, type: "external" }), "/outline/0/resources/0"],
    ["an out-of-range folder limit", withResources({ ...resource, type: "folder", maxEntries: 1001 }), "/outline/0/resources/0/maxEntries"],
    ["folder settings on a file", withResources({ ...resource, maxEntries: 10 }), "/outline/0/resources/0"],
    ["a provider on a file-backed video", withResources({ ...video, path: "recording.mp4", provider: "youtube" }), "/outline/0/resources/0"],
    ["a provider on a non-video", withResources({ ...youtube, type: "external" }), "/outline/0/resources/0/type"],
    ["a missing video provider", withResources({ ...youtube, provider: undefined }), "/outline/0/resources/0"],
    ["an unsupported video provider", withResources({ ...youtube, provider: "other" }), "/outline/0/resources/0/provider"],
    ["an impossible timestamp", withAssignment({ releaseAt: "2026-02-30T11:00:00Z" }), "/assignments/0/releaseAt"],
    ["a time without a zone", withAssignment({ releaseAt: "2026-11-21T11:00:00" }), "/assignments/0/releaseAt"],
    ["an absolute file size above the schema cap", withAssignment({ submission: { ...assignment.submission, maxFileBytes: 5368709121 } }), "/assignments/0/submission/maxFileBytes"],
    ["automatic grading that lacks configuration", withAssignment({ grading: { mode: "automatic", maxPoints: 100 } }), "/assignments/0/grading"],
  ])("rejects %s", (_name, text, path) => {
    invalid(text, "SCHEMA_INVALID", path);
  });

  it("rejects duplicate string extensions within the array limit", () => {
    const submission = { ...assignment.submission, allowedExtensions: [".pdf", ".txt", ".pdf"] };
    const [error] = invalid(withAssignment({ submission }), "SCHEMA_INVALID", "/assignments/0/submission/allowedExtensions");
    expect(error?.message).toContain("unique");
  });

  it("quickly rejects a large over-limit array of distinct extensions", () => {
    const allowedExtensions = Array.from({ length: 55_000 }, (_, index) => `.${index.toString(36)}`);
    const text = withAssignment({ submission: { ...assignment.submission, allowedExtensions } });
    const start = performance.now();
    const [error] = invalid(text, "SCHEMA_INVALID", "/assignments/0/submission/allowedExtensions");
    expect(performance.now() - start).toBeLessThan(3000);
    expect(error?.message).toContain("30 items");
  });

  it.each<[string, string, number]>([
    [document({ course: { ...course, tags: Array(41).fill("tag") } }), "/course/tags", 40],
    [document({ course: { ...course, authors: Array(31).fill(null) } }), "/course/authors", 30],
    [document({ outline: Array(251).fill(null) }), "/outline", 250],
    [document({ outline: [{ kind: "module", children: Array(251).fill(null) }] }), "/outline/0/children", 250],
    [document({ assignments: Array(501).fill(null) }), "/assignments", 500],
    [withResources(...Array(101).fill(null)), "/outline/0/resources", 100],
    [withAssignment({ materials: Array(101).fill(null) }), "/assignments/0/materials", 100],
  ])("reports an over-limit list before inspecting its items (%#)", (text, path, limit) => {
    const errors = invalid(text, "SCHEMA_INVALID", path);
    expect(errors).toEqual([{ code: "SCHEMA_INVALID", path, message: `Limit this list to ${limit} items.` }]);
  });

  it("accepts optional HTTPS URLs, generic file types and non-authority display hints", () => {
    valid(document({
      course: { ...course, homepage: "https://example.org", authors: [{ name: "Author", url: "https://example.org" }] },
      outline: [{ ...lesson, resources: [
        { ...resource, type: "file", path: "artifact.bin", preview: false, download: false },
        { ...resource, id: "reading", type: "external", path: undefined, url: "https://example.org" },
      ] }],
      display: { showFileDownloads: false },
    }));
  });

  it("accepts explicit and default directory entry limits", () => {
    valid(withResources(
      { ...resource, type: "folder", path: "materials" },
      { ...resource, id: "attachments", type: "folder", path: "attachments", maxEntries: 1000, recursive: true },
    ));
  });

  it("rejects a workflow outside the workflow directory", () => {
    const source = autoGrading.replace(".github/workflows/grade-submission.yml", "../grade-submission.yml");
    invalid(source, "SCHEMA_INVALID", "/assignments/0/grading/automatic/workflowPath");
  });

  it("rejects automatic configuration in manual mode", () => {
    const source = autoGrading.replace("mode: hybrid", "mode: manual");
    invalid(source, "SCHEMA_INVALID", "/assignments/0/grading");
  });

  it("rejects automatic release in hybrid mode", () => {
    const source = autoGrading.replace("releasePolicy: review-required", "releasePolicy: auto-release");
    invalid(source, "SCHEMA_INVALID", "/assignments/0/grading/automatic/releasePolicy");
  });

  it("keeps course text inert through validation", () => {
    const description = "<script>course content</script>";
    expect(valid(document({ course: { ...course, description } })).course.description).toBe(description);
  });

  it("preserves the exact child pointer and omits errors from unrelated outline kinds", () => {
    const errors = invalid(withResources({ ...resource, path: "../notes.pdf" }), "SCHEMA_INVALID", "/outline/0/resources/0/path");
    expect(errors[0]?.path).toBe("/outline/0/resources/0/path");
    expect(errors.some(({ message }) => message.includes('"assignmentId"'))).toBe(false);
    expect(errors.some(({ message }) => message.includes('"children"'))).toBe(false);
  });

  it("bounds an attacker-controlled property name using the containing pointer", () => {
    const key = "very-long-property-name-".repeat(100);
    const errors = invalid(document({ course: { ...course, [key]: "irrelevant" } }), "SCHEMA_INVALID", "/course");
    expect(JSON.stringify(errors)).not.toContain(key.slice(0, 81));
  });

  it.each(["\u2028", "\u2029"])("omits Unicode separators from diagnostic fields (%#)", (separator) => {
    const key = `before${separator}after`;
    const structural = invalid(document({ course: { ...course, [key]: 1 } }), "SCHEMA_INVALID", "/course");
    const yaml = invalid(`course: { "${key}": 1, "${key}": 2 }`, "YAML_DUPLICATE_KEY", "/course");
    expect([...structural, ...yaml].flatMap(({ path, message }) => [path, message]).join("")).not.toContain(separator);
  });

  it("bounds the combined unknown key excerpts in diagnostic fields", () => {
    const keys = Array.from({ length: 20 }, (_, index) => `unknown-field-${index}`);
    const fields = Object.fromEntries(keys.map((key) => [key, 1]));
    const errors = invalid(document({ course: { ...course, ...fields } }), "SCHEMA_INVALID", "/course");
    const excerpts = errors.map(({ path }) => path.startsWith("/course/") ? path.slice("/course/".length) : "");
    expect(excerpts[0]).toBe(keys[0]);
    expect(excerpts.join("").length).toBeLessThanOrEqual(80);
  });

  it.each(["__proto__", "constructor", "prototype"])("rejects the own property %s", (key) => {
    const pollution = { lectalePolluted: true };
    invalid(document({ course: { ...course, [key]: pollution } }), "SCHEMA_INVALID", `/course/${key}`);
    expect(Object.hasOwn(Object.prototype, "lectalePolluted")).toBe(false);
    expect(valid(document()).course.id).toBe(course.id);
  });

  it("stops collecting structural diagnostics at the first 50", () => {
    const outline = Array.from({ length: 80 }, (_, index) => ({ ...lesson, id: index }));
    const result = validateCourseManifest(document({ outline }));
    if (result.ok) throw new Error("Expected invalid outline IDs");
    expect(result.truncated).toBe(true);
    expect(result.errors.map(({ path }) => path))
      .toEqual(Array.from({ length: 50 }, (_, index) => `/outline/${index}/id`));
  });

  it("runs structural validation before semantic checks", () => {
    const errors = invalid(document({ schemaVersion: 2, outline: [lesson, lesson] }), "SCHEMA_INVALID", "/schemaVersion");
    expect(errors.every(({ code }) => code === "SCHEMA_INVALID")).toBe(true);
  });
});

describe("paths and video providers", () => {
  it.each(["../notes.pdf", "docs/../notes.pdf", "%2e%2e/notes.pdf", "%252e%252e/notes.pdf",
    "/notes.pdf", "docs\\notes.pdf", "https://example.org/notes.pdf", "C:/notes.pdf",
    "docs//notes.pdf", "docs/notes.pdf/"])("rejects unsafe path %s in the schema phase", (path) => {
    invalid(withResources({ ...resource, path }), "SCHEMA_INVALID", "/outline/0/resources/0/path");
  });

  it.each(["./notes.pdf", "docs/./notes.pdf", ".git/notes.pdf", ".GIT/notes.pdf", ".github/notes.pdf", "docs/.notes.pdf"])(
    "rejects hidden or dot path %s in the semantic phase",
    (path) => {
      invalid(withResources({ ...resource, path }), "INVALID_REPO_PATH", "/outline/0/resources/0/path");
    },
  );

  it.each(["docs./notes.pdf", "docs/report."])("rejects a repository segment ending in a dot (%s)", (path) => {
    invalid(withResources({ ...resource, type: "file", path }), "INVALID_REPO_PATH", "/outline/0/resources/0/path");
  });

  it("accepts the allowlisted hidden segment and a matching case-insensitive extension", () => {
    valid(withResources({ ...resource, path: ".well-known/NOTES.PDF" }));
  });

  it("checks the course cover and assignment material paths", () => {
    valid(document({ course: { ...course, cover: ".well-known/cover.png" } }));
    invalid(document({ course: { ...course, cover: ".git/cover.png" } }), "INVALID_REPO_PATH", "/course/cover");
    invalid(withAssignment({ materials: [{ ...resource, path: ".env/notes.pdf" }] }), "INVALID_REPO_PATH", "/assignments/0/materials/0/path");
  });

  it.each([
    ["pdf", "doc.pdf"],
    ["notebook", "demo.ipynb"],
    ["markdown", "reading.markdown"],
    ["image", "cover.webp"],
    ["video", "recording.mp4"],
    ["audio", "recording.ogg"],
    ["text", "README"],
    ["code", "Makefile"],
  ])("accepts %s files with matching extensions", (type, path) => {
    valid(withResources({ ...resource, type, path }));
  });

  it.each(["pdf", "notebook", "markdown", "image", "video", "audio", "text", "code"])(
    "rejects a known incompatible file declared as %s",
    (type) => {
      const path = type === "pdf" ? "recording.mp4" : "notes.pdf";
      invalid(withResources({ ...resource, type, path }), "RESOURCE_EXTENSION_MISMATCH", "/outline/0/resources/0/path");
    },
  );

  it.each([
    ["youtube", "https://youtube.com/watch?v=ABCDEFGHIJK&start=5"],
    ["youtube", "https://www.youtube.com:443/watch?v=ABCDEFGHIJK"],
    ["youtube", "https://youtu.be/ABCDEFGHIJK?si=tracking"],
    ["youtube", "https://www.youtube-nocookie.com/embed/ABCDEFGHIJK#fragment"],
    ["vimeo", "https://vimeo.com/123?tracking=1"],
    ["vimeo", "https://www.vimeo.com/123"],
    ["vimeo", "https://player.vimeo.com/video/123"],
  ])("canonicalizes %s video at %s", (provider, url) => {
    const [node] = valid(withResources({ ...video, provider, url })).outline;
    expect(node?.kind === "lesson" && node.resources[0]?.url).toBe(provider === "youtube"
      ? "https://www.youtube-nocookie.com/embed/ABCDEFGHIJK" : "https://player.vimeo.com/video/123");
  });

  it("preserves an external video link", () => {
    const url = "https://example.org/watch?video=123";
    const [node] = valid(withResources({ ...video, provider: "external", url })).outline;
    expect(node?.kind === "lesson" && node.resources[0]?.url).toBe(url);
  });

  it.each([
    { ...youtube, url: "https://vimeo.com/123" },
    { ...youtube, url: "https://youtu.be.example.org/ABCDEFGHIJK" },
    { ...youtube, url: "https://youtube.com@example.org/ABCDEFGHIJK" },
    { ...youtube, url: "https://user:password@youtu.be/ABCDEFGHIJK" },
    { ...youtube, url: "https://@youtu.be/ABCDEFGHIJK" },
    { ...youtube, url: "https://youtu.be:444/ABCDEFGHIJK" },
    { ...youtube, url: "https://%79outu.be/ABCDEFGHIJK" },
    { ...vimeo, url: "https://www.youtube.com/watch?v=ABCDEFGHIJK" },
  ])("rejects a provider/host mismatch at $url", (item) => {
    invalid(withResources(item), "VIDEO_PROVIDER_MISMATCH", "/outline/0/resources/0/url");
  });

  it.each([
    { ...youtube, url: "https://youtu.be/watch" },
    { ...youtube, url: "https://www.youtube.com/watch?v=ABCDEFGHIJKL" },
    { ...youtube, url: "https://www.youtube.com/watch?v=ABC.DEF_GHI" },
    { ...vimeo, url: "https://player.vimeo.com/video/123abc" },
    { ...vimeo, url: "https://vimeo.com/123/456" },
  ])("rejects a malformed provider video ID at $url", (item) => {
    invalid(withResources(item), "VIDEO_PROVIDER_MISMATCH", "/outline/0/resources/0/url");
  });

  it("requires an actual HTTPS authority", () => {
    invalid(document({ course: { ...course, homepage: "https:///example.org" } }), "INVALID_HTTPS_URL", "/course/homepage");
  });
});

describe("IDs, references, and limits", () => {
  it("allows equal resource IDs across separate lesson and assignment lists", () => {
    valid(document({
      outline: [{ ...lesson, resources: [resource] }, { ...lesson, id: "second", resources: [resource] }, reference],
      assignments: [{ ...assignment, materials: [resource] }],
    }));
  });

  it("rejects duplicate IDs within a lesson", () => {
    invalid(withResources(resource, resource), "DUPLICATE_RESOURCE_ID", "/outline/0/resources/1/id");
  });

  it("rejects duplicate IDs within assignment materials", () => {
    invalid(withAssignment({ materials: [resource, resource] }), "DUPLICATE_RESOURCE_ID", "/assignments/0/materials/1/id");
  });

  it("accepts distinct nested outline IDs", () => {
    valid(document({ outline: [lesson, { kind: "module", id: "module", title: "Module", children: [{ ...lesson, id: "nested-lesson" }] }] }));
  });

  it("rejects equal outline IDs across containing lists", () => {
    invalid(
      document({ outline: [lesson, { kind: "module", id: "module", title: "Module", children: [lesson] }] }),
      "DUPLICATE_NODE_ID", "/outline/1/children/0/id",
    );
  });

  it("allows multiple nodes to reference a single unique assignment", () => {
    valid(document({ outline: [reference, { ...reference, id: "second-ref" }], assignments: [assignment] }));
  });

  it("rejects duplicate assignment IDs", () => {
    invalid(document({ outline: [reference], assignments: [assignment, assignment] }), "DUPLICATE_ASSIGNMENT_ID", "/assignments/1/id");
  });

  it("rejects unknown reference IDs", () => {
    invalid(document({ outline: [reference] }), "UNKNOWN_ASSIGNMENT", "/outline/0/assignmentId");
  });

  it("rejects assignments that are absent from the outline", () => {
    invalid(document({ assignments: [assignment] }), "UNREFERENCED_ASSIGNMENT", "/assignments/0/id");
  });

  it("allows distinct course tags and rejects duplicates", () => {
    valid(document({ course: { ...course, tags: ["math", "analysis"] } }));
    invalid(document({ course: { ...course, tags: ["math", "math"] } }), "DUPLICATE_COURSE_TAG", "/course/tags/1");
  });

  function nested(depth: number, innermost: object = lesson): string {
    let node = innermost;
    for (let i = 1; i < depth; i++) {
      node = { kind: "module", id: `module-${i}`, title: "Module", children: [node] };
    }
    return document({ outline: [node] });
  }

  it("accepts five levels including an empty fifth-level module", () => {
    valid(nested(5));
    valid(nested(5, { kind: "module", id: "empty", title: "Module", children: [] }));
  });

  it("rejects a sixth level", () => {
    invalid(nested(6), "OUTLINE_TOO_DEEP", `/outline${"/0/children".repeat(5)}`);
  });

  function nodes(count: number): string {
    const outline = [];
    for (let start = 0; start < count; start += 250) {
      outline.push({
        kind: "module", id: `module-${start}`, title: "Module",
        children: Array.from({ length: Math.min(249, count - start - 1) },
          (_, i) => ({ ...lesson, id: `lesson-${start + i}` })),
      });
    }
    return document({ outline });
  }

  it("accepts exactly 2,000 total outline nodes", () => {
    valid(nodes(2000));
  });

  it("rejects 2,001 total outline nodes", () => {
    invalid(nodes(2001).replace('"schemaVersion":3', '"schemaVersion":2'), "TOO_MANY_OUTLINE_NODES", "/outline");
  });

  function resources(extra: number): string {
    const items = Array.from({ length: 100 }, (_, i) => ({ ...resource, id: `notes-${i}` }));
    const lessons = Array.from({ length: 99 }, (_, i) => ({ ...lesson, id: `lesson-${i}`, resources: items }));
    return document({
      outline: [...lessons, { ...lesson, resources: items.slice(0, extra) }, reference],
      assignments: [{ ...assignment, materials: items }],
    });
  }

  it("accepts 10,000 resources across lessons and assignment materials", () => {
    valid(resources(0));
  });

  it("rejects 10,001 resources across lessons and assignment materials", () => {
    invalid(resources(1).replace('"schemaVersion":3', '"schemaVersion":2'), "TOO_MANY_RESOURCES", "");
  });

  it("stops collecting semantic diagnostics at the first 50", () => {
    const outline = Array(80).fill(lesson);
    const result = validateCourseManifest(document({ outline }));
    if (result.ok) throw new Error("Expected duplicate outline IDs");
    expect(result.truncated).toBe(true);
    expect(result.errors.map(({ path }) => path))
      .toEqual(Array.from({ length: 50 }, (_, index) => `/outline/${index + 1}/id`));
  });

  it("bounds the total diagnostic text even when the count is below 50", () => {
    const resources = Array.from({ length: 100 }, (_, index) => ({
      ...resource, id: `notes-${index}`, path: "docs./notes.pdf",
    }));
    const result = validateCourseManifest(nested(5, { ...lesson, resources }));
    if (result.ok) throw new Error("Expected trailing dots to be rejected");
    const text = result.errors.map(({ code, path, message }) => code + path + message).join("");
    expect(text.length).toBeLessThanOrEqual(8192);
    expect(result.errors.length).toBeLessThan(50);
    expect(result.truncated).toBe(true);
  });
});

describe("submission sizes and chronology", () => {
  it("accepts equal file and attempt sizes", () => {
    valid(withAssignment());
  });

  it("rejects an attempt size below the file size", () => {
    invalid(
      withAssignment({ submission: { ...assignment.submission, maxAttemptBytes: 99 } }),
      "INVALID_ATTEMPT_SIZE", "/assignments/0/submission/maxAttemptBytes",
    );
  });

  const previous = "2026-11-21T11:00:00.0001Z";
  const next = "2026-11-21T10:00:00.0002-01:00";

  it("accepts ordered instants across offsets, precision and null gaps", () => {
    valid(withAssignment({
      releaseAt: previous,
      submission: { ...assignment.submission, openAt: null, dueAt: next, closeAt: "2026-11-21T11:00:00.0002000Z" },
    }));
  });

  it.each<[string, Record<string, unknown>, string]>([
    ["release followed by an earlier opening", { releaseAt: next, submission: { ...assignment.submission, openAt: previous } }, "openAt"],
    ["opening followed by an earlier due date", { submission: { ...assignment.submission, openAt: next, dueAt: previous } }, "dueAt"],
    ["due followed by an earlier closing", { submission: { ...assignment.submission, dueAt: next, closeAt: previous } }, "closeAt"],
    ["closing before opening without a due date", { submission: { ...assignment.submission, openAt: next, dueAt: null, closeAt: previous } }, "closeAt"],
  ])("rejects %s", (_name, fields, path) => {
    invalid(withAssignment(fields), "DATES_OUT_OF_ORDER", `/assignments/0/submission/${path}`);
  });

  it("rejects an RFC 3339 leap second in submission timestamps", () => {
    invalid(withAssignment({
      submission: { ...assignment.submission, openAt: "2016-12-31T23:59:60.5Z" },
    }), "INVALID_TIMESTAMP", "/assignments/0/submission/openAt");
  });

  it("requires the RFC 3339 date-time separator", () => {
    invalid(document({ course: { ...course, publishedAt: "2026-11-21 11:00:00Z" } }), "INVALID_TIMESTAMP", "/course/publishedAt");
  });
});
