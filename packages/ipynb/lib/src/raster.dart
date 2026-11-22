part of '../ipynb.dart';

int _base64Sextet(int unit) => switch (unit) {
  >= 0x41 && <= 0x5a => unit - 0x41, // A-Z
  >= 0x61 && <= 0x7a => unit - 0x61 + 26, // a-z
  >= 0x30 && <= 0x39 => unit - 0x30 + 52, // 0-9
  0x2b => 62, // +
  0x2f => 63, // /
  _ => -1,
};

/// Reads only the header bytes needed from validated base64. JPEG APP and
/// table segments can be skipped by length, keeping the encoded image lazy.
final class _RasterHeader {
  const _RasterHeader(this._encoded, this._length);

  final String _encoded;
  final int _length;

  int _byte(int index) {
    final bitOffset = index * 8;
    final sextet = bitOffset ~/ 6;
    final shift = 4 - bitOffset % 6;
    final left = _base64Sextet(_encoded.codeUnitAt(sextet));
    final right = _base64Sextet(_encoded.codeUnitAt(sextet + 1));
    return ((left << 6 | right) >> shift) & 0xff;
  }

  int _uint16(int offset) => _byte(offset) * 256 + _byte(offset + 1);

  int _uint32(int offset) => _uint16(offset) * 65536 + _uint16(offset + 2);

  (int, int)? png() {
    // Signature (8), length (4), type (4), IHDR (13), CRC (4).
    if (_length < 33 ||
        _uint32(0) != 0x89504e47 ||
        _uint32(4) != 0x0d0a1a0a ||
        _uint32(8) != 13 ||
        _uint32(12) != 0x49484452) {
      return null;
    }
    final width = _uint32(16);
    final height = _uint32(20);
    if (width == 0 ||
        width > 0x7fffffff ||
        height == 0 ||
        height > 0x7fffffff) {
      return null;
    }
    final depth = _byte(24);
    final validDepth = switch (_byte(25)) {
      0 => depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16,
      2 || 4 || 6 => depth == 8 || depth == 16,
      3 => depth == 1 || depth == 2 || depth == 4 || depth == 8,
      _ => false,
    };
    if (!validDepth ||
        _byte(26) != 0 ||
        _byte(27) != 0 ||
        _byte(28) > 1 ||
        _ihdrCrc() != _uint32(29)) {
      return null;
    }
    return (width, height);
  }

  int _ihdrCrc() {
    var crc = 0xffffffff;
    for (var offset = 12; offset < 29; offset++) {
      crc ^= _byte(offset);
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
      }
    }
    return crc ^ 0xffffffff;
  }

  (int, int)? jpeg() {
    if (_length < 2 || _uint16(0) != 0xffd8) return null;
    var offset = 2;
    while (offset < _length && _byte(offset++) == 0xff) {
      // Markers may be preceded by fill bytes.
      while (offset < _length && _byte(offset) == 0xff) {
        offset++;
      }
      if (offset == _length) return null;
      final marker = _byte(offset++);
      if (marker == 0x01) continue; // Standalone TEM marker.
      // Stop before scan data or a hierarchical image. In the latter the
      // first frame's dimensions need not describe the full image.
      if (marker < 0xc0 ||
          (marker >= 0xd0 && marker <= 0xda) ||
          marker == 0xde) {
        return null;
      }
      if (offset + 2 > _length) return null;
      final size = _uint16(offset);
      if (size < 2 || size > _length - offset) return null;
      if (marker <= 0xcf &&
          marker != 0xc4 &&
          marker != 0xc8 &&
          marker != 0xcc) {
        return _jpegFrame(marker, offset, size);
      }
      offset += size;
    }
    return null;
  }

  (int, int)? _jpegFrame(int marker, int offset, int size) {
    if (size < 11) return null;
    final precision = _byte(offset + 2);
    final height = _uint16(offset + 3);
    final width = _uint16(offset + 5);
    final components = _byte(offset + 7);
    if (width == 0 || height == 0 || size != 8 + 3 * components) return null;
    final lossless = const [0xc3, 0xc7, 0xcb, 0xcf].contains(marker);
    final validPrecision = switch (marker) {
      0xc0 => precision == 8,
      _ when lossless => precision >= 2 && precision <= 16,
      _ => precision == 8 || precision == 12,
    };
    if (!validPrecision) return null;
    final componentIds = <int>{};
    for (var at = offset + 8; at < offset + size; at += 3) {
      final sampling = _byte(at + 1);
      final quantisationTable = _byte(at + 2);
      final horizontal = sampling >> 4;
      final vertical = sampling & 0xf;
      if (!componentIds.add(_byte(at)) ||
          horizontal < 1 ||
          horizontal > 4 ||
          vertical < 1 ||
          vertical > 4 ||
          quantisationTable > (lossless ? 0 : 3)) {
        return null;
      }
    }
    return (width, height);
  }
}
