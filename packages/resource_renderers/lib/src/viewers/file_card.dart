import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/widgets/download_button.dart';
import 'package:resource_renderers/src/widgets/meta_style.dart';

/// The file name a resource is known by: the last segment of its repository
/// path, else its title.
String resourceFileName(OutlineResource resource) {
  final path = resource.path;
  return path == null || path.isEmpty ? resource.title : path.split('/').last;
}

/// "PDF", "Notebook", "Audio": the kind as a learner reads it.
String kindLabel(OutlineResource resource) {
  final extension = resource.fileExtension;
  return switch (resource.kind) {
    OutlineResourceKind.pdf => 'PDF',
    OutlineResourceKind.notebook => 'Notebook',
    OutlineResourceKind.audio => 'Audio',
    OutlineResourceKind.video => 'Video',
    OutlineResourceKind.image => 'Image',
    OutlineResourceKind.markdown => 'Markdown',
    OutlineResourceKind.text => 'Text',
    OutlineResourceKind.code => 'Code',
    OutlineResourceKind.folder => 'Folder',
    _ =>
      extension == null || extension.isEmpty
          ? 'File'
          : '${extension.toUpperCase()} file',
  };
}

/// "{kind}, {size}", the size only when it is known.
String kindAndSize(OutlineResource resource) {
  final size = resource.sizeBytes;
  return size == null
      ? kindLabel(resource)
      : '${kindLabel(resource)}, ${formatBytes(size)}';
}

/// The card for a file Lectale can't show: its name, its type and size, why
/// it isn't shown, and a Download that works (reader.md §5, File card).
class FileCard extends StatelessWidget {
  /// Creates the card for [resource], explaining itself with [reason].
  const FileCard({
    required this.resource,
    required this.environment,
    required this.reason,
    super.key,
  });

  /// The file.
  final OutlineResource resource;

  /// Opens the download.
  final ResourceEnvironment environment;

  /// Why the file is not shown.
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final name = resourceFileName(resource);
    final href = resource.href;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: style.space(0.5),
      children: [
        Text(
          name,
          style: theme.typography.code.copyWith(
            fontSize: 16,
            fontWeight: theme.typography.semibold,
            color: theme.colors.foreground,
          ),
        ),
        Text(kindAndSize(resource), style: metaTextStyle(theme)),
        Text(
          reason,
          style: metaTextStyle(theme).copyWith(color: theme.colors.foreground),
        ),
      ],
    );
    // A browser shows a PDF in its own viewer, so the button says Open.
    final action = href == null
        ? null
        : DownloadButton(
            host: environment.host,
            target: ApiHref(href),
            fileName: name,
            label: resource.kind == OutlineResourceKind.pdf
                ? ViewerCopy.downloadPdf
                : ViewerCopy.download,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.card,
        borderRadius: BorderRadius.circular(style.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(style.space(4)),
        // The action sits beside the details when there is room, and below
        // them on a phone.
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 480
              ? Row(
                  spacing: style.space(4),
                  children: [
                    Expanded(child: details),
                    ?action,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: style.space(3),
                  children: [details, ?action],
                ),
        ),
      ),
    );
  }
}

/// The card for a resource that lives on another site: its title, its host
/// and one button that opens the browser. Nothing loads before the tap.
class LinkCard extends StatelessWidget {
  /// Creates the card for [uri], opened by a button labelled [action].
  const LinkCard({
    required this.title,
    required this.uri,
    required this.action,
    required this.environment,
    super.key,
  });

  /// The resource's title.
  final String title;

  /// Where the button goes.
  final Uri uri;

  /// The button's label: "Open link", "Watch on YouTube", "Watch on Vimeo".
  final String action;

  /// Opens the address.
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) => DcCard(
    title: Text(title),
    description: Text(ViewerCopy.opensIn(uri.host)),
    footer: DcButton(
      variant: DcButtonVariant.outline,
      onPressed: () => environment.host.open(uri),
      child: Text(action),
    ),
  );
}

/// The note for a resource with nothing to open.
class NoFileNote extends StatelessWidget {
  /// Creates the note.
  const NoFileNote({super.key});

  @override
  Widget build(BuildContext context) =>
      Text(ViewerCopy.noFile, style: DcTheme.of(context).typography.body);
}
