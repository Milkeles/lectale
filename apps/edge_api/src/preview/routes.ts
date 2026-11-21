import type { Context, Hono } from "hono";
import { isSafeRepoPath } from "../contract/repo-path";
import type { components } from "../generated/api";
import { commitShaPattern, GitHubReadError, isRepoId, type GitHubReader } from "../github/reader";
import { GitHubRestReader } from "../github/rest-reader";
import { readBoundedBody } from "../net/bounded-body";
import { FILE_CACHE_CONTROL, PreviewMemo, PreviewStore, type PreviewCache } from "./cache";
import { courseNotFound, PreviewError } from "./errors";
import { servePinnedFile } from "./file";
import { coursePreview, README_PATH, resourceTarget } from "./pinned";
import { PreviewSource } from "./source";

export type PreviewBindings = Env & { GITHUB_PUBLIC_READ_TOKEN?: string };
type WorkerEnv = { Bindings: PreviewBindings };
type ImportCourseRequest = components["schemas"]["ImportCourseRequest"];
type PreviewFolder = components["schemas"]["PreviewFolder"];
type Limiter = Pick<RateLimit, "limit">;

const REPOSITORY_URL = /^https:\/\/github\.com\/([A-Za-z0-9-]{1,39})\/([A-Za-z0-9_.-]{1,104})\/?$/u;
const MANIFEST_ID = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/u;
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
  if (!name || name.length > 100 || name === "." || name === "..") throw invalidUrl();
  return { owner: match[1].toLowerCase(), name: name.toLowerCase() };
}

function resourceAddress({ lessonId, resourceId }: { lessonId: string; resourceId: string }): string {
  const scope = lessonId.startsWith("assignment~") ? lessonId.slice("assignment~".length) : lessonId;
  if (scope.length > 80 || resourceId.length > 80 || MANIFEST_ID.exec(scope)?.[0] !== scope
      || MANIFEST_ID.exec(resourceId)?.[0] !== resourceId) throw courseNotFound();
  return `${lessonId}/${resourceId}`;
}

function filePath(requestUrl: string): string {
  // Hono decodes path parameters. Use the original suffix so an encoded
  // separator cannot turn into a directory boundary before validation.
  const raw = /^https?:\/\/[^/]+\/api\/preview\/[^/?]+\/[^/?]+\/files\/([^?#]+)/u.exec(requestUrl)?.[1];
  if (!raw || raw.length > 1_500 || /%(?:2f|5c)/iu.test(raw)) throw courseNotFound();
  let path: string;
  try {
    path = decodeURIComponent(raw);
  } catch {
    throw courseNotFound();
  }
  if (!isSafeRepoPath(path)) throw courseNotFound();
  return path;
}

async function admit(c: Context<WorkerEnv>, limiter: Limiter | undefined): Promise<void> {
  if (!limiter) return;
  const { success } = await limiter.limit({ key: c.req.header("CF-Connecting-IP") ?? "unknown" });
  if (!success) throw new GitHubReadError("rate_limited", 60);
}

/** Registers public-only, read-only preview routes (V4-CORE-01, ADR-0008). */
export function registerPreviewRoutes(
  app: Hono<WorkerEnv>,
  reader?: GitHubReader,
  cacheOverride?: PreviewCache,
  importLimiter?: Limiter,
): void {
  const memo = new PreviewMemo();
  const cooldown = { until: 0 };
  function sourceFor(c: Context<WorkerEnv>): PreviewSource {
    const cache = cacheOverride ?? (typeof caches === "undefined" ? undefined : caches.default);
    const github = reader ?? new GitHubRestReader(async () => c.env?.GITHUB_PUBLIC_READ_TOKEN);
    return new PreviewSource(new PreviewStore(c.req.url, cache, memo), github, cooldown);
  }

  app.post("/courses/import", async (c) => {
    await admit(c, importLimiter ?? c.env?.IMPORT_RATE_LIMIT);
    const { owner, name } = await importCoordinates(c.req.raw);
    const source = sourceFor(c);
    await source.assertAvailable();
    const repository = await source.repositoryByName(owner, name);
    const sha = await source.head(repository);
    const preview = await coursePreview(source, repository, sha);
    await source.recordPin(repository.id, sha);
    return c.json(preview, 200, { "Cache-Control": "no-store" });
  });

  app.use("/preview/*", async (c, next) => {
    await admit(c, c.env?.PREVIEW_RATE_LIMIT);
    await next();
  });

  async function authorize(c: Context<WorkerEnv>) {
    const id = c.req.param("repoId") ?? "";
    const sha = c.req.param("sha") ?? "";
    const repoId = Number(id);
    if (!/^[1-9][0-9]*$/u.test(id) || !isRepoId(repoId) || !commitShaPattern.test(sha)) throw courseNotFound();
    const source = sourceFor(c);
    await source.assertAvailable();
    const repository = await source.repositoryById(repoId);
    await source.requirePin(repository, sha);
    return { source, repository, sha };
  }

  app.get("/preview/:repoId/:sha", async (c) => {
    const { source, repository, sha } = await authorize(c);
    const preview = await coursePreview(source, repository, sha);
    return c.json(preview, 200, { "Cache-Control": FILE_CACHE_CONTROL });
  });

  async function scopedFile(c: Context<WorkerEnv>, address: string): Promise<Response> {
    const { source, repository, sha } = await authorize(c);
    const { path, maxEntries } = await resourceTarget(source, repository, sha, address);
    if (maxEntries !== undefined) throw courseNotFound();
    return servePinnedFile(source, repository, sha, path, c.req.raw, c.get("requestId"));
  }

  app.get("/preview/:repoId/:sha/readme", (c) => scopedFile(c, README_PATH));
  app.get("/preview/:repoId/:sha/content/:lessonId/:resourceId", (c) => scopedFile(c, resourceAddress(c.req.param())));

  app.get("/preview/:repoId/:sha/files/*", async (c) => {
    const path = filePath(c.req.url);
    const { source, repository, sha } = await authorize(c);
    return servePinnedFile(source, repository, sha, path, c.req.raw, c.get("requestId"));
  });

  app.get("/preview/:repoId/:sha/folders/:lessonId/:resourceId", async (c) => {
    const address = resourceAddress(c.req.param());
    const { source, repository, sha } = await authorize(c);
    const { path, maxEntries } = await resourceTarget(source, repository, sha, address);
    if (maxEntries === undefined) throw courseNotFound();
    const prefix = `/api/preview/${repository.id}/${sha}/files/${path}/`;
    const items = await source.directory(repository, sha, path);
    const listing: PreviewFolder = {
      entries: items.slice(0, maxEntries).map((entry) => ({ ...entry, href: prefix + entry.name })),
    };
    return c.json(listing, 200, { "Cache-Control": FILE_CACHE_CONTROL });
  });
}
