import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:resource_renderers/src/widgets/image_header.dart';

Uint8List _png(int width, int height) {
  final bytes = ByteData(33);
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    bytes.setUint8(i, signature[i]);
  }
  bytes
    ..setUint32(8, 13)
    ..setUint32(12, 0x49484452)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes.buffer.asUint8List();
}

Uint8List _gif(int width, int height) {
  final bytes = ByteData(13);
  for (final (i, c) in 'GIF89a'.codeUnits.indexed) {
    bytes.setUint8(i, c);
  }
  bytes
    ..setUint16(6, width, Endian.little)
    ..setUint16(8, height, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _jpeg(int width, int height) {
  final bytes = BytesBuilder()
    ..add([0xFF, 0xD8])
    // An APP0 segment to skip: length 16 including its own two bytes.
    ..add([0xFF, 0xE0, 0x00, 0x10])
    ..add(List.filled(14, 0))
    // SOF0: length 17, precision 8, height, width.
    ..add([0xFF, 0xC0, 0x00, 0x11, 0x08])
    ..add([height >> 8, height & 0xFF, width >> 8, width & 0xFF])
    ..add(List.filled(10, 0));
  return bytes.toBytes();
}

Uint8List _webpLossy(int width, int height) {
  final bytes = ByteData(40);
  for (final (i, c) in 'RIFF'.codeUnits.indexed) {
    bytes.setUint8(i, c);
  }
  for (final (i, c) in 'WEBPVP8 '.codeUnits.indexed) {
    bytes.setUint8(8 + i, c);
  }
  bytes
    ..setUint16(26, width, Endian.little)
    ..setUint16(28, height, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _webpLossless(int width, int height) {
  final bytes = ByteData(40);
  for (final (i, c) in 'RIFF'.codeUnits.indexed) {
    bytes.setUint8(i, c);
  }
  for (final (i, c) in 'WEBPVP8L'.codeUnits.indexed) {
    bytes.setUint8(8 + i, c);
  }
  bytes
    ..setUint8(20, 0x2F)
    ..setUint32(21, (width - 1) | ((height - 1) << 14), Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _webpExtended(int width, int height) {
  final bytes = ByteData(40);
  for (final (i, c) in 'RIFF'.codeUnits.indexed) {
    bytes.setUint8(i, c);
  }
  for (final (i, c) in 'WEBPVP8X'.codeUnits.indexed) {
    bytes.setUint8(8 + i, c);
  }
  final w = width - 1;
  final h = height - 1;
  bytes
    ..setUint8(24, w & 0xFF)
    ..setUint8(25, (w >> 8) & 0xFF)
    ..setUint8(26, (w >> 16) & 0xFF)
    ..setUint8(27, h & 0xFF)
    ..setUint8(28, (h >> 8) & 0xFF)
    ..setUint8(29, (h >> 16) & 0xFF);
  return bytes.buffer.asUint8List();
}

void main() {
  test('reads PNG, GIF, JPEG and the three WebP flavours', () {
    expect(imageSizeFromHeader(_png(1200, 600)), const Size(1200, 600));
    expect(imageSizeFromHeader(_gif(320, 200)), const Size(320, 200));
    expect(imageSizeFromHeader(_jpeg(4000, 3000)), const Size(4000, 3000));
    expect(imageSizeFromHeader(_webpLossy(800, 450)), const Size(800, 450));
    expect(imageSizeFromHeader(_webpLossless(641, 480)), const Size(641, 480));
    expect(
      imageSizeFromHeader(_webpExtended(5000, 2500)),
      const Size(5000, 2500),
    );
  });

  test('returns null for other bytes and for bytes that end early', () {
    expect(imageSizeFromHeader(Uint8List.fromList([1, 2, 3])), isNull);
    expect(imageSizeFromHeader(Uint8List(0)), isNull);
    expect(imageSizeFromHeader(_png(10, 10).sublist(0, 20)), isNull);
    expect(imageSizeFromHeader(_jpeg(10, 10).sublist(0, 12)), isNull);
    expect(
      imageSizeFromHeader(Uint8List.fromList('<svg></svg>'.codeUnits)),
      isNull,
    );
    expect(imageSizeFromHeader(_png(0, 0)), isNull);
  });
}
