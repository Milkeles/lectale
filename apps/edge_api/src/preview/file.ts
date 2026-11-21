import { errorResponse } from "../errors";
import { GitHubReadError, type GitHubReader, type GitHubRepository } from "../github/reader";
import { matchPreviewCache, PINNED_CACHE_CONTROL, previewCacheKey, putPreviewCache, type PreviewCache } from "./cache";
import type { PinnedFile } from "./pinned";

const MARKDOWN = "text/markdown; charset=utf-8";
const TEXT = "text/plain; charset=utf-8";
const DOWNLOAD = "application/octet-stream";
const MEDIA_TYPES = new Map([
  ["md", MARKDOWN], ["markdown", MARKDOWN], ["mdown", MARKDOWN], ["mkd", MARKDOWN],
  ["mkdn", MARKDOWN], ["mdwn", MARKDOWN], ["mdtxt", MARKDOWN], ["mdtext", MARKDOWN],
  ["rmd", MARKDOWN], ["qmd", MARKDOWN],
  ["txt", TEXT], ["csv", TEXT], ["json", TEXT], ["ipynb", TEXT], ["yaml", TEXT], ["yml", TEXT],
  ["py", TEXT], ["js", TEXT], ["ts", TEXT], ["dart", TEXT], ["java", TEXT],
  ["c", TEXT], ["cpp", TEXT], ["h", TEXT], ["rs", TEXT], ["go", TEXT], ["sh", TEXT],
  ["pdf", "application/pdf"], ["avif", "image/avif"], ["bmp", "image/bmp"],
  ["gif", "image/gif"], ["jpeg", "image/jpeg"], ["jpg", "image/jpeg"], ["png", "image/png"],
  ["webp", "image/webp"], ["ico", "image/x-icon"], ["jxl", "image/jxl"],
  ["tif", "image/tiff"], ["tiff", "image/tiff"],
]);

const MAX_CACHED_FILE_BYTES = 4 * 1024 * 1024;
const RANGE_PATTERN = /^bytes=(?:[0-9]+-[0-9]*|-[0-9]+)$/u;

function safeFileHeaders(): Headers {
  return new Headers({
    "Content-Security-Policy": "sandbox",
    "X-Content-Type-Options": "nosniff",
  });
}

function rangeNotSatisfiable(requestId: string, contentRange: string | undefined): Response {
  const headers = safeFileHeaders();
  if (contentRange) headers.set("Content-Range", contentRange);
  return errorResponse(416, {
    code: "range_not_satisfiable",
    message: "The requested byte range is unavailable.",
    requestId,
    retryable: false,
  }, headers);
}

/** Streams an authorized regular file with a safe MIME type and optional byte range (V4-SEC-03). */
export async function servePinnedFile(
  reader: GitHubReader,
  cache: PreviewCache | undefined,
  repository: GitHubRepository,
  sha: string,
  file: PinnedFile,
  request: Request,
  requestId: string,
  waitUntil: (promise: Promise<void>) => void,
): Promise<Response> {
  const range = request.headers.get("Range");
  const unsatisfiedRange = file.size === undefined ? undefined : `bytes */${file.size}`;
  if (range !== null && (range.length > 128 || !RANGE_PATTERN.test(range))) {
    return rangeNotSatisfiable(requestId, unsatisfiedRange);
  }

  const { id, owner, name } = repository;
  const key = previewCacheKey(request.url, `public-course:v1:${id}:${sha}:${file.path}:1`);
  if (range === null) {
    const cached = await matchPreviewCache(cache, key);
    if (cached) return new Response(cached.body, cached);
  }

  const upstream = await reader.openFile(owner, name, sha, file.path, range ?? undefined);
  const contentRange = upstream.headers.get("Content-Range");
  if (range !== null && upstream.status === 416) {
    void upstream.body?.cancel().catch(() => undefined);
    const total = contentRange && /^bytes \*\/\d+$/u.test(contentRange) ? contentRange : unsatisfiedRange;
    return rangeNotSatisfiable(requestId, total);
  }
  if ((range === null && upstream.status !== 200) || (range !== null &&
      (upstream.status !== 206 || !contentRange || !/^bytes \d+-\d+\/\d+$/u.test(contentRange)))) {
    void upstream.body?.cancel().catch(() => undefined);
    throw new GitHubReadError("upstream");
  }

  const filename = file.path.slice(file.path.lastIndexOf("/") + 1);
  const extension = /\.([^.]+)$/u.exec(filename)?.[1]?.toLowerCase() ?? "";
  const type = MEDIA_TYPES.get(extension) ?? DOWNLOAD;
  const headers = safeFileHeaders();
  headers.set("Cache-Control", PINNED_CACHE_CONTROL);
  headers.set("Content-Type", type);
  headers.set("Accept-Ranges", "bytes");
  if (type === DOWNLOAD) headers.set("Content-Disposition", `attachment; filename="${filename}"`);
  if (contentRange && upstream.status === 206) headers.set("Content-Range", contentRange);

  const response = new Response(upstream.body, { status: upstream.status, headers });
  // Cloning tees a stream. Only cache bounded, complete objects so a slow
  // client cannot cause an unbounded queue on its branch.
  const length = upstream.headers.get("Content-Length");
  if (cache && range === null && length !== null && file.size !== undefined
      && Number(length) === file.size && file.size <= MAX_CACHED_FILE_BYTES
      && !upstream.headers.has("Content-Encoding")) {
    waitUntil(putPreviewCache(cache, key, response.clone()));
  }
  return response;
}
