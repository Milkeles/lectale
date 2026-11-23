import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/viewers/file_card.dart';
import 'package:resource_renderers/src/widgets/download_button.dart';
import 'package:resource_renderers/src/widgets/load_once.dart';
import 'package:resource_renderers/src/widgets/meta_style.dart';

/// The most entries a folder resource lists unless its manifest says more.
const int defaultFolderEntries = 100;

/// The list of a folder resource's entries, in the order the API returns
/// them. `name` is the path inside the folder, so a recursive listing
/// indents by its `/` segments. Directories say "Folder" and have no
/// action; files with an `href` have their own Download (reader.md §5).
class FolderViewer extends StatelessWidget {
  /// Creates the viewer for [resource].
  const FolderViewer({
    required this.resource,
    required this.environment,
    super.key,
  });

  /// The folder resource; its `href` is the folders route.
  final OutlineResource resource;

  /// Lists the folder.
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final href = resource.href;
    if (href == null) {
      return const NoFileNote();
    }
    return LoadOnce<PreviewFolder>(
      environment: environment,
      load: () => environment.host.listFolder(href),
      builder: (context, folder) => _FolderList(
        entries: folder.entries,
        cap: resource.maxEntries ?? defaultFolderEntries,
        environment: environment,
      ),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({
    required this.entries,
    required this.cap,
    required this.environment,
  });

  final List<PreviewFolderEntry> entries;
  final int cap;
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    if (entries.isEmpty) {
      return Text(ViewerCopy.emptyFolder, style: theme.typography.body);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          role: SemanticsRole.list,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in entries)
                Semantics(
                  container: true,
                  role: SemanticsRole.listItem,
                  child: _FolderRow(entry: entry, environment: environment),
                ),
            ],
          ),
        ),
        if (entries.length >= cap)
          Padding(
            padding: EdgeInsets.only(top: style.space(3)),
            child: Text(
              ViewerCopy.folderCap(cap),
              style: theme.typography.small.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.entry, required this.environment});

  final PreviewFolderEntry entry;
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final segments = entry.name.split('/');
    final isDirectory = entry.type == PreviewFolderEntryType.directory;
    final href = entry.href;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.controlHeights.medium),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: style.space(4) * (segments.length - 1),
          top: style.space(1),
          bottom: style.space(1),
        ),
        child: Row(
          spacing: style.space(3),
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segments.last,
                    style: theme.typography.code.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                  Text(
                    isDirectory ? ViewerCopy.folder : formatBytes(entry.size),
                    style: metaTextStyle(theme),
                  ),
                ],
              ),
            ),
            if (!isDirectory && href != null)
              DownloadButton(
                host: environment.host,
                target: ApiHref(href),
                fileName: segments.last,
              ),
          ],
        ),
      ),
    );
  }
}
