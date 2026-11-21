import {
  MAX_MANIFEST_BYTES, validateCourseManifest, type CourseManifest,
} from "../contract/course-manifest";
import type { OutlineNode, Resource } from "../contract/course-manifest-types";
import type { components } from "../generated/api";
import { GitHubReadError, type GitHubReader, type GitHubRepository } from "../github/reader";
import { readBoundedBody } from "../net/bounded-body";
import { courseNotFound, PreviewError } from "./errors";
import { toCourseOutline } from "./outline";

export type CoursePreview = components["schemas"]["CoursePreview"];
export const README_PATH = "README.md";
const MANIFEST_PATH = "course.yaml";

export interface PinnedFile {
  path: string;
  size?: number;
}

export interface PinnedPreview {
  preview: CoursePreview;
  files: Record<string, PinnedFile>;
}

function indexFiles(manifest: CourseManifest, regularFiles: Map<string, PinnedFile>): Record<string, PinnedFile> {
  const files: Record<string, PinnedFile> = {};
  const readme = regularFiles.get(README_PATH);
  if (readme) files[README_PATH] = readme;

  function addResources(scope: string, resources: Resource[]): void {
    for (const { id, path } of resources) {
      const file = path === undefined ? undefined : regularFiles.get(path);
      if (file) files[`${scope}/${id}`] = file;
    }
  }

  function addLessons(nodes: OutlineNode[]): void {
    for (const node of nodes) {
      if (node.kind === "module") addLessons(node.children);
      if (node.kind === "lesson") addResources(node.id, node.resources);
    }
  }

  addLessons(manifest.outline);
  for (const assignment of manifest.assignments) {
    addResources(`assignment~${assignment.id}`, assignment.materials);
  }
  return files;
}

function manifestTooLarge(): PreviewError {
  return new PreviewError(413, {
    code: "manifest_too_large",
    message: "The manifest must be 1 MiB or smaller in UTF-8.",
    retryable: false,
  });
}

/** Validates one public commit and indexes its regular files (SEC-020, ADR-0008). */
export async function loadPinnedPreview(
  reader: GitHubReader,
  repository: GitHubRepository,
  sha: string,
): Promise<PinnedPreview> {
  if (repository.private !== false) throw courseNotFound();
  const { owner, name, id: repoId } = repository;
  const { entries, truncated } = await reader.tree(owner, name, sha);
  if (truncated) {
    throw new PreviewError(502, {
      code: "repository_tree_truncated",
      message: "GitHub returned an incomplete file list for this course.",
      retryable: false,
    });
  }
  const regularFiles = new Map<string, PinnedFile>();
  for (const { path, type, mode, size } of entries) {
    // GitHub also labels symlinks as blobs. Only regular Git modes are safe.
    if (type === "blob" && (mode === "100644" || mode === "100755")) {
      regularFiles.set(path, size === undefined ? { path } : { path, size });
    }
  }
  const manifestFile = regularFiles.get(MANIFEST_PATH);
  if (!manifestFile) {
    throw new PreviewError(422, {
      code: "manifest_missing",
      message: "A regular course.yaml file is required at the repository root.",
      retryable: false,
    });
  }
  if (manifestFile.size !== undefined && manifestFile.size > MAX_MANIFEST_BYTES) {
    throw manifestTooLarge();
  }
  const response = await reader.openFile(owner, name, sha, MANIFEST_PATH);
  if (response.status !== 200) {
    void response.body?.cancel().catch(() => undefined);
    throw new GitHubReadError("upstream");
  }
  let bytes: Uint8Array | undefined;
  try {
    bytes = await readBoundedBody(response.body, MAX_MANIFEST_BYTES);
  } catch {
    throw new GitHubReadError("upstream");
  }
  if (!bytes) throw manifestTooLarge();

  const result = validateCourseManifest(bytes);
  if (!result.ok) {
    throw new PreviewError(422, {
      code: "invalid_manifest",
      message: "The course.yaml manifest is invalid.",
      retryable: false,
      details: { errors: result.errors, ...(result.truncated ? { truncated: true } : {}) },
    });
  }

  const files = indexFiles(result.manifest, regularFiles);
  return {
    preview: {
      repoId,
      sha,
      outline: toCourseOutline(result.manifest, repoId, sha),
      readmePresent: regularFiles.has(README_PATH),
    },
    files,
  };
}
