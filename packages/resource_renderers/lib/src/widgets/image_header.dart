import 'dart:typed_data';
import 'dart:ui' show Size;

/// The widest or tallest an image may be, in pixels.
const int maxImageSide = 8192;

/// The most pixels an image may have in total (16 megapixels).
const int maxImagePixels = 16 * 1000 * 1000;

/// The most bytes of an image the app reads (10 MB).
const int maxImageBytes = 10 * 1000 * 1000;

/// The bytes are not a PNG, GIF, JPEG or WebP image.
class ImageNotRaster implements Exception {
  /// Creates the signal.
  const ImageNotRaster();
}

/// The image's header claims more pixels than the app decodes.
class ImageTooLarge implements Exception {
  /// Creates the signal for an image of [size].
  const ImageTooLarge(this.size);

  /// The size the header claims.
  final Size size;
}

/// The pixel size of a PNG, GIF, JPEG or WebP image, read from its header
/// without decoding, or null when the bytes are not one of those or end
/// early.
///
/// The app needs the size before it draws, to decode at the size shown, and
/// the engines differ in whether they can report it without a full decode
/// (the web engine can't from an `ImageDescriptor`), so the header is read
/// here. The reader never looks past the first bytes it needs.
Size? imageSizeFromHeader(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final length = bytes.length;

  bool starts(List<int> prefix, [int at = 0]) {
    if (length < at + prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[at + i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  Size? sized(num width, num height) => width > 0 && height > 0
      ? Size(width.toDouble(), height.toDouble())
      : null;

  // PNG: signature, then IHDR with big-endian width and height.
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    if (length < 24) {
      return null;
    }
    return sized(data.getUint32(16), data.getUint32(20));
  }

  // GIF: "GIF87a" or "GIF89a", then little-endian width and height.
  if (starts(const [0x47, 0x49, 0x46, 0x38]) && length >= 10) {
    return sized(
      data.getUint16(6, Endian.little),
      data.getUint16(8, Endian.little),
    );
  }

  // WebP: RIFF container; the first chunk says which flavour.
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8) &&
      length >= 30) {
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    switch (chunk) {
      case 'VP8 ':
        return sized(
          data.getUint16(26, Endian.little) & 0x3fff,
          data.getUint16(28, Endian.little) & 0x3fff,
        );
      case 'VP8L':
        final bits = data.getUint32(21, Endian.little);
        return sized((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
      case 'VP8X':
        final width = bytes[24] | (bytes[25] << 8) | (bytes[26] << 16);
        final height = bytes[27] | (bytes[28] << 8) | (bytes[29] << 16);
        return sized(width + 1, height + 1);
    }
    return null;
  }

  // JPEG: walk the segments to the first start-of-frame marker.
  if (starts(const [0xFF, 0xD8])) {
    var at = 2;
    while (at + 4 <= length) {
      if (bytes[at] != 0xFF) {
        return null;
      }
      final marker = bytes[at + 1];
      if (marker == 0xFF) {
        at++;
        continue;
      }
      // Markers without a length: standalone and restart markers.
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        at += 2;
        continue;
      }
      final segment = data.getUint16(at + 2);
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) {
        if (at + 9 > length) {
          return null;
        }
        return sized(data.getUint16(at + 7), data.getUint16(at + 5));
      }
      if (segment < 2) {
        return null;
      }
      at += 2 + segment;
    }
  }
  return null;
}
