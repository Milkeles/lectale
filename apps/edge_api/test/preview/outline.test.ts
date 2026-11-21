import { describe, expect, it } from "vitest";
import { validateCourseManifest } from "../../src/contract/course-manifest.ts";
import { toCourseOutline } from "../../src/preview/outline.ts";

const sha = "a".repeat(40);
const content = `/api/preview/42/${sha}/content`;

function outlineFor(
  outline: unknown[],
  assignments: unknown[] = [],
  courseFields: Record<string, unknown> = {},
) {
  const validated = validateCourseManifest(JSON.stringify({
    schemaVersion: 3,
    course: {
      id: "reader-course",
      title: "Reader course",
      summary: "Course summary",
      language: "en",
      version: "1.0.0",
      ...courseFields,
    },
    outline,
    assignments,
    display: { showEstimatedDuration: false, themeAccent: "#225599" },
  }));
  if (!validated.ok) throw new Error(JSON.stringify(validated.errors));
  return toCourseOutline(validated.manifest, 42, sha);
}

describe("toCourseOutline", () => {
  it("keeps tree order and scopes repeated resource IDs to their lesson or assignment", () => {
    const slides = { id: "slides", title: "Slides", type: "pdf", mediaType: "application/pdf" };
    const recordedAt = "2026-11-20T00:00:00Z";
    const branch = outlineFor([
      {
        id: "module-one", kind: "module", title: "Module one", description: "Start here",
        children: [
          {
            id: "lesson-one", kind: "lesson", title: "Lesson one", recordedAt,
            resources: [{ ...slides, path: "first/LECTURE.PDF", download: false }],
          },
          { id: "problem-link", kind: "assignment", assignmentId: "lesson-one" },
        ],
      },
      {
        id: "lesson-two", kind: "lesson", title: "Lesson two",
        resources: [{ ...slides, path: "second/lecture.pdf" }],
      },
    ], [{
      id: "lesson-one",
      title: "Problem set",
      releaseAt: "2026-11-21T00:00:00Z",
      materials: [{ ...slides, path: "assignments/instructions.pdf" }],
      submission: {
        allowedExtensions: [".pdf"], maxFileBytes: 1, maxAttemptBytes: 1, maxFiles: 1, maxAttempts: 1,
        openAt: "2026-11-22T00:00:00Z", dueAt: "2026-11-23T00:00:00Z", closeAt: "2026-11-24T00:00:00Z",
      },
      grading: { mode: "manual", maxPoints: 10 },
    }], {
      description: "An introduction",
      authors: [{ name: "Instructor", url: "https://example.org/" }],
      cover: "images/cover.png",
      estimatedMinutes: 0,
      publishedAt: null,
    });

    expect(branch.course).toMatchObject({
      title: "Reader course", summary: "Course summary", language: "en", description: "An introduction",
      cover: "images/cover.png", estimatedMinutes: 0, authors: [{ name: "Instructor", url: "https://example.org/" }],
    });
    expect(branch.course.publishedAt).toBeUndefined();
    expect(branch.display).toMatchObject({ showEstimatedDuration: false, themeAccent: "#225599" });
    expect(branch.nodes).toMatchObject([
      {
        id: "module-one", kind: "module", description: "Start here", resources: [],
        children: [
          {
            id: "lesson-one", kind: "lesson", recordedAt, children: [],
            resources: [{
              id: "slides", kind: "pdf", href: `${content}/lesson-one/slides`,
              mediaType: "application/pdf", fileExtension: "pdf", download: false,
            }],
          },
          {
            id: "problem-link", kind: "assignment", title: "Problem set", assignmentId: "lesson-one",
            children: [], resources: [],
          },
        ],
      },
      { id: "lesson-two", resources: [{ id: "slides", href: `${content}/lesson-two/slides` }] },
    ]);
    expect(JSON.parse(JSON.stringify(branch.assignments))).toStrictEqual([{
      id: "lesson-one",
      title: "Problem set",
      releaseAt: "2026-11-21T00:00:00Z",
      openAt: "2026-11-22T00:00:00Z",
      dueAt: "2026-11-23T00:00:00Z",
      closeAt: "2026-11-24T00:00:00Z",
      resources: [{
        id: "slides", kind: "pdf", title: "Slides", mediaType: "application/pdf", fileExtension: "pdf",
        href: `${content}/assignment~lesson-one/slides`,
      }],
    }]);
  });

  it("carries canonical embeds and keeps external videos link-only", () => {
    const outline = outlineFor([{
      id: "lesson", kind: "lesson", title: "Video and links",
      resources: [
        { id: "yt", title: "YouTube", type: "video", provider: "youtube", url: "https://youtu.be/dQw4w9WgXcQ?t=20" },
        { id: "vimeo", title: "Vimeo", type: "video", provider: "vimeo", url: "https://vimeo.com/123456" },
        { id: "other", title: "Link", type: "video", provider: "external", url: "https://example.org/video" },
        { id: "file", title: "Local movie", type: "video", path: "movies/lecture.mp4" },
        { id: "link", title: "Link with credentials", type: "external", url: "https://user:password@example.org/" },
      ],
    }], [], { homepage: "https://user:password@example.org/" });

    expect(outline.course.homepage).toBeUndefined();
    expect(JSON.parse(JSON.stringify(outline.nodes[0]?.resources))).toStrictEqual([
      { id: "yt", title: "YouTube", kind: "video", href: null, provider: "youtube", embedUrl: "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ" },
      { id: "vimeo", title: "Vimeo", kind: "video", href: null, provider: "vimeo", embedUrl: "https://player.vimeo.com/video/123456" },
      { id: "other", title: "Link", kind: "video", href: null, provider: "external", url: "https://example.org/video" },
      { id: "file", title: "Local movie", kind: "video", href: `${content}/lesson/file`, fileExtension: "mp4" },
      { id: "link", title: "Link with credentials", kind: "external", href: null },
    ]);
  });
});
