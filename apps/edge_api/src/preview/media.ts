const MARKDOWN = "text/markdown; charset=utf-8";
const TEXT = "text/plain; charset=utf-8";
export const DOWNLOAD = "application/octet-stream";

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

export const SIGNATURE_BYTES = 32;

export function fileMediaType(filename: string): string {
  const extension = /\.([^.]+)$/u.exec(filename)?.[1]?.toLowerCase() ?? "";
  return MEDIA_TYPES.get(extension) ?? DOWNLOAD;
}

function at(bytes: Uint8Array, signature: string | number[], offset = 0): boolean {
  const codes = typeof signature === "string" ? [...signature].map((char) => char.charCodeAt(0)) : signature;
  return codes.every((code, index) => bytes[offset + index] === code);
}

/** Verifies raster container signatures before advertising an inline media type (SEC-014). */
export function matchesRaster(type: string, bytes: Uint8Array): boolean {
  switch (type) {
    case "image/png": return at(bytes, [137, 80, 78, 71, 13, 10, 26, 10]);
    case "image/jpeg": return at(bytes, [255, 216, 255]);
    case "image/gif": return at(bytes, "GIF87a") || at(bytes, "GIF89a");
    case "image/webp": return at(bytes, "RIFF") && at(bytes, "WEBP", 8);
    case "image/avif": {
      if (!at(bytes, "ftyp", 4)) return false;
      if (at(bytes, "avif", 8) || at(bytes, "avis", 8)) return true;
      // Major brand may be generic. Compatible brands are inside the ftyp box.
      const boxSize = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(0);
      for (let offset = 16; offset + 4 <= Math.min(boxSize, bytes.length); offset += 4) {
        if (at(bytes, "avif", offset) || at(bytes, "avis", offset)) return true;
      }
      return false;
    }
    case "image/bmp": return at(bytes, "BM");
    case "image/x-icon": return at(bytes, [0, 0, 1, 0]);
    case "image/jxl": return at(bytes, [255, 10]) || at(bytes, [0, 0, 0, 12, 74, 88, 76, 32, 13, 10, 135, 10]);
    case "image/tiff": return at(bytes, [73, 73, 42, 0]) || at(bytes, [77, 77, 0, 42])
      || at(bytes, [73, 73, 43, 0]) || at(bytes, [77, 77, 0, 43]);
    default: return false;
  }
}

/** Reads only enough bytes for a signature, then replays the original stream. */
export async function peekBody(body: ReadableStream<Uint8Array>, length: number) {
  const reader = body.getReader();
  const prefix = new Uint8Array(length);
  const chunks: Uint8Array[] = [];
  let count = 0;
  try {
    while (count < length) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value.byteLength === 0) continue;
      const bytes = value.subarray(0, length - count);
      prefix.set(bytes, count);
      count += bytes.byteLength;
      chunks.push(value);
    }
  } catch (error) {
    reader.releaseLock();
    throw error;
  }

  let index = 0;
  return {
    prefix: prefix.subarray(0, count),
    stream: new ReadableStream<Uint8Array>({
      async pull(controller) {
        try {
          if (index < chunks.length) {
            controller.enqueue(chunks[index++]!);
            return;
          }
          chunks.length = 0;
          const { done, value } = await reader.read();
          if (done) {
            reader.releaseLock();
            controller.close();
          } else {
            controller.enqueue(value);
          }
        } catch (error) {
          reader.releaseLock();
          controller.error(error);
        }
      },
      cancel: (reason: unknown) => reader.cancel(reason),
    }),
  };
}
