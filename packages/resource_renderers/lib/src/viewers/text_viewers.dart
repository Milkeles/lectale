import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/markdown/markdown_view.dart';
import 'package:resource_renderers/src/viewers/file_card.dart';
import 'package:resource_renderers/src/viewers/text_loading.dart';
import 'package:resource_renderers/src/widgets/code_surface.dart';
import 'package:resource_renderers/src/widgets/meta_style.dart';

/// The viewer of a Markdown file. Relative links and images resolve against
/// the file's own `path`.
class MarkdownViewer extends StatelessWidget {
  /// Creates the viewer for [resource].
  const MarkdownViewer({
    required this.resource,
    required this.environment,
    super.key,
  });

  /// The Markdown file.
  final OutlineResource resource;

  /// Reads the file and supplies the styles.
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) => TextResource(
    resource: resource,
    environment: environment,
    builder: (context, text) => MarkdownView(
      source: text,
      environment: environment,
      basePath: resource.path ?? '',
    ),
  );
}

/// Extensions of data files, shown in Plex Mono without wrapping.
const Set<String> dataExtensions = {
  'csv',
  'tsv',
  'json',
  'yaml',
  'yml',
  'log',
  'xml',
  'toml',
  'ini',
};

/// The viewer of a plain-text file: prose wraps in the reading face, while
/// data files (CSV, TSV, JSON, YAML, logs) keep their columns in Plex Mono
/// and scroll sideways (reader.md §5, S10).
class TextViewer extends StatelessWidget {
  /// Creates the viewer for [resource].
  const TextViewer({
    required this.resource,
    required this.environment,
    super.key,
  });

  /// The text file.
  final OutlineResource resource;

  /// Reads the file and supplies the styles.
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final extension = (resource.fileExtension ?? '').toLowerCase();
    final isData = dataExtensions.contains(extension);
    return TextResource(
      resource: resource,
      environment: environment,
      builder: (context, text) => isData
          ? CodeSurface(
              code: text.trimRight(),
              semanticLabel: 'Data, ${resourceFileName(resource)}',
            )
          : Text(text, style: environment.styles.reading),
    );
  }
}

/// Language names for the code viewer's label, by file extension.
const Map<String, String> codeLanguages = {
  'py': 'Python',
  'js': 'JavaScript',
  'mjs': 'JavaScript',
  'ts': 'TypeScript',
  'tsx': 'TypeScript',
  'jsx': 'JavaScript',
  'dart': 'Dart',
  'java': 'Java',
  'kt': 'Kotlin',
  'c': 'C',
  'h': 'C',
  'cpp': 'C++',
  'cc': 'C++',
  'cs': 'C#',
  'go': 'Go',
  'rs': 'Rust',
  'rb': 'Ruby',
  'php': 'PHP',
  'swift': 'Swift',
  'sh': 'Shell',
  'bash': 'Shell',
  'sql': 'SQL',
  'r': 'R',
  'jl': 'Julia',
  'm': 'MATLAB',
  'html': 'HTML',
  'css': 'CSS',
  'tex': 'LaTeX',
  'hs': 'Haskell',
  'lua': 'Lua',
};

/// The viewer of a source file: line numbers, the language, Copy, and
/// sideways scrolling in place of wrapping. The text is plain; syntax colors
/// are not drawn in this version.
class CodeViewer extends StatefulWidget {
  /// Creates the viewer for [resource].
  const CodeViewer({
    required this.resource,
    required this.environment,
    super.key,
  });

  /// The source file.
  final OutlineResource resource;

  /// Reads the file and supplies the styles.
  final ResourceEnvironment environment;

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  bool _copied = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final extension = (widget.resource.fileExtension ?? '').toLowerCase();
    final language =
        codeLanguages[extension] ?? (extension.isEmpty ? '' : extension);
    return TextResource(
      resource: widget.resource,
      environment: widget.environment,
      builder: (context, text) {
        final code = text.trimRight();
        // The language and Copy sit in a slim header attached to the code.
        final header = Padding(
          padding: EdgeInsetsDirectional.only(
            start: theme.style.space(3),
            end: theme.style.space(1),
            top: theme.style.space(1),
          ),
          child: Row(
            children: [
              Expanded(child: Text(language, style: metaTextStyle(theme))),
              // Says "Copied" once, politely, after the tap.
              if (_copied)
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(ViewerCopy.copied, style: metaTextStyle(theme)),
                ),
              DcButton(
                variant: DcButtonVariant.ghost,
                onPressed: () => _copy(code),
                child: const Text(ViewerCopy.copy),
              ),
            ],
          ),
        );
        return CodeSurface(
          code: code,
          lineNumbers: true,
          header: header,
          semanticLabel: language.isEmpty ? 'Code' : 'Code, $language',
        );
      },
    );
  }
}
