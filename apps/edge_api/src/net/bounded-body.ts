/** Reads at most the given byte budget. Returns undefined and cancels an oversized body. */
export async function readBoundedBody(
  body: ReadableStream<Uint8Array> | null,
  maxBytes: number,
): Promise<Uint8Array | undefined> {
  if (!body) return new Uint8Array();
  const reader = body.getReader();
  const bytes = new Uint8Array(maxBytes);
  let offset = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) return bytes.subarray(0, offset);
      if (value.byteLength > maxBytes - offset) {
        void reader.cancel().catch(() => undefined);
        return;
      }
      bytes.set(value, offset);
      offset += value.byteLength;
    }
  } finally {
    reader.releaseLock();
  }
}
