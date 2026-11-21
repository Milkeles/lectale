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
  const cacheName = `public-course:v1:${repository.id}:${sha}:${path}:2`;
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
  const rawLength = contentLength(upstream);
  const encoding = upstream.headers.get("Content-Encoding");
  if (encoding && encoding !== "identity") badUpstream(upstream);

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
  if (rawLength !== undefined && rawLength !== expectedBytes) badUpstream(upstream);

  let body: BodyInit | null;
  let prefix: Uint8Array = new Uint8Array(0);
  const cacheable = !range && size <= MAX_CACHED_FILE_BYTES;
  let type = fileMediaType(filename);
  if (cacheable) {
    const bytes = await readBoundedBody(upstream.body, size).catch(() => undefined);
    if (!bytes || bytes.length !== size) throw new GitHubReadError("upstream");
    body = bytes;
    prefix = bytes.subarray(0, SIGNATURE_BYTES);
  } else {
    let stream = upstream.body;
    if (start === 0 && stream && type.startsWith("image/")) {
      const peeked = await peekBody(stream, Math.min(SIGNATURE_BYTES, expectedBytes)).catch(() => {
        throw new GitHubReadError("upstream");
      });
      prefix = peeked.prefix;
      stream = peeked.stream;
    }
    body = fittedBody(stream, expectedBytes);
  }
  if (type.startsWith("image/") && !matchesRaster(type, prefix)) type = DOWNLOAD;
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
