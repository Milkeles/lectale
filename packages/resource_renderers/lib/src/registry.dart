import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/repository_path.dart';
import 'package:resource_renderers/src/viewers/file_card.dart';
import 'package:resource_renderers/src/viewers/folder_viewer.dart';
import 'package:resource_renderers/src/viewers/image_viewer.dart';
import 'package:resource_renderers/src/viewers/text_viewers.dart';

/// Draws one resource.
typedef ResourceViewBuilder = Widget Function(
  BuildContext context,
  OutlineResource resource,
  ResourceEnvironment environment,
);

/// How one kind of resource is shown.
@immutable
class ResourceRenderer {
  /// Creates a renderer. Set [barDownload] when the viewer leaves the file
  /// without a Download of its own, so the screen's Download bar applies.
  const ResourceRenderer({required this.build, this.barDownload = false});

  /// Builds the viewer, card or list.
  final ResourceViewBuilder build;

  /// Whether the screen offers a Download in the header for this kind.
  /// Cards and folder rows carry their own, so they leave it false.
  final bool barDownload;
}

/// Maps each [OutlineResourceKind] to the renderer that shows it.
///
/// A new kind is a new entry here and a new renderer; no screen changes
/// (AGENTS.md, patterns). A kind with no entry gets the file card with
/// Download, so no resource is ever a dead end.
class ResourceRendererRegistry {
  /// Creates a registry from [renderers], with [fallback] for other kinds.
  const ResourceRendererRegistry(this.renderers, {required this.fallback});

  /// The M2 set: Markdown, text, code, images and folders have viewers; PDF,
  /// notebook, audio, video and plain files show the download card.
  /// `notebook` stays a card until the notebook viewer lands.
  factory ResourceRendererRegistry.standard() => ResourceRendererRegistry({
    OutlineResourceKind.markdown: ResourceRenderer(
      barDownload: true,
      build: (context, resource, env) =>
          MarkdownViewer(resource: resource, environment: env),
    ),
    OutlineResourceKind.text: ResourceRenderer(
      barDownload: true,
      build: (context, resource, env) =>
          TextViewer(resource: resource, environment: env),
    ),
    OutlineResourceKind.code: ResourceRenderer(
      barDownload: true,
      build: (context, resource, env) =>
          CodeViewer(resource: resource, environment: env),
    ),
    OutlineResourceKind.image: ResourceRenderer(
      barDownload: true,
      build: (context, resource, env) =>
          ImageViewer(resource: resource, environment: env),
    ),
    OutlineResourceKind.folder: ResourceRenderer(
      build: (context, resource, env) =>
          FolderViewer(resource: resource, environment: env),
    ),
    OutlineResourceKind.pdf: _card(ViewerCopy.noViewer('PDF files')),
    OutlineResourceKind.notebook: _card(ViewerCopy.noViewer('notebooks')),
    OutlineResourceKind.audio: _card(ViewerCopy.noViewer('audio files')),
    OutlineResourceKind.video: ResourceRenderer(
      build: (context, resource, env) =>
          _linkOrCard(resource, env, ViewerCopy.noViewer('video files')),
    ),
    OutlineResourceKind.external2: ResourceRenderer(
      build: (context, resource, env) =>
          _linkOrCard(resource, env, ViewerCopy.unknownType),
    ),
  }, fallback: _card(ViewerCopy.unknownType));

  /// The renderer of each kind.
  final Map<OutlineResourceKind, ResourceRenderer> renderers;

  /// Used for kinds without an entry, such as `file`.
  final ResourceRenderer fallback;

  /// The renderer for [resource], after resolving `auto` from the file
  /// extension and media type.
  ResourceRenderer rendererFor(OutlineResource resource) =>
      renderers[resolveKind(resource)] ?? fallback;

  /// Draws [resource].
  Widget build(
    BuildContext context,
    OutlineResource resource,
    ResourceEnvironment environment,
  ) => rendererFor(resource).build(context, resource, environment);

  /// Whether the Download bar applies to [resource]: its kind has a viewer
  /// without a download of its own, and the manifest hasn't turned downloads
  /// off for it or for the course (reader.md §5).
  bool offersBarDownload(
    OutlineResource resource, {
    bool courseShowsDownloads = true,
  }) =>
      rendererFor(resource).barDownload &&
      resource.href != null &&
      resource.download != false &&
      courseShowsDownloads;
}

ResourceRenderer _card(String reason) => ResourceRenderer(
  build: (context, resource, env) => resource.href == null
      ? const NoFileNote()
      : FileCard(resource: resource, environment: env, reason: reason),
);

