import { MAX_MANIFEST_BYTES, validateCourseManifest, type CourseManifest } from "../contract/course-manifest";
import type { OutlineNode, Resource } from "../contract/course-manifest-types";
import type { components } from "../generated/api";
import { GitHubReadError, type GitHubRepository } from "../github/reader";
import { readBoundedBody } from "../net/bounded-body";
import { PINNED_TTL } from "./cache";
import { courseNotFound, PreviewError } from "./errors";
import { toCourseOutline } from "./outline";
import type { PreviewSource } from "./source";

export type CoursePreview = components["schemas"]["CoursePreview"];
export const README_PATH = "README.md";
const MANIFEST_PATH = "course.yaml";

type ResourceTarget = { path: string; maxEntries?: number };
type ResourceIndex = Record<string, ResourceTarget>;

interface PinnedPreview {
  preview: CoursePreview;
  resources: ResourceIndex[];
}

const INDEX_SHARDS = 16;

function resourceShard(address: string): number {
  let hash = 0;
  for (let index = 0; index < address.length; index++) {
    hash = Math.imul(hash, 31) + address.charCodeAt(index) | 0;
  }
  return (hash >>> 0) % INDEX_SHARDS;
}

function indexResources(manifest: CourseManifest, readmePresent: boolean): ResourceIndex[] {
  const shards = Array.from({ length: INDEX_SHARDS }, (): ResourceIndex => ({}));
  function add(address: string, target: ResourceTarget): void {
    shards[resourceShard(address)]![address] = target;
  }
  if (readmePresent) add(README_PATH, { path: README_PATH });

  function addResources(scope: string, resources: Resource[]): void {
    for (const { id, path, type, maxEntries } of resources) {
      if (path !== undefined) add(`${scope}/${id}`, type === "folder" ? { path, maxEntries: maxEntries ?? 100 } : { path });
    }
  }

  function addLessons(nodes: OutlineNode[]): void {
    for (const node of nodes) {
      if (node.kind === "module") addLessons(node.children);
      if (node.kind === "lesson") addResources(node.id, node.resources);
    }
  }

  addLessons(manifest.outline);
  for (const assignment of manifest.assignments) addResources(`assignment~${assignment.id}`, assignment.materials);
  return shards;
}

function manifestTooLarge(): PreviewError {
  return new PreviewError(413, {
    code: "manifest_too_large",
    message: "The manifest must be 1 MiB or smaller in UTF-8.",
    retryable: false,
  });
}

function manifestMissing(): PreviewError {
  return new PreviewError(422, {
    code: "manifest_missing",
    message: "A regular course.yaml file is required at the repository root.",
    retryable: false,
  });
}

async function loadPinnedPreview(source: PreviewSource, repository: GitHubRepository, sha: string): Promise<PinnedPreview> {
  // The single root listing checks both files and their types (README-001, SEC-020).
  const root = await source.directory(repository, sha, "");
  const manifestFile = root.find((entry) => entry.name === MANIFEST_PATH && entry.type === "file");
  if (!manifestFile) throw manifestMissing();
  if (manifestFile.size > MAX_MANIFEST_BYTES) throw manifestTooLarge();
  const readmePresent = root.some((entry) => entry.name === README_PATH && entry.type === "file");

  let response: Response;
  try {
    response = await source.openFile(repository, sha, MANIFEST_PATH);
  } catch (error) {
    if (error instanceof GitHubReadError && error.kind === "not_found") throw manifestMissing();
    throw error;
  }
  if (response.status !== 200) {
    void response.body?.cancel().catch(() => undefined);
    throw new GitHubReadError("upstream");
  }
  const bytes = await readBoundedBody(response.body, MAX_MANIFEST_BYTES).catch(() => {
    throw new GitHubReadError("upstream");
  });
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

  const { id: repoId } = repository;
  return {
    preview: { repoId, sha, outline: toCourseOutline(result.manifest, repoId, sha), readmePresent },
    resources: indexResources(result.manifest, readmePresent),
  };
}

/** Loads and validates an authorized public course once per commit (N7, CACHE-005). */
function pinned(source: PreviewSource, repository: GitHubRepository, sha: string): Promise<PinnedPreview> {
  return source.store.cached(`public-course-outline:v2:${repository.id}:${sha}`, PINNED_TTL,
    () => loadPinnedPreview(source, repository, sha));
}

/** Returns the same preview DTO for import and reload (V4-CORE-01). */
export async function coursePreview(source: PreviewSource, repository: GitHubRepository, sha: string): Promise<CoursePreview> {
  return (await pinned(source, repository, sha)).preview;
}

/** Resolves a resource using one small index shard on warm requests (ADR-0008). */
export async function resourceTarget(
  source: PreviewSource, repository: GitHubRepository, sha: string, address: string,
): Promise<ResourceTarget> {
  const shard = resourceShard(address);
  const key = `public-course-index:v2:${repository.id}:${sha}:${shard}`;
  try {
    const addresses = await source.store.cached(key, PINNED_TTL,
      async () => (await pinned(source, repository, sha)).resources[shard] ?? {});
    const target = addresses[address];
    if (target) return target;
  } catch (error) {
    if (!(error instanceof PreviewError) || (error.status !== 413 && error.status !== 422)) throw error;
  }
  throw courseNotFound();
}
