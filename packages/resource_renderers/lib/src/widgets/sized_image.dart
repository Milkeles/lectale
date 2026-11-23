import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/widgets/image_header.dart';

/// The pixel size of an image the app may decode, read from its header
/// before anything is decoded.
///
/// Only PNG, GIF, JPEG and WebP are drawn: bytes with another signature, such
/// as SVG behind a `.png` name, throw [ImageNotRaster]. An image over
/// [maxImageSide] on a side or [maxImagePixels] in total throws
/// [ImageTooLarge]; a small file can claim a huge canvas, and `cacheWidth`
/// does not stop the engine decoding the full frame first (V4-SEC-03,
/// threat 5.6). Every path to `Image.memory` goes through here.
Future<Size> naturalImageSize(Uint8List bytes) async {
  final size = imageSizeFromHeader(bytes);
  if (size == null) {
    throw const ImageNotRaster();
  }
  if (size.width > maxImageSide ||
      size.height > maxImageSide ||
      size.width * size.height > maxImagePixels) {
    throw ImageTooLarge(size);
  }
  return size;
}

/// An image drawn at the size it is shown, and decoded at that size times the
/// device pixel ratio, so a large photograph is never decoded into a small
/// box (`cacheWidth`; `docs/ux/screens/course.md` §10).
///
/// It shows the image at its own size up to [maxWidth], then multiplies by
/// [zoom]. [failed] is drawn, with the reason, when the bytes are not a
/// raster image, claim too many pixels, or can't be decoded; [loading] while
/// the header is read.
class SizedImage extends StatefulWidget {
  /// Creates the image.
  const SizedImage({
    required this.bytes,
    required this.maxWidth,
    required this.failed,
    required this.loading,
    this.zoom = 1,
    this.semanticLabel,
    super.key,
  });

  /// The encoded image.
  final Uint8List bytes;

  /// The widest the image may be at zoom 1, in dp.
  final double maxWidth;

  /// The zoom factor, 1 for the fitted size.
  final double zoom;

  /// What a screen reader says for the image; null marks it decorative.
  final String? semanticLabel;

  /// Drawn when the image can't be shown; the error is [ImageNotRaster],
  /// [ImageTooLarge] or a decode failure.
  final Widget Function(BuildContext context, Object error) failed;

  /// Drawn while the image's size is being read.
  final WidgetBuilder loading;

  @override
  State<SizedImage> createState() => _SizedImageState();
}

class _SizedImageState extends State<SizedImage> {
  late Future<Size> _size = naturalImageSize(widget.bytes);

  @override
  void didUpdateWidget(SizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _size = naturalImageSize(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return FutureBuilder<Size>(
      future: _size,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.failed(context, snapshot.error!);
        }
        final natural = snapshot.data;
        if (natural == null || natural.isEmpty) {
          return widget.loading(context);
        }
        final fitted = natural.width < widget.maxWidth
            ? natural.width
            : widget.maxWidth;
        final width = fitted * widget.zoom;
        final height = width * natural.height / natural.width;
        return Semantics(
          image: true,
          label: widget.semanticLabel,
          excludeSemantics: true,
          child: Image.memory(
            widget.bytes,
            width: width,
            height: height,
            fit: BoxFit.fill,
            // Decoded at the shown size; the engine never decodes above the
            // image's own size.
            cacheWidth: (width * ratio).ceil(),
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                widget.failed(context, error),
          ),
        );
      },
    );
  }
}