Widget _linkOrCard(
  OutlineResource resource,
  ResourceEnvironment env,
  String reason,
) {
  // A video of YouTube or Vimeo opens its own page; nothing loads before the
  // tap (D14). Only an http(s) address with a host is ever offered.
  final embed = resource.embedUrl;
  final provider = resource.provider;
  final raw = embed ?? resource.url;
  final target = raw == null ? null : classifyLink(raw);
  if (target is ExternalLink) {
    // A provider's name is only claimed for that provider's own hosts; a
    // manifest can't make another site read "Watch on YouTube".
    final host = target.uri.host;
    final action = switch (provider) {
      OutlineResourceProvider.youtube when _isHostOf(host, _youTubeHosts) =>
        ViewerCopy.watchOnYouTube,
      OutlineResourceProvider.vimeo when _isHostOf(host, _vimeoHosts) =>
        ViewerCopy.watchOnVimeo,
      _ => ViewerCopy.openLink,
    };
    return LinkCard(
      title: resource.title,
      uri: target.uri,
      action: action,
      environment: env,
    );
  }
  return resource.href == null
      ? const NoFileNote()
      : FileCard(resource: resource, environment: env, reason: reason);
}

const Set<String> _youTubeHosts = {
  'youtube.com',
  'youtube-nocookie.com',
  'youtu.be',
};
const Set<String> _vimeoHosts = {'vimeo.com'};

/// Whether [host] is one of [domains] or a subdomain of one.
bool _isHostOf(String host, Set<String> domains) =>
    domains.any((domain) => host == domain || host.endsWith('.$domain'));

const Map<String, OutlineResourceKind> _kindsByExtension = {
  'md': OutlineResourceKind.markdown,
  'markdown': OutlineResourceKind.markdown,
  'txt': OutlineResourceKind.text,
  'text': OutlineResourceKind.text,
  'csv': OutlineResourceKind.text,
  'tsv': OutlineResourceKind.text,
  'json': OutlineResourceKind.text,
  'yaml': OutlineResourceKind.text,
  'yml': OutlineResourceKind.text,
  'log': OutlineResourceKind.text,
  'png': OutlineResourceKind.image,
  'jpg': OutlineResourceKind.image,
  'jpeg': OutlineResourceKind.image,
  'gif': OutlineResourceKind.image,
  'webp': OutlineResourceKind.image,
  'pdf': OutlineResourceKind.pdf,
  'ipynb': OutlineResourceKind.notebook,
  'mp3': OutlineResourceKind.audio,
  'wav': OutlineResourceKind.audio,
  'ogg': OutlineResourceKind.audio,
  'm4a': OutlineResourceKind.audio,
  'mp4': OutlineResourceKind.video,
  'webm': OutlineResourceKind.video,
  'mov': OutlineResourceKind.video,
};

bool _isSvg(OutlineResource resource) =>
    (resource.fileExtension ?? '').toLowerCase() == 'svg' ||
    (resource.mediaType ?? '').toLowerCase().startsWith('image/svg') ||
    (resource.path ?? '').toLowerCase().endsWith('.svg');

/// The kind to draw: [OutlineResource.kind], with `auto` resolved from the
/// file extension, then from the media type (reader.md §5). Source files
/// whose extension is in [codeLanguages] resolve to `code`. Anything else
/// resolves to `file`, which shows the card.
OutlineResourceKind resolveKind(OutlineResource resource) {
  if (resource.kind == OutlineResourceKind.image && _isSvg(resource)) {
    // SVG can carry script, so an explicit image that is SVG is a plain file.
    return OutlineResourceKind.file;
  }
  if (resource.kind != OutlineResourceKind.auto) {
    return resource.kind;
  }
  final extension = (resource.fileExtension ?? '').toLowerCase();
  final byExtension = _kindsByExtension[extension];
  if (byExtension != null) {
    return byExtension;
  }
  if (codeLanguages.containsKey(extension)) {
    return OutlineResourceKind.code;
  }
  final media = (resource.mediaType ?? '').toLowerCase();
  if (media.startsWith('image/') && media != 'image/svg+xml') {
    return OutlineResourceKind.image;
  }
  if (media.startsWith('text/markdown')) {
    return OutlineResourceKind.markdown;
  }
  if (media.startsWith('text/')) {
    return OutlineResourceKind.text;
  }
  if (media == 'application/pdf') {
    return OutlineResourceKind.pdf;
  }
  return OutlineResourceKind.file;
}
