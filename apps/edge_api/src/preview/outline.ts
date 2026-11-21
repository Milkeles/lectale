import type { CourseManifest } from "../contract/course-manifest.ts";
import type { OutlineNode, Resource } from "../contract/course-manifest-types.ts";

interface CourseOutlineNode {
  id: string;
  kind: OutlineNode["kind"];
  title: string;
  description?: string | undefined;
  recordedAt?: string | undefined;
  assignmentId?: string;
  children: CourseOutlineNode[];
  resources: ReturnType<typeof toResource>[];
}

function readerUrl(value: string | undefined): URL | undefined {
  if (value === undefined) return;
  const url = new URL(value);
  if (!url.username && !url.password) return url;
}

function toResource(resource: Resource, contentPrefix: string) {
  const { id, type, title, path, provider } = resource;
  const canEmbed = provider === "youtube" || provider === "vimeo";
  const link = canEmbed ? undefined : readerUrl(resource.url);
  const filename = (path ?? link?.pathname)?.split("/").at(-1);
  const dot = filename?.lastIndexOf(".") ?? -1;
  return {
    id,
    kind: type,
    title,
    description: resource.description,
    href: path === undefined ? null : `${contentPrefix}/${id}`,
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
  };
}

/**
 * Projects a validated manifest into the CourseOutline reader response for
 * a public repository at the supplied full commit SHA (ADR-0003, ADR-0008,
 * V4-CORE-01). The caller verifies repository visibility before publishing it.
 * File sizes require repository metadata and are absent from this projection.
 */
export function toCourseOutline(validatedManifest: CourseManifest, repoId: number, sha: string) {
  const { course, outline, assignments, display } = validatedManifest;
  const contentPrefix = `/api/preview/${repoId}/${sha}/content`;
  const assignmentTitles = new Map(assignments.map(({ id, title }) => [id, title]));

  function toNode(node: OutlineNode): CourseOutlineNode {
    const { id, kind } = node;
    if (kind === "assignment") {
      const title = assignmentTitles.get(node.assignmentId);
      if (title === undefined) throw new Error("Validated outline references an unknown assignment.");
      return { id, kind, title, assignmentId: node.assignmentId, children: [], resources: [] };
    }
    const common = { id, kind, title: node.title, description: node.description };
    if (kind === "module") {
      return { ...common, children: node.children.map(toNode), resources: [] };
    }
    return {
      ...common,
      recordedAt: node.recordedAt ?? undefined,
      children: [],
      resources: node.resources.map((resource) => toResource(resource, `${contentPrefix}/${id}`)),
    };
  }

  return {
    course: {
      id: course.id,
      title: course.title,
      summary: course.summary,
      description: course.description,
      language: course.language,
      version: course.version,
      license: course.license,
      tags: course.tags?.slice(),
      authors: course.authors?.map(({ name, url }) => ({ name, url: readerUrl(url)?.href })),
      homepage: readerUrl(course.homepage)?.href,
      estimatedMinutes: course.estimatedMinutes,
      level: course.level,
      cover: course.cover,
      publishedAt: course.publishedAt ?? undefined,
    },
    nodes: outline.map(toNode),
    assignments: assignments.map((assignment) => ({
      id: assignment.id,
      title: assignment.title,
      description: assignment.description,
      releaseAt: assignment.releaseAt ?? undefined,
      openAt: assignment.submission.openAt ?? undefined,
      dueAt: assignment.submission.dueAt ?? undefined,
      closeAt: assignment.submission.closeAt ?? undefined,
      resources: assignment.materials.map((resource) =>
        toResource(resource, `${contentPrefix}/assignment~${assignment.id}`)),
    })),
    display: display && {
      showEstimatedDuration: display.showEstimatedDuration,
      showFileDownloads: display.showFileDownloads,
      themeAccent: display.themeAccent,
    },
  };
}
