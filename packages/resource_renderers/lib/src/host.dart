import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// Something in the pinned repository that a viewer wants to read or open.
@immutable
sealed class ResourceTarget {
  const ResourceTarget();
}

/// An address the API handed out: an `OutlineResource.href` or the `href` of
/// a folder entry. Used exactly as returned (ADR-0008, ADR-0011).
final class ApiHref extends ResourceTarget {
  /// Creates the target.
  const ApiHref(this.href);

  /// The same-origin address, starting `/api/preview/`.
  final String href;

  @override
  bool operator ==(Object other) => other is ApiHref && other.href == href;

  @override
  int get hashCode => href.hashCode;
}

/// A file named by a canonical repository path, such as a Markdown image.
/// The host builds the files-route address.
final class RepositoryFile extends ResourceTarget {
  /// Creates the target. [path] must come from `resolveRepositoryPath`.
  const RepositoryFile(this.path);

  /// The canonical repository path.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is RepositoryFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Thrown by [ResourceHost.read] when a file is longer than the limit the
/// viewer asked for. It is never a transport failure.
class ResourceTooLarge implements Exception {
  /// Creates the signal.
  const ResourceTooLarge();
}

/// What the viewers need from the app: reading bytes of the pinned course
/// and leaving the app. Viewers never make a request of their own, so
/// nothing but the pinned repository can be reached (V4-SEC-03, threat 5.6).
abstract interface class ResourceHost {
  /// Reads the bytes behind [target].
  ///
  /// With [maxBytes] set, throws [ResourceTooLarge] when the file is longer,
  /// judged by its length header where the server sends one. Any other
  /// failure is thrown as the app's own error type, which the viewer hands
  /// to [ResourceErrorBuilder].
  Future<Uint8List> read(ResourceTarget target, {int? maxBytes});

  /// Lists the entries of the folder resource at [href].
  Future<PreviewFolder> listFolder(String href);

  /// The address that opens [target] in the browser, where the server shows
  /// or downloads it by its own safe-type rules.
  Uri addressOf(ResourceTarget target);

  /// Opens [uri] outside the app. Returns false when nothing could open it.
  Future<bool> open(Uri uri);
}

/// Draws a load failure inside the region that failed. The app owns the
/// wording and decides whether Try again is offered, by calling [retry]
/// from a button only when trying again can help (J5 error table).
typedef ResourceErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  VoidCallback retry,
);
