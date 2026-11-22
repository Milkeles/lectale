import type { CourseManifest } from "../contract/course-manifest.ts";
import type { OutlineNode, Resource } from "../contract/course-manifest-types.ts";
import type { components } from "../generated/api";

/** The reader-facing outline, exactly as the API contract defines it (ADR-0011). */
export type CourseOutline = components["schemas"]["CourseOutline"];

type CourseOutlineNode = CourseOutline["nodes"][number];

/** Optional keys whose value may be undefined in the input. */
type UndefinedKeys<T> = { [K in keyof T]-?: undefined extends T[K] ? K : never }[keyof T];

/**
 * Drops keys whose value is undefined. The JSON body is the same either way,
 * but the contract types use `exactOptionalPropertyTypes`, where an optional
 * field must be absent rather than present with `undefined`.
 */
function present<T extends object>(
  value: T,
): Omit<T, UndefinedKeys<T>> & { [K in UndefinedKeys<T>]?: Exclude<T[K], undefined> } {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  ) as Omit<T, UndefinedKeys<T>> & { [K in UndefinedKeys<T>]?: Exclude<T[K], undefined> };
}

function readerUrl(value: string | undefined): URL | undefined {
  if (value === undefined) return;
  const url = new URL(value);
  if (!url.username && !url.password) return url;
}

function toResource(resource: Resource, previewPrefix: string, scope: string) {
  const { id, type, title, path, provider } = resource;
  const canEmbed = provider === "youtube" || provider === "vimeo";
  const link = canEmbed ? undefined : readerUrl(resource.url);
  const filename = (path ?? link?.pathname)?.split("/").at(-1);
  const dot = filename?.lastIndexOf(".") ?? -1;
  return present({
    id,
    kind: type,
    title,
    description: resource.description,
    href: path === undefined ? null : `${previewPrefix}/${type === "folder" ? "folders" : "content"}/${scope}/${id}`,
    path,
    url: link?.href,
    provider,
    embedUrl: canEmbed ? resource.url : undefined,
    mediaType: resource.mediaType,
    fileExtension: filename && dot > 0 && type !== "folder"
      ? filename.slice(dot + 1).toLowerCase() || undefined
      : undefined,
    language: resource.language,
    display: resource.display,
    preview: resource.preview,
    download: resource.download,
    recursive: resource.recursive,
    maxEntries: resource.maxEntries,
  });
}

/**
 * Projects a validated manifest into the CourseOutline reader response for
 * a public repository at the supplied full commit SHA (ADR-0003, ADR-0008,
 * V4-CORE-01). The caller verifies repository visibility before publishing it.
 * Paths support relative links from Markdown lessons (V4-CORE-05, SEC-020).
 * File sizes require repository metadata and are absent from this projection.
 */
export function toCourseOutline(
  validatedManifest: CourseManifest,
  repoId: number,
  sha: string,
): CourseOutline {
  const { course, outline, assignments, display } = validatedManifest;
  const previewPrefix = `/api/preview/${repoId}/${sha}`;
  const assignmentTitles = new Map(assignments.map(({ id, title }) => [id, title]));

  function toNode(node: OutlineNode): CourseOutlineNode {
    const { id, kind } = node;
    if (kind === "assignment") {
      const title = assignmentTitles.get(node.assignmentId);
      if (title === undefined) throw new Error("Validated outline references an unknown assignment.");
      return { id, kind, title, assignmentId: node.assignmentId, children: [], resources: [] };
    }
    const common = present({ id, kind, title: node.title, description: node.description });
    if (kind === "module") {
      return { ...common, children: node.children.map(toNode), resources: [] };
    }
    return {
      ...common,
      ...present({ recordedAt: node.recordedAt ?? undefined }),
      children: [],
      resources: node.resources.map((resource) => toResource(resource, previewPrefix, id)),
    };
  }

  return {
    course: present({
      id: course.id,
      title: course.title,
      summary: course.summary,
      description: course.description,
      language: course.language,
      version: course.version,
      license: course.license,
      tags: course.tags?.slice(),
      authors: course.authors?.map(({ name, url }) => present({ name, url: readerUrl(url)?.href })),
      homepage: readerUrl(course.homepage)?.href,
      estimatedMinutes: course.estimatedMinutes,
      level: course.level,
      cover: course.cover,
      publishedAt: course.publishedAt ?? undefined,
    }),
    nodes: outline.map(toNode),
    assignments: assignments.map((assignment) => present({
      id: assignment.id,
      title: assignment.title,
      description: assignment.description,
      releaseAt: assignment.releaseAt ?? undefined,
      openAt: assignment.submission.openAt ?? undefined,
      dueAt: assignment.submission.dueAt ?? undefined,
      closeAt: assignment.submission.closeAt ?? undefined,
      resources: assignment.materials.map((resource) =>
        toResource(resource, previewPrefix, `assignment~${assignment.id}`)),
    })),
    ...present({
      display: display && present({
        showEstimatedDuration: display.showEstimatedDuration,
        showFileDownloads: display.showFileDownloads,
        themeAccent: display.themeAccent,
      }),
    }),
  };
}
