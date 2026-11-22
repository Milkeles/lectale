part of '../ipynb.dart';

int _utf8RuneBytes(int rune) => switch (rune) {
  <= 0x7f => 1,
  <= 0x7ff => 2,
  <= 0xffff => 3,
  _ => 4,
};

final class _TextBudget {
  _TextBudget(this._remaining);

  int _remaining;
  bool truncated = false;

  String take(List<String> parts, {bool stripControls = false}) {
    final units = _textUnits(parts, stripControls: stripControls).iterator;
    final result = StringBuffer();
    var hasUnit = units.moveNext();
    while (hasUnit) {
      var rune = units.current;
      hasUnit = units.moveNext();
      // A surrogate pair can straddle two notebook string fragments.
      if (rune >= 0xd800 &&
          rune <= 0xdbff &&
          hasUnit &&
          units.current >= 0xdc00 &&
          units.current <= 0xdfff) {
        rune = 0x10000 + ((rune - 0xd800) << 10) + (units.current - 0xdc00);
        hasUnit = units.moveNext();
      }
      final size = _utf8RuneBytes(rune);
      if (size > _remaining) {
        truncated = true;
        _remaining = 0;
        break;
      }
      _remaining -= size;
      result.writeCharCode(rune);
    }
    return result.toString();
  }
}

Iterable<int> _textUnits(
  List<String> parts, {
  required bool stripControls,
}) sync* {
  if (!stripControls) {
    for (final part in parts) {
      yield* part.codeUnits;
    }
    return;
  }

  final cursor = _TextCursor(parts);
  for (var unit = cursor.current; unit != null; unit = cursor.current) {
    cursor.advance();
    switch (unit) {
      case 0x1b:
        cursor.skipEscape();
      case 0x9b:
        cursor.skipCsi();
      case 0x90 || 0x98 || 0x9d || 0x9e || 0x9f:
        cursor.skipControlString();
      case >= 0x00 && <= 0x08:
      case 0x0b || 0x0c:
      case >= 0x0e && <= 0x1f:
      case >= 0x7f && <= 0x9f:
      case >= 0x202a && <= 0x202e:
      case >= 0x2066 && <= 0x2069:
        break;
      default:
        yield unit;
    }
  }
}

/// Walks split notebook text without joining it or copying skipped sequences.
final class _TextCursor {
  _TextCursor(this._parts) {
    _skipEmptyParts();
  }

  final List<String> _parts;
  int _part = 0;
  int _offset = 0;

  int? get current =>
      _part < _parts.length ? _parts[_part].codeUnitAt(_offset) : null;

  void advance() {
    _offset++;
    _skipEmptyParts();
  }

  void _skipEmptyParts() {
    while (_part < _parts.length && _offset == _parts[_part].length) {
      _part++;
      _offset = 0;
    }
  }

  bool _skipIfInRange(int low, int high) {
    final unit = current;
    if (unit == null || unit < low || unit > high) return false;
    advance();
    return true;
  }

  void skipEscape() {
    switch (current) {
      case 0x5b: // CSI
        advance();
        skipCsi();
      case 0x5d || 0x50 || 0x58 || 0x5e || 0x5f: // OSC, DCS, SOS, PM, APC
        advance();
        skipControlString();
      default:
        while (_skipIfInRange(0x20, 0x2f)) {}
        _skipIfInRange(0x30, 0x7e);
    }
  }

  void skipCsi() {
    while (_skipIfInRange(0x30, 0x3f)) {}
    while (_skipIfInRange(0x20, 0x2f)) {}
    _skipIfInRange(0x40, 0x7e);
  }

  void skipControlString() {
    final startPart = _part;
    final startOffset = _offset;
    for (var unit = current; unit != null; unit = current) {
      if (unit == 0x07 || unit == 0x9c) {
        advance();
        return;
      }
      if (unit == 0x1b) {
        advance();
        if (current == 0x5c) {
          advance();
          return;
        }
        break;
      }
      // Stop at another control sequence or line break. Replaying an
      // unterminated string then costs at most one extra pass over its text.
      if (unit == 0x0a || unit == 0x0d || (unit >= 0x80 && unit <= 0x9f)) {
        break;
      }
      advance();
    }
    _part = startPart;
    _offset = startOffset;
  }
}
