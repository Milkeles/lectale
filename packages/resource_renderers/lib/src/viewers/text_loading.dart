import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/viewers/file_card.dart';
import 'package:resource_renderers/src/widgets/load_once.dart';

/// The most a text, code or Markdown file may weigh to be shown in the app:
/// 512 KB, judged by its length header (reader.md §5). Larger files get a
/// card with Download.
const int inlineTextLimit = 512 * 1024;

/// Loads the text of [resource] through its `href` and hands it to
/// [builder].
///
/// A file over [inlineTextLimit] becomes a file card that says so. Any
/// other failure shows the environment's error view in place, with Try
/// again.
class TextResource extends StatelessWidget {
  /// Creates the loader.
  const TextResource({
    required this.resource,
    required this.environment,
    required this.builder,
    super.key,
  });

  /// The text file.
  final OutlineResource resource;

  /// Reads the file.
  final ResourceEnvironment environment;

  /// Builds the viewer from the decoded text.
  final Widget Function(BuildContext context, String text) builder;

  @override
  Widget build(BuildContext context) {
    final href = resource.href;
    if (href == null) {
      return const NoFileNote();
    }
    return LoadOnce<String>(
      environment: environment,
      load: () async => utf8.decode(
        await environment.host.read(ApiHref(href), maxBytes: inlineTextLimit),
        // A stray byte shows as a replacement character rather than hiding
        // the whole file.
        allowMalformed: true,
      ),
      onError: (context, error) => error is ResourceTooLarge
          ? FileCard(
              resource: resource,
              environment: environment,
              reason: ViewerCopy.tooLarge,
            )
          : null,
      builder: builder,
    );
  }
}
