import { errorResponse } from "../errors";
import { GitHubReadError, type GitHubRepository } from "../github/reader";
import { readBoundedBody } from "../net/bounded-body";
import { FILE_CACHE_CONTROL, PINNED_TTL } from "./cache";
import { DOWNLOAD, fileMediaType, matchesRaster, peekBody, SIGNATURE_BYTES } from "./media";
import { byteInterval, parseRange, readContentRange, readUnsatisfiedRange } from "./range";
import type { PreviewSource } from "./source";

const MAX_CACHED_FILE_BYTES = 4 * 1024 * 1024;
const CSP = "default-src 'none'; sandbox; frame-ancestors 'none'";

function safeFileHeaders(): Headers {
  return new Headers({
    "Content-Security-Policy": CSP,
    "X-Content-Type-Options": "nosniff",
  });
}

function rangeNotSatisfiable(requestId: string, size?: number): Response {
  const headers = safeFileHeaders();
  if (size !== undefined) headers.set("Content-Range", `bytes */${size}`);
  return errorResponse(416, {
    code: "range_not_satisfiable",
    message: "The requested byte range is unavailable.",
    requestId,
    retryable: false,
  }, headers);
}

function contentLength(response: Response): number | undefined {
  const value = response.headers.get("Content-Length");
  const parsed = value !== null && /^\d+$/u.test(value) ? Number(value) : NaN;
  if (Number.isSafeInteger(parsed)) return parsed;
}

function publicHeaders(headers: Headers): Headers {
  const downstream = new Headers(headers);
  downstream.set("Cache-Control", FILE_CACHE_CONTROL);
  downstream.delete("Age");
  return downstream;
}

function cancel(response: Response): void {
  void response.body?.cancel().catch(() => undefined);
}

function badUpstream(response: Response): never {
  cancel(response);
  throw new GitHubReadError("upstream");
}

function checkTransfer(response: Response, length: number): void {
  const encoding = response.headers.get("Content-Encoding");
  const received = contentLength(response);
  if ((encoding && encoding !== "identity") || (received !== undefined && received !== length)) badUpstream(response);
}

async function rasterPrefix(
  source: PreviewSource, repository: GitHubRepository, sha: string, path: string, size: number, length: number,
): Promise<Uint8Array> {
  const end = length - 1;
  const response = await source.openFile(repository, sha, path, `bytes=0-${end}`);
  const actual = readContentRange(response.headers.get("Content-Range"));
  if (response.status !== 206 || actual?.start !== 0 || actual.end !== end || actual.size !== size) badUpstream(response);
  checkTransfer(response, length);
  const prefix = await readBoundedBody(response.body, length).catch(() => undefined);
  if (prefix?.length !== length) throw new GitHubReadError("upstream");
  return prefix;
}

function fittedBody(body: ReadableStream<Uint8Array> | null, length: number): ReadableStream<Uint8Array> | null {
  if (!body) {
    if (length === 0) return null;
    throw new GitHubReadError("upstream");
  }
  if (typeof FixedLengthStream !== "undefined") {
    const fixed = new FixedLengthStream(length);
    void body.pipeTo(fixed.writable).catch(() => undefined);
    return fixed.readable;
  }
  let remaining = length;
  return body.pipeThrough(new TransformStream<Uint8Array, Uint8Array>({
    transform(chunk, controller) {
      remaining -= chunk.byteLength;
      if (remaining < 0) throw new GitHubReadError("upstream");
      controller.enqueue(chunk);
    },
    flush() {
      if (remaining !== 0) throw new GitHubReadError("upstream");
    },
  }));
}

function fromCache(cached: Response): Response {
  return new Response(cached.body, { headers: publicHeaders(cached.headers) });
}

/** Streams a pinned regular file with safe media headers and validated single ranges (SEC-020, SEC-027). */
export async function servePinnedFile(
  source: PreviewSource,
  repository: GitHubRepository,
  sha: string,
  path: string,
  request: Request,
  requestId: string,
): Promise<Response> {
  const header = request.headers.get("Range");
  const cacheName = `public-course:v1:${repository.id}:${sha}:${path}:3`;
  const key = source.store.key(cacheName);

  if (header === null) {
    const hit = await source.store.match(key);
    if (hit) return fromCache(hit);

    // Share completion of a cold fill. A streaming response stays with the
    // request that opened it, so no request consumes another request's stream.
    let own: Response | undefined;
    await source.store.once(cacheName, async () => {
      const filled = await source.store.match(key);
      own = filled ? fromCache(filled) : await loadFile(source, repository, sha, path, key, null, requestId);
    });
    if (own) return own;
    const filled = await source.store.match(key);
    if (filled) return fromCache(filled);
  }
  return loadFile(source, repository, sha, path, key, header, requestId);
}

