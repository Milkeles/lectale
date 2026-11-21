import type { CourseManifest, OutlineNode, Resource, ValidationError } from "./course-manifest-types";

const VIDEO_HOSTS = {
  youtube: new Set(["youtube.com", "www.youtube.com", "youtu.be", "www.youtube-nocookie.com"]),
  vimeo: new Set(["vimeo.com", "www.vimeo.com", "player.vimeo.com"]),
};

const TYPED_EXTENSIONS = {
  pdf: ["pdf"],
  notebook: ["ipynb"],
  markdown: ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdtxt", "mdtext", "rmd", "qmd"],
  image: ["avif", "bmp", "gif", "heic", "heif", "ico", "jfif", "jpeg", "jpg", "jxl", "png", "svg", "svgz", "tif", "tiff", "webp"],
  video: ["3gp", "avi", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "ogv", "webm", "wmv"],
  audio: ["aac", "aif", "aiff", "alac", "flac", "m4a", "mid", "midi", "mp3", "oga", "ogg", "opus", "wav", "weba", "wma"],
} satisfies Partial<Record<Resource["type"], string[]>>;

const NON_TEXT_EXTENSIONS = new Set([
  ...TYPED_EXTENSIONS.pdf, ...TYPED_EXTENSIONS.notebook, ...TYPED_EXTENSIONS.image,
  ...TYPED_EXTENSIONS.video, ...TYPED_EXTENSIONS.audio,
]);

function extensionMatches(type: Resource["type"], filename: string): boolean {
  const extension = /\.([^.]+)$/u.exec(filename)?.[1]?.toLowerCase() ?? "";
  // Source and plain text can have project-specific filenames or no suffix.
  if (type === "text" || type === "code") return !NON_TEXT_EXTENSIONS.has(extension);
  if (Object.hasOwn(TYPED_EXTENSIONS, type)) {
    return TYPED_EXTENSIONS[type as keyof typeof TYPED_EXTENSIONS].includes(extension);
  }
  return true;
}

