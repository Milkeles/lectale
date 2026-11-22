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

final _base64Whitespace = RegExp(r'[ \t\r\n]+');

final class _Sanitiser {
  _Sanitiser(this.limits);

  final NotebookLimits limits;
  bool truncated = false;

  Iterable<T> takeEntries<T>(List<T> entries, int limit) {
    if (entries.length > limit) truncated = true;
    return entries.take(limit);
  }

  bool keepName(String name, int limit) {
    var remaining = limit;
    for (final rune in name.runes) {
      remaining -= _utf8RuneBytes(rune);
      if (remaining < 0) {
        truncated = true;
        return false;
      }
    }
    return true;
  }

  String source(List<String> parts) {
    final budget = _TextBudget(limits.maxSourceBytesPerCell);
    final source = budget.take(parts);
    truncated |= budget.truncated;
    return source;
  }

  StreamOutput stream(List<String> name, List<String> text) {
    final budget = _TextBudget(limits.maxTextBytesPerOutput);
    final output = StreamOutput._(
      budget.take(name, stripControls: true),
      budget.take(text, stripControls: true),
    );
    truncated |= budget.truncated;
    return output;
  }

  ErrorOutput error(
    List<String> name,
    List<String> value,
    List<Object?> traceback,
  ) {
    final budget = _TextBudget(limits.maxTextBytesPerOutput);
    final safeName = budget.take(name, stripControls: true);
    final safeValue = budget.take(value, stripControls: true);
    final lines = <String>[];
    for (final line in traceback) {
      if (lines.isNotEmpty) budget.take(const ['\n']);
      if (budget.truncated) break;
      final safeLine = budget.take(_readTextParts(line), stripControls: true);
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
    final output = TextOutput._(
      mime,
      budget.take(parts, stripControls: mime == 'text/plain'),
    );
    truncated |= budget.truncated;
    return output;
  }

  ImageOutput? image(String mime, Object? value) {
    final parts = _textParts(value);
    if (parts == null) return null;
    final payload = _base64Payload(parts);
    if (payload == null) return null;
    final (encoded, length) = payload;
    final header = _RasterHeader(encoded, length);
    final dimensions = mime == 'image/png' ? header.png() : header.jpeg();
    if (dimensions == null) return null;
    final (width, height) = dimensions;
    // Use division so very large dimensions cannot overflow the pixel check.
    if (width > limits.maxImagePixels ~/ height) {
      truncated = true;
      return null;
    }
    return ImageOutput._(mime, width, height, encoded);
  }

  (String, int)? _base64Payload(List<String> parts) {
    var sextets = 0;
    var padding = 0;
    var lastSextet = 0;
    var valid = true;
    var hasWhitespace = false;
    // Reject oversize payloads before allocating a normalised base64 string.
    for (final part in parts) {
      for (var offset = 0; offset < part.length; offset++) {
        final unit = part.codeUnitAt(offset);
        switch (unit) {
          case 0x09 || 0x0a || 0x0d || 0x20:
            hasWhitespace = true;
          case 0x3d: // =
            padding++;
          default:
            // Each complete set of eight data bits is one decoded byte.
            if (++sextets * 3 ~/ 4 > limits.maxImageBytes) {
              truncated = true;
              return null;
            }
            lastSextet = _base64Sextet(unit);
            valid &= padding == 0 && lastSextet >= 0;
        }
      }
    }
    if (!valid ||
        sextets == 0 ||
        padding > 2 ||
        (sextets + padding) % 4 != 0 ||
        (lastSextet & ((1 << (2 * padding)) - 1)) != 0) {
      return null;
    }
    final encoded = hasWhitespace
        ? parts.map((part) => part.replaceAll(_base64Whitespace, '')).join()
        : (parts.length == 1 ? parts.single : parts.join());
    return (encoded, sextets * 3 ~/ 4);
  }
}