async function loadFile(
  source: PreviewSource,
  repository: GitHubRepository,
  sha: string,
  path: string,
  key: Request,
  header: string | null,
  requestId: string,
): Promise<Response> {
  const range = header === null ? undefined : parseRange(header);
  if (header !== null) {
    const cached = await source.store.match(key);
    if (cached) {
      const size = contentLength(cached);
      const interval = size === undefined || !range ? undefined : byteInterval(range, size);
      if (size !== undefined && !interval) {
        cancel(cached);
        return rangeNotSatisfiable(requestId, size);
      }
      if (size !== undefined && size <= MAX_CACHED_FILE_BYTES && interval) {
        const { start, end } = interval;
        const expectedRange = `bytes ${start}-${end}/${size}`;
        const headers = publicHeaders(cached.headers);
        headers.set("Content-Range", expectedRange);
        headers.set("Content-Length", String(end - start + 1));

        const sliced = await source.store.match(new Request(key, { headers: { Range: `bytes=${start}-${end}` } }));
        if (sliced?.status === 206 && sliced.headers.get("Content-Range") === expectedRange) {
          cancel(cached);
          return new Response(sliced.body, { status: 206, headers });
        }
        if (sliced) cancel(sliced);
        // Cache implementations without native range support can still slice
        // complete entries whose size is already bounded.
        const bytes = await readBoundedBody(cached.body, size).catch(() => undefined);
        if (bytes?.length === size) {
          return new Response(bytes.subarray(start, end + 1), { status: 206, headers });
        }
      } else {
        cancel(cached);
      }
    }
  }

  const slash = path.lastIndexOf("/");
  const directory = slash === -1 ? "" : path.slice(0, slash);
  const filename = path.slice(slash + 1);
  const findFile = (entries: Awaited<ReturnType<PreviewSource["directory"]>> | undefined) =>
    entries?.find((entry) => entry.name === filename && entry.type === "file");
  let file = findFile(await source.knownDirectory(repository, sha, directory));
  if (header !== null && (!range || (file && !byteInterval(range, file.size)))) {
    return rangeNotSatisfiable(requestId, file?.size);
  }

  const upstream = await source.openFile(repository, sha, path, header ?? undefined);
  try {
    // Raw misses are authoritative for missing paths. For successful raw
    // reads use the pinned parent listing to reject links and submodules.
    file ??= findFile(await source.directory(repository, sha, directory));
    if (!file) {
      await source.rememberMissingFile(repository, sha, path);
      throw new GitHubReadError("not_found");
    }
  } catch (error) {
    cancel(upstream);
    throw error;
  }
  const { size } = file;
  const rawRange = upstream.headers.get("Content-Range");
  let start = 0;
  let expectedBytes = size;
  const headers = safeFileHeaders();
  if (range) {
    const interval = byteInterval(range, size);
    if (upstream.status === 416) {
      if (interval || readUnsatisfiedRange(rawRange) !== size) badUpstream(upstream);
      cancel(upstream);
      return rangeNotSatisfiable(requestId, size);
    }
    const actual = readContentRange(rawRange);
    if (upstream.status !== 206 || !interval || !actual || actual.size !== size
        || actual.start !== interval.start || actual.end !== interval.end) badUpstream(upstream);
    start = actual.start;
    expectedBytes = actual.end - start + 1;
    headers.set("Content-Range", `bytes ${start}-${actual.end}/${size}`);
  } else if (upstream.status !== 200 || rawRange !== null) {
    badUpstream(upstream);
  }
  checkTransfer(upstream, expectedBytes);

  const cacheable = !range && size <= MAX_CACHED_FILE_BYTES;
  const bytes = cacheable ? await readBoundedBody(upstream.body, size).catch(() => undefined) : undefined;
  if (cacheable && bytes?.length !== size) throw new GitHubReadError("upstream");
  let stream = upstream.body;
  let type = fileMediaType(filename);
  if (type.startsWith("image/")) {
    const hint = type;
    const length = Math.min(SIGNATURE_BYTES, size);
    try {
      type = await source.store.cached(`raster-type:v1:${repository.id}:${sha}:${path}`, PINNED_TTL, async () => {
        let prefix = bytes?.subarray(0, length);
        if (length === 0) return DOWNLOAD;
        if (!prefix && start === 0 && expectedBytes >= length && stream) {
          const peeked = await peekBody(stream, length).catch(() => { throw new GitHubReadError("upstream"); });
          stream = peeked.stream;
          prefix = peeked.prefix;
        }
        // The requested range may omit part of the signature (SEC-014).
        prefix ??= await rasterPrefix(source, repository, sha, path, size, length);
        if (prefix.length !== length) throw new GitHubReadError("upstream");
        return matchesRaster(hint, prefix) ? hint : DOWNLOAD;
      });
    } catch (error) {
      void stream?.cancel().catch(() => undefined);
      throw error;
    }
  }
  const body = bytes ?? fittedBody(stream, expectedBytes);
  headers.set("Content-Type", type);
  headers.set("Content-Length", String(expectedBytes));
  headers.set("Accept-Ranges", "bytes");
  if (type === DOWNLOAD) headers.set("Content-Disposition", `attachment; filename="${filename}"`);

  if (cacheable) {
    const internal = new Headers(headers);
    internal.set("Cache-Control", `public, max-age=${PINNED_TTL}, immutable`);
    await source.store.put(key, new Response(body, { headers: internal }));
  }
  return new Response(body, { status: upstream.status, headers: publicHeaders(headers) });
}