function httpsUrl(value: string): URL | undefined {
  // URL accepts a missing authority and repairs some spellings of it.
  if (!/^https:\/\/[^/?#]/u.test(value)) return;
  try {
    return new URL(value);
  } catch {
    return;
  }
}

function timestamp(value: string): [minute: number, second: string] | undefined {
  const parts = /^(\d{4}-\d\d-\d\dT\d\d:\d\d):(\d\d)(\.\d+)?(Z|[+-]\d\d:\d\d)$/iu.exec(value);
  if (!parts) return;
  // Compare UTC minutes, then seconds and fractions to retain leap seconds
  // and sub-millisecond precision that Date cannot represent.
  const minute = Date.parse(`${parts[1]}:00${parts[4]}`);
  const fraction = parts[3] ?? "";
  let end = fraction.length;
  while (fraction[end - 1] === "0") end--;
  const second = `${parts[2]}${end > 1 ? fraction.slice(0, end) : ""}`;
  return [minute, second];
}

/**
 * Checks the manifest-only rules in SEMANTIC_VALIDATION.md after schema
 * validation. Repository objects and owner-approved policy need their own checks.
 */
export function validateManifestSemantics(manifest: CourseManifest): ValidationError[] {
  const errors: ValidationError[] = [];
  const report = (code: ValidationError["code"], path: string, message: string) => {
    errors.push({ code, path, message });
  };
  const assignmentIds = new Map<string, string>();
  const nodeIds = new Set<string>();
  const referencedIds = new Set<string>();
  let nodeCount = 0;
  let resourceCount = 0;

  function checkPath(value: string, path: string): boolean {
    // The schema already excludes absolute paths, backslashes, URL schemes
    // and percent encodings. The repository allowlist governs hidden segments.
    if (value.split("/").some((part) => part.startsWith(".") && part !== ".well-known")) {
      report("INVALID_REPO_PATH", path, "Use a canonical repository-relative path without dot segments or hidden entries other than .well-known.");
      return false;
    }
    return true;
  }

  function checkUrl(value: string, path: string): URL | undefined {
    const url = httpsUrl(value);
    if (!url) report("INVALID_HTTPS_URL", path, "Use an HTTPS URL with a valid host.");
    return url;
  }

  function checkTimestamp(value: string | null | undefined, path: string) {
    if (value == null) return;
    const instant = timestamp(value);
    if (!instant) report("INVALID_TIMESTAMP", path, "Use an RFC 3339 timestamp with a T separator and a time zone.");
    return instant;
  }

  function checkResources(items: Resource[], path: string) {
    resourceCount += items.length;
    const ids = new Set<string>();
    items.forEach((item, index) => {
      const base = `${path}/${index}`;
      if (ids.has(item.id)) {
        report("DUPLICATE_RESOURCE_ID", `${base}/id`, "Resource IDs must be unique within this list.");
      }
      ids.add(item.id);
      if (item.path !== undefined && checkPath(item.path, `${base}/path`)
          && !extensionMatches(item.type, item.path.slice(item.path.lastIndexOf("/") + 1))) {
        report("RESOURCE_EXTENSION_MISMATCH", `${base}/path`, `Use a file extension that matches the ${item.type} resource type.`);
      }
      if (item.url !== undefined) {
        const url = checkUrl(item.url, `${base}/url`);
        const provider = item.provider;
        if (url && (provider === "youtube" || provider === "vimeo") && !VIDEO_HOSTS[provider].has(url.hostname)) {
          report("VIDEO_PROVIDER_MISMATCH", `${base}/url`, `Use a host allowed for the ${provider} video provider.`);
        }
      }
    });
  }

  function checkNodes(items: OutlineNode[], path: string, depth: number) {
    if (depth === 6 && items.length > 0) {
      report("OUTLINE_TOO_DEEP", path, "Limit the outline to five levels of nodes.");
    }
    nodeCount += items.length;
    items.forEach((node, index) => {
      const base = `${path}/${index}`;
      if (nodeIds.has(node.id)) {
        report("DUPLICATE_NODE_ID", `${base}/id`, "Node IDs must be unique across the outline.");
      }
      nodeIds.add(node.id);
      switch (node.kind) {
        case "module":
          checkNodes(node.children, `${base}/children`, depth + 1);
          break;
        case "lesson":
          checkTimestamp(node.recordedAt, `${base}/recordedAt`);
          checkResources(node.resources, `${base}/resources`);
          break;
        case "assignment":
          if (!assignmentIds.has(node.assignmentId)) {
            report("UNKNOWN_ASSIGNMENT", `${base}/assignmentId`, "Reference an ID defined in assignments.");
          }
          referencedIds.add(node.assignmentId);
          break;
      }
    });
  }

  const course = manifest.course;
  if (course.cover !== undefined) checkPath(course.cover, "/course/cover");
  if (course.homepage !== undefined) checkUrl(course.homepage, "/course/homepage");
  course.authors?.forEach(({ url }, index) => {
    if (url !== undefined) checkUrl(url, `/course/authors/${index}/url`);
  });
  checkTimestamp(course.publishedAt, "/course/publishedAt");
  const tags = new Set<string>();
  course.tags?.forEach((tag, index) => {
    if (tags.has(tag)) report("DUPLICATE_COURSE_TAG", `/course/tags/${index}`, "Course tags must be unique.");
    tags.add(tag);
  });

  manifest.assignments.forEach((assignment, index) => {
    const path = `/assignments/${index}`;
    const idPath = `${path}/id`;
    if (assignmentIds.has(assignment.id)) {
      report("DUPLICATE_ASSIGNMENT_ID", idPath, "Assignment IDs must be unique.");
    } else {
      assignmentIds.set(assignment.id, idPath);
    }
  });

  checkNodes(manifest.outline, "/outline", 1);
  manifest.assignments.forEach((assignment, index) => {
    const path = `/assignments/${index}`;
    checkResources(assignment.materials, `${path}/materials`);
    const submission = assignment.submission;
    if (submission.maxAttemptBytes < submission.maxFileBytes) {
      report("INVALID_ATTEMPT_SIZE", `${path}/submission/maxAttemptBytes`, "Set maxAttemptBytes at least as high as maxFileBytes.");
    }
    const dates = [
      ["releaseAt", assignment.releaseAt],
      ["submission/openAt", submission.openAt],
      ["submission/dueAt", submission.dueAt],
      ["submission/closeAt", submission.closeAt],
    ] as const;
    let previous: { instant: [number, string]; field: string } | undefined;
    for (const [field, value] of dates) {
      const datePath = `${path}/${field}`;
      const instant = checkTimestamp(value, datePath);
      if (!instant) continue;
      if (previous && (instant[0] < previous.instant[0]
          || (instant[0] === previous.instant[0] && instant[1] < previous.instant[1]))) {
        report("DATES_OUT_OF_ORDER", datePath, `Set this timestamp at or after ${previous.field.split("/").at(-1)}.`);
      }
      previous = { instant, field };
    }
  });
  if (nodeCount > 2000) {
    report("TOO_MANY_OUTLINE_NODES", "/outline", "Limit the outline to 2,000 total nodes.");
  }
  if (resourceCount > 10000) {
    report("TOO_MANY_RESOURCES", "", "Limit the combined lesson resources and assignment materials to 10,000.");
  }
  for (const [id, path] of assignmentIds) {
    if (!referencedIds.has(id)) {
      report("UNREFERENCED_ASSIGNMENT", path, "Add an outline entry that references this assignment.");
    }
  }
  return errors;
}
