import 'package:flutter/foundation.dart';
import 'package:resource_renderers/src/punycode.dart';

/// One segment of a path the files route accepts: letters, digits, `_`, `-`
/// and inner dots, or `.well-known` (`spec/errata/openapi.yaml`, files route).
final RegExp _segmentPattern = RegExp(
  r'^(?:\.well-known|[A-Za-z0-9_-](?:[A-Za-z0-9_.-]*[A-Za-z0-9_-])?)$',
);

/// The longest path the files route accepts.
const int maxRepositoryPathLength = 500;

final RegExp _schemeAuthority = RegExp(
  r'^([A-Za-z][A-Za-z0-9+.\-]*)://([^/?#]*)(.*)$',
  dotAll: true,
);

/// The ASCII host and the `:port` of an authority such as `host:8080`, or
/// null when it has credentials, an IP literal or a host that is not a plain
/// name (see [asciiHost]).
({String host, String port})? _authority(String authority) {
  if (authority.contains('@')) {
    return null;
  }
  final match = RegExp(r'^(.*?)(:[0-9]{1,5})?$').firstMatch(authority)!;
  // Markdown percent-encodes non-ASCII destinations; undo that so the host
  // can be shown in ASCII form. What is left must still be a plain name.
  final rawHost = match.group(1)!;
  final decoded = rawHost.contains('%') ? _decode(rawHost) : rawHost;
  final host = decoded == null ? null : asciiHost(decoded);
  return host == null ? null : (host: host, port: match.group(2) ?? '');
}

/// Percent-decodes [text]; null when the escapes are malformed.
String? _decode(String text) {
  try {
    return Uri.decodeComponent(text);
    // A truncated escape is an ArgumentError; bytes that are not UTF-8, such
    // as `%FF`, are a FormatException. Both mean "not a path".
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}

/// Resolves [reference], a relative path found in a document, against the
/// folder of [basePath], the document's own repository path.
///
/// Returns the canonical repository path (`docs/img/figure.png`), or null
/// when the reference can't name a file inside the repository: it leaves the
/// root with `..`, holds a backslash, a control character or an encoded
/// slash, or a segment the files route would refuse (SEC-012, SEC-020).
///
/// A reference that starts with `/` is taken from the repository root, as
/// GitHub does. A `?query` or `#fragment` is dropped. `./` and `../` collapse.
String? resolveRepositoryPath(String reference, {String basePath = ''}) {
  var text = reference.trim();
  final cut = text.indexOf(RegExp('[?#]'));
  if (cut >= 0) {
    text = text.substring(0, cut);
  }
  if (text.isEmpty || text.contains(r'\')) {
    return null;
  }
  // An encoded slash would let one segment hide a separator.
  if (RegExp('%(2f|5c)', caseSensitive: false).hasMatch(text)) {
    return null;
  }
  final decoded = _decode(text);
  if (decoded == null || decoded.contains(RegExp(r'[\x00-\x1f\x7f\\]'))) {
    return null;
  }

  final stack = <String>[];
  if (!decoded.startsWith('/')) {
    final folder = basePath.split('/')..removeLast();
    stack.addAll(folder.where((part) => part.isNotEmpty));
  }
  for (final part in decoded.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (stack.isEmpty) {
        return null;
      }
      stack.removeLast();
      continue;
    }
    stack.add(part);
  }
  if (stack.isEmpty || !stack.every(_segmentPattern.hasMatch)) {
    return null;
  }
  final path = stack.join('/');
  return path.length > maxRepositoryPathLength ? null : path;
}

/// What a link in course Markdown points to, decided before anything is
/// followed (`docs/ux/screens/course.md` §5, Links and images).
@immutable
sealed class LinkTarget {
  const LinkTarget();
}

/// `#heading`: a place in the same document.
final class AnchorLink extends LinkTarget {
  /// Creates the target for the heading [id].
  const AnchorLink(this.id);

  /// The heading's id, decoded, without the `#`.
  final String id;
}

/// A file in the pinned repository, opened through the files route.
final class RepositoryLink extends LinkTarget {
  /// Creates the target for the canonical [path].
  const RepositoryLink(this.path);

  /// The canonical repository path.
  final String path;
}

/// An `http` or `https` address outside Lectale, opened in the browser.
final class ExternalLink extends LinkTarget {
  /// Creates the target for [uri].
  const ExternalLink(this.uri);

  /// The address; its host is shown to the learner.
  final Uri uri;
}

/// A link that is not followed: it shows as plain text with [shown] after it.
final class RefusedLink extends LinkTarget {
  /// Creates the refusal, remembering the text to show.
  const RefusedLink(this.shown);

  /// The target as written, for display only.
  final String shown;
}

/// Decides what [href] may do.
///
/// Anchors stay in the document. Relative paths resolve inside the
/// repository or are refused. Only `https` with a plain host name and no
/// credentials leaves the app (SEMANTIC_VALIDATION: "Only HTTPS URLs"); the
/// host is the ASCII (Punycode) form, which is also what is shown. An `http:`
/// link is refused and shows its host. Every other scheme, including
/// `javascript:`, `data:`, `file:`, `intent:` and `mailto:`, and
/// scheme-less `//host` addresses, is refused.
LinkTarget classifyLink(String? href, {String basePath = ''}) {
  final text = (href ?? '').trim();
  if (text.isEmpty) {
    return const RefusedLink('');
  }
  if (text.startsWith('#')) {
    final id = _decode(text.substring(1));
    return id == null || id.isEmpty ? RefusedLink(text) : AnchorLink(id);
  }
  final hierarchical = _schemeAuthority.firstMatch(text);
  if (hierarchical != null) {
    final scheme = hierarchical.group(1)!.toLowerCase();
    final authority = _authority(hierarchical.group(2)!);
    if ((scheme != 'https' && scheme != 'http') || authority == null) {
      return RefusedLink(text);
    }
    // Plain `http` is text, with the host it would have contacted.
    if (scheme == 'http') {
      return RefusedLink(authority.host);
    }
    final rebuilt = Uri.tryParse(
      'https://${authority.host}${authority.port}${hierarchical.group(3)}',
    );
    return rebuilt == null ? RefusedLink(text) : ExternalLink(rebuilt);
  }
  final uri = Uri.tryParse(text);
  if (uri == null) {
    return RefusedLink(text);
  }
  if (uri.hasScheme) {
    // `javascript:`, `data:`, `mailto:`, `intent:` and the like.
    return RefusedLink(text);
  }
  if (uri.hasAuthority) {
    return RefusedLink(text);
  }
  final path = resolveRepositoryPath(text, basePath: basePath);
  return path == null ? RefusedLink(text) : RepositoryLink(path);
}

/// Why an image is not loaded.
enum ImageRefusal {
  /// Another host. Course images load only through the files route.
  otherHost,

  /// SVG can carry script, so it is never drawn (V4-SEC-03).
  svg,

  /// A `data:` address, or a type the app does not draw.
  unsupported,

  /// A path outside the repository or one the route would refuse.
  invalidPath,
}

/// What an image reference in course Markdown may load.
@immutable
sealed class ImageTarget {
  const ImageTarget();
}

/// A raster image in the pinned repository.
final class RepositoryImage extends ImageTarget {
  /// Creates the target for the canonical [path].
  const RepositoryImage(this.path);

  /// The canonical repository path.
  final String path;
}

/// An image that is not loaded.
final class RefusedImage extends ImageTarget {
  /// Creates the refusal.
  const RefusedImage(this.reason, this.shown);

  /// Why not.
  final ImageRefusal reason;

  /// The host for another host's image, else the file name; for display.
  final String shown;
}

/// The raster types the app draws from the repository.
const Set<String> drawableImageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
};

