type ByteRange = { suffix: number } | { start: number; end?: number };
type ByteInterval = { start: number; end: number };

const RANGE = /^bytes=(?:(\d+)-(\d*)|-(\d+))$/u;
const CONTENT_RANGE = /^bytes (\d+)-(\d+)\/(\d+)$/u;
const UNSATISFIED_RANGE = /^bytes \*\/(\d+)$/u;

/** Parses a single HTTP byte range using safe integers (SEC-027). */
export function parseRange(value: string): ByteRange | undefined {
  if (value.length > 128) return;
  const match = RANGE.exec(value);
  if (!match || match[0] !== value) return;
  if (match[3] !== undefined) {
    const suffix = Number(match[3]);
    if (Number.isSafeInteger(suffix) && suffix > 0) return { suffix };
    return;
  }
  const start = Number(match[1]);
  const end = match[2] ? Number(match[2]) : undefined;
  if (Number.isSafeInteger(start) && (end === undefined || (Number.isSafeInteger(end) && end >= start))) {
    return end === undefined ? { start } : { start, end };
  }
}

/** Resolves suffix and open ranges and clamps a closed range at EOF. */
export function byteInterval(range: ByteRange, size: number): ByteInterval | undefined {
  if (size === 0) return;
  if ("suffix" in range) return { start: Math.max(0, size - range.suffix), end: size - 1 };
  if (range.start >= size) return;
  return { start: range.start, end: Math.min(range.end ?? size - 1, size - 1) };
}

export function readContentRange(value: string | null) {
  const match = value && CONTENT_RANGE.exec(value);
  if (!match || match[0] !== value) return;
  const start = Number(match[1]);
  const end = Number(match[2]);
  const size = Number(match[3]);
  if ([start, end, size].every(Number.isSafeInteger) && start <= end && end < size) return { start, end, size };
}

export function readUnsatisfiedRange(value: string | null): number | undefined {
  const match = value && UNSATISFIED_RANGE.exec(value);
  if (!match || match[0] !== value) return;
  const size = Number(match[1]);
  if (Number.isSafeInteger(size)) return size;
}
