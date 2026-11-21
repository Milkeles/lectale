import { GitHubReadError } from "../github/reader";
import { PreviewError } from "./errors";

export type PreviewCache = Pick<Cache, "match" | "put"> & Partial<Pick<Cache, "delete">>;

/** Synthetic keys use only the deployment origin and normalized, versioned coordinates. */
export function previewCacheKey(requestUrl: string, key: string): Request {
  return new Request(new URL(`/_lectale-cache/${key}`, requestUrl));
}

/** Treats cache failures as misses so GitHub remains the source of record. */
export async function matchPreviewCache(cache: PreviewCache | undefined, key: Request): Promise<Response | undefined> {
  try {
    return await cache?.match(key);
  } catch {
    return undefined;
  }
}

/** Stores only responses explicitly classified as public by the caller (V4-CACHE-02). */
export async function putPreviewCache(cache: PreviewCache, key: Request, response: Response): Promise<void> {
  try {
    await cache.put(key, response);
  } catch {
    // Cache storage is optional and may reject an otherwise valid response.
  }
}

export const VISIBILITY_TTL = 60;
export const NEGATIVE_TTL = 30;
export const PINNED_TTL = 300;

/** Downstream freshness starts after the last Worker visibility check (V4-CACHE-02). */
export const FILE_CACHE_CONTROL = "public, max-age=60, immutable, must-revalidate";

type CachedError =
  | { kind: "preview"; status: number; body: PreviewError["body"] }
  | { kind: "github"; code: GitHubReadError["kind"] };

type CachedResult<T> = { value: T } | { error: CachedError };

/** Shares plain results of metadata work in this isolate and persists public results in the Cache API. */
export class PreviewMemo {
  private readonly pending = new Map<string, Promise<unknown>>();

  async once<T>(key: Request, load: () => Promise<T>): Promise<T> {
    const pending = this.pending.get(key.url);
    if (pending) return pending as Promise<T>;
    const result = load();
    this.pending.set(key.url, result);
    try {
      return await result;
    } finally {
      this.pending.delete(key.url);
    }
  }
}

/** Stores public preview results and safe error markers under deployment-scoped keys (CACHE-005). */
export class PreviewStore {
  constructor(
    private readonly origin: string,
    private readonly cache: PreviewCache | undefined,
    private readonly memo: PreviewMemo,
  ) {}

  key(name: string): Request {
    return previewCacheKey(this.origin, name);
  }

  async match(key: Request): Promise<Response | undefined> {
    return matchPreviewCache(this.cache, key);
  }

  async put(key: Request, response: Response): Promise<void> {
    if (this.cache) await putPreviewCache(this.cache, key, response);
  }

  async delete(name: string): Promise<void> {
    try {
      await this.cache?.delete?.(this.key(name));
    } catch {
      // The visibility TTL still bounds entries when deletion is unavailable.
    }
  }

  async get<T>(name: string): Promise<T | undefined> {
    try {
      return await (await this.match(this.key(name)))?.json() as T | undefined;
    } catch {
      return undefined;
    }
  }

  async save<T>(name: string, value: T, ttl: number): Promise<void> {
    if (!this.cache) return;
    await this.put(this.key(name), Response.json(value, { headers: { "Cache-Control": `public, max-age=${ttl}` } }));
  }

  once<T>(name: string, load: () => Promise<T>): Promise<T> {
    return this.memo.once(this.key(name), load);
  }

  async peek<T>(name: string): Promise<T | undefined> {
    const cached = await this.get<CachedResult<T>>(name);
    if (cached && "value" in cached) return cached.value;
  }

  async cached<T>(name: string, ttl: number, load: () => Promise<T>): Promise<T> {
    return this.memo.once(this.key(name), async () => {
      const cached = await this.get<CachedResult<T>>(name);
      if (cached && "value" in cached) return cached.value;
      if (cached) {
        const { error } = cached;
        throw error.kind === "preview"
          ? new PreviewError(error.status, error.body)
          : new GitHubReadError(error.code);
      }

      try {
        const value = await load();
        await this.save<CachedResult<T>>(name, { value }, value === false ? NEGATIVE_TTL : ttl);
        return value;
      } catch (error) {
        // A raced namespace is retryable immediately. Throttling has a shared key.
        if (error instanceof GitHubReadError && (error.kind === "not_found" || error.kind === "upstream")) {
          await this.save<CachedResult<T>>(name, { error: { kind: "github", code: error.kind } }, NEGATIVE_TTL);
        }
        if (error instanceof PreviewError && (error.status === 413 || error.status === 422)) {
          await this.save<CachedResult<T>>(name, {
            error: { kind: "preview", status: error.status, body: error.body },
          }, NEGATIVE_TTL);
        }
        throw error;
      }
    });
  }
}
