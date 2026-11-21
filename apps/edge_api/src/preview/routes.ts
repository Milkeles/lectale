import type { Context, Hono } from "hono";
import type { components } from "../generated/api";
import { commitShaPattern, GitHubReadError, isRepoId, type GitHubReader, type GitHubRepository } from "../github/reader";
import { readBoundedBody } from "../net/bounded-body";
import { matchPreviewCache, PINNED_CACHE_CONTROL, previewCacheKey, putPreviewCache, type PreviewCache } from "./cache";
import { courseNotFound, PreviewError } from "./errors";
import { servePinnedFile } from "./file";
import { loadPinnedPreview, README_PATH, type CoursePreview, type PinnedPreview } from "./pinned";

type WorkerEnv = { Bindings: Env };
type RepoHead = Pick<CoursePreview, "repoId" | "sha">;
type ImportCourseRequest = components["schemas"]["ImportCourseRequest"];

const REPOSITORY_URL = /^https:\/\/github\.com\/([A-Za-z0-9-]+)\/([A-Za-z0-9_.-]+)\/?$/u;
const MANIFEST_ID = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/u;
const REF_CACHE_CONTROL = "public, max-age=60";
const MAX_IMPORT_BODY_BYTES = 4096;

function invalidUrl(): PreviewError {
  return new PreviewError(400, {
    code: "invalid_url",
    message: "Provide an HTTPS GitHub repository URL in owner/repository form.",
    retryable: false,
  });
}

async function importCoordinates(request: Request): Promise<{ owner: string; name: string }> {
  if (request.headers.get("Content-Type")?.split(";")[0]?.trim().toLowerCase() !== "application/json") {
    throw invalidUrl();
  }
  let parsed: unknown;
  try {
    const bytes = await readBoundedBody(request.body, MAX_IMPORT_BODY_BYTES);
    if (!bytes) throw invalidUrl();
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes));
  } catch {
    throw invalidUrl();
  }
  if (!parsed || typeof parsed !== "object" || Object.keys(parsed).length !== 1 || !("url" in parsed)
      || typeof parsed.url !== "string") {
    throw invalidUrl();
  }
  const { url }: ImportCourseRequest = { url: parsed.url };
  const match = REPOSITORY_URL.exec(url);
  if (!match || match[0] !== url || !match[1] || !match[2]) throw invalidUrl();
  const name = match[2].replace(/\.git$/u, "");
  if (!name || name === "." || name === "..") throw invalidUrl();
  return { owner: match[1].toLowerCase(), name: name.toLowerCase() };
}

function pinnedKey(url: string, { repoId, sha }: RepoHead): Request {
  return previewCacheKey(url, `public-course-outline:v1:${repoId}:${sha}`);
}

async function cachedJson<T>(cache: PreviewCache | undefined, key: Request): Promise<T | undefined> {
  try {
    return (await (await matchPreviewCache(cache, key))?.json()) as T | undefined;
  } catch {
    return undefined;
  }
}

function isManifestId(id: string): boolean {
  return id.length <= 80 && MANIFEST_ID.test(id);
}

/** Registers public-only, read-only preview routes (V4-CORE-01, ADR-0008). */
export function registerPreviewRoutes(
  app: Hono<WorkerEnv>,
  reader: GitHubReader,
  cacheOverride?: PreviewCache,
): void {
  const getCache = () => cacheOverride ?? (typeof caches === "undefined" ? undefined : caches.default);

  async function loadAndCache(
    cache: PreviewCache | undefined,
    key: Request,
    repository: GitHubRepository,
    sha: string,
  ): Promise<PinnedPreview> {
    const pinned = await loadPinnedPreview(reader, repository, sha);
    if (cache) {
      await putPreviewCache(cache, key, Response.json(pinned, {
        headers: { "Cache-Control": PINNED_CACHE_CONTROL },
      }));
    }
    return pinned;
  }

  app.post("/courses/import", async (c) => {
    const { owner, name } = await importCoordinates(c.req.raw);
    const cache = getCache();
    const refKey = previewCacheKey(c.req.url, `repo-preview:v1:${owner}:${name}`);
    const head = await cachedJson<RepoHead>(cache, refKey);
    if (head) {
      const pinned = await cachedJson<PinnedPreview>(cache, pinnedKey(c.req.url, head));
      if (pinned) return c.json(pinned.preview, 200);
    }

    const repository = await reader.resolveRepository(owner, name);
    if (repository.private !== false) throw courseNotFound();
    const sha = await reader.headCommit(repository.owner, repository.name);
    if (!commitShaPattern.test(sha)) throw new GitHubReadError("upstream");

    const resolved = { repoId: repository.id, sha };
    const key = pinnedKey(c.req.url, resolved);
    const pinned = await cachedJson<PinnedPreview>(cache, key) ?? await loadAndCache(cache, key, repository, sha);
    if (cache) {
      await putPreviewCache(cache, refKey, Response.json(resolved, {
        headers: { "Cache-Control": REF_CACHE_CONTROL },
      }));
    }
    return c.json(pinned.preview, 200);
  });

  async function getFile(c: Context<WorkerEnv>, address: string): Promise<Response> {
    const id = c.req.param("repoId") ?? "";
    const sha = c.req.param("sha") ?? "";
    const repoId = Number(id);
    if (!/^[1-9][0-9]*$/u.test(id) || !isRepoId(repoId) || !commitShaPattern.test(sha)) {
      throw courseNotFound();
    }

    // Class B entries carry bytes and addresses, never current visibility.
    const repository = await reader.resolveRepositoryById(repoId);
    if (repository.id !== repoId || repository.private !== false) throw courseNotFound();
    const cache = getCache();
    const key = pinnedKey(c.req.url, { repoId, sha });
    let pinned = await cachedJson<PinnedPreview>(cache, key);
    if (!pinned) {
      try {
        pinned = await loadAndCache(cache, key, repository, sha);
      } catch (error) {
        // A content address for a commit without a valid preview is unavailable.
        if (error instanceof PreviewError && (error.status === 413 || error.status === 422)) {
          throw courseNotFound();
        }
        throw error;
      }
    }
    const file = pinned.files[address];
    if (!file) throw courseNotFound();
    return servePinnedFile(reader, cache, repository, sha, file, c.req.raw, c.get("requestId"),
      (promise) => c.executionCtx.waitUntil(promise));
  }

  app.get("/preview/:repoId/:sha/readme", (c) => getFile(c, README_PATH));

  app.get("/preview/:repoId/:sha/content/:lessonId/:resourceId", (c) => {
    const { lessonId, resourceId } = c.req.param();
    const scope = lessonId.startsWith("assignment~") ? lessonId.slice("assignment~".length) : lessonId;
    if (!isManifestId(scope) || !isManifestId(resourceId)) throw courseNotFound();
    return getFile(c, `${lessonId}/${resourceId}`);
  });
}
