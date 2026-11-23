import 'dart:typed_data';

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/repository_path.dart';
import 'package:resource_renderers/src/widgets/image_header.dart';
import 'package:resource_renderers/src/widgets/load_once.dart';
import 'package:resource_renderers/src/widgets/sized_image.dart';

/// An image named in course Markdown.
///
/// Only a raster image inside the pinned repository loads, through the
/// host's files route. Another host's image, an SVG, a `data:` address or a
/// path outside the repository is never requested: it shows the box that
/// says so (V4-SEC-03, threat 5.6). A missing or undecodable file shows the
/// same box, never a broken-image glyph.
class ContentImage extends StatelessWidget {
  /// Creates the image for [target], with the Markdown's [alt] text.
  const ContentImage({
    required this.target,
    required this.alt,
    required this.environment,
    super.key,
  });

  /// What [classifyImage] decided.
  final ImageTarget target;

  /// The alternative text; empty when the author gave none.
  final String alt;

  /// Reads the file and supplies the styles.
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return switch (target) {
      RefusedImage(:final shown) => ImageFailureBox(alt: alt, fileName: shown),
      RepositoryImage(:final path) => LayoutBuilder(
        builder: (context, constraints) => LoadOnce<Uint8List>(
          environment: environment,
          load: () => environment.host.read(
            RepositoryFile(path),
            maxBytes: maxImageBytes,
          ),
          placeholder: const DcSkeleton(height: 120),
          onError: (context, error) =>
              ImageFailureBox(alt: alt, fileName: path.split('/').last),
          builder: (context, bytes) => SizedImage(
            bytes: bytes,
            maxWidth: constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 960,
            semanticLabel: alt.isEmpty ? null : alt,
            loading: (context) => const DcSkeleton(height: 120),
            failed: (context, error) =>
                ImageFailureBox(alt: alt, fileName: path.split('/').last),
          ),
        ),
      ),
    };
  }
}

/// The box shown in place of an image that can't be drawn: the author's
/// description, the file name and why.
class ImageFailureBox extends StatelessWidget {
  /// Creates the box.
  const ImageFailureBox({required this.alt, required this.fileName, super.key});

  /// The author's description; empty when there is none.
  final String alt;

  /// The file name, or the host for another host's image.
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final small = theme.typography.small.copyWith(
      color: theme.colors.mutedForeground,
    );
    final description = alt.isEmpty
        ? ViewerCopy.imageWithoutDescription(fileName)
        : '$alt, $fileName';
    return Semantics(
      container: true,
      image: true,
      label: '$description. ${ViewerCopy.imageFailed}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: BorderRadius.circular(style.radiusMedium),
        ),
        child: Padding(
          padding: EdgeInsets.all(style.space(3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: style.space(1),
            children: [
              Text(
                ViewerCopy.imageFailed,
                style: theme.typography.label.copyWith(
                  color: theme.colors.foreground,
                ),
              ),
              Text(description, style: small),
            ],
          ),
        ),
      ),
    );
  }
}
