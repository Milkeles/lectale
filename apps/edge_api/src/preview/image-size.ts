import { matchesRaster } from "./media";

/** Maximum prefix to fetch and inspect for cover dimensions (O2). */
export const IMAGE_HEADER_BYTES = 64 * 1024;
const MAX_DIMENSION = 16_384;

type Dimensions = { width: number; height: number };
type Format = "png" | "jpeg" | "webp" | "avif";

function jpeg(view: DataView): Dimensions | undefined {
  let offset = 2;
  while (offset < view.byteLength && view.getUint8(offset++) === 0xff) {
    while (offset < view.byteLength && view.getUint8(offset) === 0xff) offset++;
    if (offset + 3 > view.byteLength) return;
    const marker = view.getUint8(offset++);
    if (marker === 0 || marker === 0xd8 || marker === 0xd9 || marker === 0xda) return;
    if (marker === 1) continue;
    const length = view.getUint16(offset);
    if (length < 2 || offset + length > view.byteLength) return;
    // SOFn markers exclude the Huffman table, reserved JPG, and arithmetic table.
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      if (length < 11 || length !== 8 + 3 * view.getUint8(offset + 7)) return;
      return { width: view.getUint16(offset + 5), height: view.getUint16(offset + 3) };
    }
    offset += length;
  }
}

function webp(view: DataView): Dimensions | undefined {
  if (view.byteLength < 20) return;
  const length = view.getUint32(16, true);
  if (12 + length + (length % 2) > view.getUint32(4, true)) return;
  const available = Math.min(length, view.byteLength - 20);
  const tag = view.getUint32(12);
  if (tag === 0x56503820 && available >= 10 && !(view.getUint8(20) & 1) // VP8
      && view.getUint16(23) === 0x9d01 && view.getUint8(25) === 0x2a) {
    return { width: view.getUint16(26, true) & 0x3fff, height: view.getUint16(28, true) & 0x3fff };
  }
  if (tag === 0x5650384c && available >= 5 && view.getUint8(20) === 0x2f) { // VP8L
    const bits = view.getUint32(21, true);
    if ((bits >>> 29) !== 0) return;
    return { width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1 };
  }
  if (tag === 0x56503858 && length === 10 && available >= 10) { // VP8X
    return { width: (view.getUint32(23, true) >>> 8) + 1, height: (view.getUint32(26, true) >>> 8) + 1 };
  }
}

type Box = { type: string; start: number; end: number };

function* boxes(view: DataView, start: number, end: number): Generator<Box> {
  const limit = Math.min(end, view.byteLength);
  for (let offset = start; offset + 8 <= limit;) {
    const type = String.fromCharCode(...new Uint8Array(view.buffer, view.byteOffset + offset + 4, 4));
    let header = 8;
    let size = view.getUint32(offset);
    if (size === 1) {
      header = 16;
      if (offset + header > limit) return;
      size = Number(view.getBigUint64(offset + 8));
    } else if (size === 0) {
      size = end - offset;
    }
    if (!Number.isSafeInteger(size) || size < header || size > end - offset) return;
    yield { type, start: offset + header, end: offset + size };
    offset += size;
  }
}

function associatedExtents(view: DataView, box: Box, primary: number, properties: Box[]): Dimensions | undefined {
  if (box.end > view.byteLength || box.end - box.start < 8) return;
  const version = view.getUint8(box.start);
  if (version > 1) return;
  const idBytes = version === 0 ? 2 : 4;
  const indexBytes = (view.getUint8(box.start + 3) & 1) === 0 ? 1 : 2;
  const entries = view.getUint32(box.start + 4);
  let offset = box.start + 8;
  for (let i = 0; i < entries; i++) {
    if (offset + idBytes + 1 > box.end) return;
    const id = idBytes === 2 ? view.getUint16(offset) : view.getUint32(offset);
    const count = view.getUint8(offset + idBytes);
    offset += idBytes + 1;
    const next = offset + indexBytes * count;
    if (next > box.end) return;
    if (id === primary) {
      for (; offset < next; offset += indexBytes) {
        const index = indexBytes === 1 ? view.getUint8(offset) & 0x7f : view.getUint16(offset) & 0x7fff;
        const property = properties[index - 1];
        if (property?.type === "ispe" && property.end - property.start === 12
            && property.end <= view.byteLength && view.getUint32(property.start) === 0) {
          return { width: view.getUint32(property.start + 4), height: view.getUint32(property.start + 8) };
        }
      }
    }
    offset = next;
  }
}

function avif(view: DataView): Dimensions | undefined {
  const meta = [...boxes(view, 0, view.byteLength)].find(({ type }) => type === "meta");
  if (!meta || meta.start + 4 > meta.end || view.getUint32(meta.start) !== 0) return;
  const children = [...boxes(view, meta.start + 4, meta.end)];
  const primary = children.find(({ type }) => type === "pitm");
  const itemProps = children.find(({ type }) => type === "iprp");
  if (!primary || !itemProps || primary.end - primary.start < 6) return;
  const version = view.getUint8(primary.start);
  if (version > 1 || (version === 1 && primary.end - primary.start < 8)) return;
  const id = version === 0 ? view.getUint16(primary.start + 4) : view.getUint32(primary.start + 4);
  const items = [...boxes(view, itemProps.start, itemProps.end)];
  const container = items.find(({ type }) => type === "ipco");
  if (!container) return;
  // A thumbnail, tile, or alpha image can have its own ispe property.
  const properties = [...boxes(view, container.start, container.end)];
  for (const box of items) {
    if (box.type !== "ipma") continue;
    const size = associatedExtents(view, box, id, properties);
    if (size) return size;
  }
}

/** Reads declared dimensions from a raster prefix, or returns null for unrecognized or unsafe headers (O2). */
export function imageSize(input: Uint8Array): (Dimensions & { format: Format }) | null {
  const bytes = input.subarray(0, IMAGE_HEADER_BYTES);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let format: Format;
  let size: Dimensions | undefined;
  if (matchesRaster("image/png", bytes)) {
    format = "png";
    if (bytes.length >= 33 && view.getUint32(8) === 13 && view.getUint32(12) === 0x49484452) {
      size = { width: view.getUint32(16), height: view.getUint32(20) };
    }
  } else if (matchesRaster("image/jpeg", bytes)) {
    format = "jpeg";
    size = jpeg(view);
  } else if (matchesRaster("image/webp", bytes)) {
    format = "webp";
    size = webp(view);
  } else if (matchesRaster("image/avif", bytes)) {
    format = "avif";
    size = avif(view);
  } else {
    return null;
  }
  if (!size || ![size.width, size.height].every((side) => side > 0 && side <= MAX_DIMENSION)) return null;
  return { format, ...size };
}
