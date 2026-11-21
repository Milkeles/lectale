/** Class B data is immutable at the pinned SHA, with a bounded public TTL (CACHE-005). */
export const PINNED_CACHE_CONTROL = "public, max-age=300, immutable";

export type PreviewCache = Pick<Cache, "match" | "put">;

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
