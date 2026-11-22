import { describe, expect, it } from "vitest";
import { IMAGE_HEADER_BYTES, imageSize } from "../../src/preview/image-size";

const width = 1200;
const height = 1800;
const ascii = (value: string) => Array.from(value, (char) => char.charCodeAt(0));
const be32 = (value: number) => [value >>> 24, (value >>> 16) & 255, (value >>> 8) & 255, value & 255];
const box = (type: string, data: number[]) => [...be32(data.length + 8), ...ascii(type), ...data];

function png(w: number, h: number): number[] {
  return [137, 80, 78, 71, 13, 10, 26, 10, ...be32(13), ...ascii("IHDR"),
    ...be32(w), ...be32(h), 8, 2, 0, 0, 0, ...be32(0)];
}

const jpegFrame = [255, 0xc2, 0, 11, 8, 7, 8, 4, 176, 1, 1, 0x11, 0];
const jpeg = [255, 0xd8, 255, 0xe1, 0, 5, 0, 255, 0xc0, ...jpegFrame];

function webp(tag: string, payload: number[]): number[] {
  const pad = payload.length % 2 ? [0] : [];
  return [...ascii("RIFF"), ...be32(12 + payload.length + pad.length).reverse(), ...ascii("WEBP"),
    ...ascii(tag), ...be32(payload.length).reverse(), ...payload, ...pad];
}

const vp8 = webp("VP8 ", [0, 0, 0, 0x9d, 1, 0x2a, 176, 4, 8, 7]);
const vp8l = webp("VP8L", [0x2f, ...be32(((height - 1) << 14) | (width - 1)).reverse()]);
const vp8x = webp("VP8X", [0, 0, 0, 0, 175, 4, 0, 7, 7, 0]);

const avif = [
  ...box("ftyp", [...ascii("mif1"), ...be32(0), ...ascii("avif")]),
  ...box("meta", [
    ...be32(0),
    ...box("pitm", [...be32(0), 0, 2]),
    ...box("iprp", [
      ...box("ipco", [
        ...box("ispe", [...be32(0), ...be32(60), ...be32(90)]),
        ...box("ispe", [...be32(0), ...be32(width), ...be32(height)]),
      ]),
      ...box("ipma", [...be32(0), ...be32(2), 0, 1, 1, 1, 0, 2, 1, 0x82]),
    ]),
  ]),
];

describe("imageSize (O2)", () => {
  const headers = [
    ["png", "IHDR", png(width, height)],
    ["jpeg", "SOF2 after an application segment", jpeg],
    ["webp", "VP8", vp8],
    ["webp", "VP8L", vp8l],
    ["webp", "VP8X", vp8x],
    ["avif", "ispe associated with the primary item", avif],
  ] as const;

  it.each(headers)("reads %s dimensions from %s", (format, _header, bytes) => {
    const wrapped = new Uint8Array([0, ...bytes]);
    expect(imageSize(wrapped.subarray(1))).toEqual({ format, width, height });
  });

  it.each(headers)("rejects a truncated %s header (%s)", (_format, _header, bytes) => {
    const header = new Uint8Array(bytes);
    for (let i = 0; i < header.length - (bytes === vp8l ? 1 : 0); i++) {
      expect(imageSize(header.subarray(0, i)), `prefix length ${i}`).toBeNull();
    }
  });

  it("rejects unknown formats and dimensions outside 1–16384 pixels", () => {
    expect(imageSize(new Uint8Array(ascii("GIF89a")))).toBeNull();
    expect(imageSize(new Uint8Array(png(0, height)))).toBeNull();
    expect(imageSize(new Uint8Array(png(width, 0xffffffff)))).toBeNull();
    expect(imageSize(new Uint8Array(png(16_385, height)))).toBeNull();
    expect(imageSize(new Uint8Array(png(16_384, height)))).toMatchObject({ width: 16_384 });
  });

  it("stops looking for JPEG frames at 64 KiB", () => {
    const bytes = new Uint8Array(IMAGE_HEADER_BYTES + jpegFrame.length + 4);
    bytes.set([255, 0xd8, 255, 0xe1, 255, 255]);
    bytes.set(jpegFrame, IMAGE_HEADER_BYTES + 3);
    expect(imageSize(bytes)).toBeNull();
  });
});
