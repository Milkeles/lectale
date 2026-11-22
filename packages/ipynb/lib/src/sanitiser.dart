part of '../ipynb.dart';

const _rasterMimes = ['image/png', 'image/jpeg'];
const List<String> _outputMimes = [
  'text/markdown',
  'text/latex',
  ..._rasterMimes,
  'text/plain',
];
const _unknownMime = 'application/octet-stream';

final _mimePattern = RegExp(
  r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+/[A-Za-z0-9!#$%&'*+.^_`|~-]+$",
);

String _mimeLabel(String key) =>
    key.length <= 255 && _mimePattern.hasMatch(key) ? key : _unknownMime;

// Strip CSI, terminal control strings, and single escapes. Keep line breaks
// and tabs so terminal formatting cannot obscure the readable text.
final _ansi = RegExp(
  r'(?:\x1b\[|\x9b)[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]?'
  r'|(?:\x1b[\]PX^_]|[\x90\x98\x9d-\x9f])'
  r'[^\x07\x1b\x9c\r\n]*(?:\x07|\x1b\\|\x9c)?'
  r'|\x1b[\x20-\x2f]*[\x30-\x7e]?'
  r'|[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]',
);

String _stripAnsi(String text) => text.replaceAll(_ansi, '');

final _base64Whitespace = RegExp(r'[ \t\r\n]');
final _base64Chunk = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');

final class _Sanitiser {
  _Sanitiser(this.limits);

  final NotebookLimits limits;
  bool truncated = false;

  Iterable<T> takeEntries<T>(List<T> entries, int limit) {
    if (entries.length > limit) truncated = true;
    return entries.take(limit);
  }

  StreamOutput stream(String name, String text) {
    final budget = _TextBudget(limits.maxTextBytesPerOutput);
    final output = StreamOutput._(
      budget.take(_stripAnsi(name)),
      budget.take(_stripAnsi(text)),
    );
    truncated |= budget.truncated;
    return output;
  }

  ErrorOutput error(String name, String value, List<Object?> traceback) {
    final budget = _TextBudget(limits.maxTextBytesPerOutput);
    final safeName = budget.take(_stripAnsi(name));
    final safeValue = budget.take(_stripAnsi(value));
    final lines = <String>[];
    for (final line in traceback) {
      if (lines.isNotEmpty) budget.take('\n');
      if (budget.truncated) break;
      final safeLine = budget.take(_stripAnsi(_readText(line)));
      if (budget.truncated && safeLine.isEmpty) break;
      lines.add(safeLine);
    }
    truncated |= budget.truncated;
    return ErrorOutput._(safeName, safeValue, lines);
  }

  TextOutput? text(String mime, Object? value) {
    final parts = _textParts(value);
    if (parts == null) return null;
    final budget = _TextBudget(limits.maxTextBytesPerOutput);
    final output = TextOutput._(mime, budget.take(parts.join()));
    truncated |= budget.truncated;
    return output;
  }

  ImageOutput? image(String mime, Object? value) {
    final parts = _textParts(value);
    if (parts == null) return null;
    final buffer = StringBuffer();
    var sextets = 0;
    var padding = 0;
    for (final part in parts) {
      final chunk = part.replaceAll(_base64Whitespace, '');
      final padStart = chunk.indexOf('=');
      final dataLength = padStart == -1 ? chunk.length : padStart;
      if (padding != 0 && dataLength != 0) return null;
      sextets += dataLength;
      padding += chunk.length - dataLength;
      // Each complete set of eight data bits contributes one decoded byte.
      if (sextets * 3 ~/ 4 > limits.maxImageBytes) {
        truncated = true;
        return null;
      }
      if (padding > 2 || !_base64Chunk.hasMatch(chunk)) return null;
      buffer.write(chunk);
    }
    if (buffer.isEmpty || buffer.length % 4 != 0) return null;

    final encoded = buffer.toString();
    if (!_matchesRaster(mime, encoded)) return null;
    return ImageOutput._(mime, encoded);
  }
}

bool _matchesRaster(String mime, String encoded) {
  final signature = mime == 'image/png'
      ? const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
      : const [0xff, 0xd8, 0xff];
  final prefixLength = (signature.length + 2) ~/ 3 * 4;
  if (encoded.length < prefixLength) return false;
  try {
    // Only the last quartet can contain invalid padding or unused bits.
    // Validate it now so reading ImageOutput.bytes cannot fail on base64.
    base64Decode(encoded.substring(encoded.length - 4));
    final prefix = base64Decode(encoded.substring(0, prefixLength));
    if (prefix.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (prefix[index] != signature[index]) return false;
    }
    return true;
  } on FormatException {
    return false;
  }
}

final class _TextBudget {
  _TextBudget(this._remaining);

  int _remaining;
  bool truncated = false;

  String take(String text) {
    var offset = 0;
    for (final rune in text.runes) {
      final size = switch (rune) {
        <= 0x7f => 1,
        <= 0x7ff => 2,
        <= 0xffff => 3,
        _ => 4,
      };
      if (size > _remaining) {
        truncated = true;
        _remaining = 0;
        return text.substring(0, offset);
      }
      _remaining -= size;
      offset += size == 4 ? 2 : 1;
    }
    return text;
  }
}