/// Decides whether the image at [src] may load, and from where.
ImageTarget classifyImage(String? src, {String basePath = ''}) {
  final text = (src ?? '').trim();
  if (text.isEmpty) {
    return RefusedImage(ImageRefusal.invalidPath, text);
  }
  final hierarchical = _schemeAuthority.firstMatch(text);
  if (hierarchical != null) {
    // The ASCII form of the host, so a look-alike name is visibly different.
    return RefusedImage(
      ImageRefusal.otherHost,
      _authority(hierarchical.group(2)!)?.host ?? text,
    );
  }
  if (text.startsWith('//')) {
    final authority = _authority(
      text.substring(2).split(RegExp('[/?#]')).first,
    );
    return RefusedImage(ImageRefusal.otherHost, authority?.host ?? text);
  }
  final uri = Uri.tryParse(text);
  if (uri == null) {
    return RefusedImage(ImageRefusal.invalidPath, text);
  }
  if (uri.hasScheme) {
    if (uri.scheme == 'data') {
      return const RefusedImage(ImageRefusal.unsupported, '');
    }
    return RefusedImage(ImageRefusal.otherHost, text);
  }
  final path = resolveRepositoryPath(text, basePath: basePath);
  if (path == null) {
    return RefusedImage(ImageRefusal.invalidPath, text);
  }
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (extension == 'svg') {
    return RefusedImage(ImageRefusal.svg, name);
  }
  if (!drawableImageExtensions.contains(extension)) {
    return RefusedImage(ImageRefusal.unsupported, name);
  }
  return RepositoryImage(path);
}
