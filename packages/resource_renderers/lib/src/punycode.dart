/// Turns a host name into its ASCII form, so the host a learner sees is the
/// one the browser would contact: `bücher.example` becomes
/// `xn--bcher-kva.example` (RFC 3492 Punycode, RFC 5890 labels).
///
/// Returns null when the result is not a plain host name: a character
/// outside letters, digits and hyphens in a label, an empty label, a label
/// that starts or ends with a hyphen, or a name over 253 characters. Case is
/// folded to lower case first. There is no Unicode normalization beyond
/// that, so a look-alike spelling stays visibly different from the original.
String? asciiHost(String host) {
  final lower = host.toLowerCase();
  if (lower.isEmpty) {
    return null;
  }
  final labels = <String>[];
  for (final label in lower.split('.')) {
    if (label.isEmpty) {
      return null;
    }
    final runes = label.runes.toList();
    final ascii = runes.every((rune) => rune < 128);
    final encoded = ascii ? label : _encodeLabel(runes);
    if (encoded == null) {
      return null;
    }
    labels.add(encoded);
  }
  final result = labels.join('.');
  if (result.length > 253 ||
      !RegExp(
        r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*$',
      ).hasMatch(result)) {
    return null;
  }
  return result;
}

const int _base = 36;
const int _tMin = 1;
const int _tMax = 26;
const int _skew = 38;
const int _damp = 700;
const int _initialBias = 72;
const int _initialN = 128;

int _adapt(int delta, int points, {required bool first}) {
  var value = first ? delta ~/ _damp : delta ~/ 2;
  value += value ~/ points;
  var k = 0;
  while (value > ((_base - _tMin) * _tMax) ~/ 2) {
    value ~/= _base - _tMin;
    k += _base;
  }
  return k + ((_base - _tMin + 1) * value) ~/ (value + _skew);
}

String _digit(int value) =>
    String.fromCharCode(value < 26 ? 97 + value : 22 + value);

String? _encodeLabel(List<int> codePoints) {
  var n = _initialN;
  var delta = 0;
  var bias = _initialBias;
  final output = <int>[...codePoints.where((c) => c < 128)];
  final basic = output.length;
  var handled = basic;
  if (basic > 0) {
    output.add(0x2d);
  }
  while (handled < codePoints.length) {
    var next = 0x7fffffff;
    for (final c in codePoints) {
      if (c >= n && c < next) {
        next = c;
      }
    }
    delta += (next - n) * (handled + 1);
    n = next;
    for (final c in codePoints) {
      if (c < n) {
        delta++;
      }
      if (c == n) {
        var q = delta;
        for (var k = _base; ; k += _base) {
          final t = k <= bias
              ? _tMin
              : k >= bias + _tMax
              ? _tMax
              : k - bias;
          if (q < t) {
            break;
          }
          output.add(_digit(t + (q - t) % (_base - t)).codeUnitAt(0));
          q = (q - t) ~/ (_base - t);
        }
        output.add(_digit(q).codeUnitAt(0));
        bias = _adapt(delta, handled + 1, first: handled == basic);
        delta = 0;
        handled++;
      }
    }
    delta++;
    n++;
  }
  return 'xn--${String.fromCharCodes(output)}';
}
