import 'dart:typed_data';

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// The course cover: a 2:3 portrait, 112 by 168 dp, beside the title
/// (`spec/errata` O2). It collapses, gap included, when the course has no
/// cover or the cover can't be shown, so the title reads first.
///
/// The image comes through the files route only, at most [maxImageBytes], and
/// only when its header says a raster image within the size limits; AVIF,
/// SVG and anything over the limits collapse the slot. It is decoded at the
/// size it is shown times the device pixel ratio. The cover is decorative:
/// the title follows it.
class CourseCover extends StatelessWidget {
  /// Creates the cover for the manifest's [cover] path.
  const CourseCover({
    required this.cover,
    required this.environment,
    super.key,
  });

  /// `course.cover`, a repository path, or null.
  final String? cover;

  /// Reads the file.
  final ResourceEnvironment environment;

  /// The cover's width in dp.
  static const double width = 112;

  /// The cover's height in dp: 2:3.
  static const double height = 168;

  /// Whether [cover] names a file that may be drawn, so a slot is worth
  /// reserving while it loads.
  static bool isDrawable(String? cover) =>
      cover != null && classifyImage(cover) is RepositoryImage;

  @override
  Widget build(BuildContext context) {
    final target = cover == null ? null : classifyImage(cover);
    if (target is! RepositoryImage) {
      return const SizedBox.shrink();
    }
    final gap = DcTheme.of(context).style.space(5);
    Widget slot(Widget child) => ExcludeSemantics(
      child: Padding(
        padding: EdgeInsetsDirectional.only(end: gap),
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
    const skeleton = DcSkeleton(width: width, height: height);
    return LoadOnce<Uint8List>(
      environment: environment,
      load: () => environment.host.read(
        RepositoryFile(target.path),
        maxBytes: maxImageBytes,
      ),
      placeholder: slot(skeleton),
      // Any failure collapses the slot, gap included: the title still comes
      // first.
      onError: (context, error) => const _Collapsed(),
      builder: (context, bytes) => FutureBuilder<Object>(
        // The header is checked before the bytes reach the decoder.
        future: naturalImageSize(bytes),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Collapsed();
          }
          if (!snapshot.hasData) {
            return slot(skeleton);
          }
          return slot(
            ClipRRect(
              borderRadius: BorderRadius.circular(
                DcTheme.of(context).style.radiusSmall,
              ),
              child: Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                errorBuilder: (context, error, stack) => const _Collapsed(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shows nothing: the cover slot gives its room back.
class _Collapsed extends StatelessWidget {
  const _Collapsed();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
