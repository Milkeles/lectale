import 'dart:typed_data';

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/src/copy.dart';
import 'package:resource_renderers/src/environment.dart';
import 'package:resource_renderers/src/host.dart';
import 'package:resource_renderers/src/viewers/file_card.dart';
import 'package:resource_renderers/src/widgets/content_image.dart';
import 'package:resource_renderers/src/widgets/download_button.dart';
import 'package:resource_renderers/src/widgets/focus_scroll_region.dart';
import 'package:resource_renderers/src/widgets/image_header.dart';
import 'package:resource_renderers/src/widgets/load_once.dart';
import 'package:resource_renderers/src/widgets/sized_image.dart';

/// The zoom steps of the image viewer, as factors of the fitted size.
const List<double> imageZoomSteps = [1, 1.5, 2, 3, 4];

/// The viewer of an image resource: the picture at the size it is shown,
/// with Zoom in, Zoom out and Reset zoom (reader.md §5).
///
/// The image is decoded at its displayed size times the device pixel ratio,
/// so zooming re-decodes only what is shown. A picture that can't be decoded
/// shows the failure box with its own Download.
class ImageViewer extends StatefulWidget {
  /// Creates the viewer for [resource].
  const ImageViewer({
    required this.resource,
    required this.environment,
    super.key,
  });

  /// The image.
  final OutlineResource resource;

  /// Reads the file.
  final ResourceEnvironment environment;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  int _step = 0;

  // Keeps the image's measured size when zoom wraps it in a scroll region.
  final GlobalKey _imageKey = GlobalKey();

  void _zoom(int delta) => setState(
    () => _step = (_step + delta).clamp(0, imageZoomSteps.length - 1),
  );

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final href = resource.href;
    if (href == null) {
      return const NoFileNote();
    }
    final theme = DcTheme.of(context);
    final alt = [
      resource.title,
      ?resource.description,
    ].where((part) => part.isNotEmpty).join('. ');
    final name = resourceFileName(resource);

    Widget failure(BuildContext context, Object error) {
      // Bytes that are not a raster image, such as SVG behind a .png name,
      // get the file card; an image that is too big or won't decode gets the
      // box with its own Download.
      if (error is ImageNotRaster) {
        return FileCard(
          resource: resource,
          environment: widget.environment,
          reason: ViewerCopy.unknownType,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.style.space(3),
        children: [
          ImageFailureBox(alt: resource.title, fileName: name),
          DownloadButton(
            host: widget.environment.host,
            target: ApiHref(href),
            fileName: name,
          ),
        ],
      );
    }

    return LoadOnce<Uint8List>(
      environment: widget.environment,
      load: () =>
          widget.environment.host.read(ApiHref(href), maxBytes: maxImageBytes),
      placeholder: const DcSkeleton(height: 240),
      onError: (context, error) =>
          error is ResourceTooLarge ? failure(context, error) : null,
      builder: (context, bytes) => _Checked(
        bytes: bytes,
        failed: failure,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final zoom = imageZoomSteps[_step];
            final image = SizedImage(
              key: _imageKey,
              bytes: bytes,
              maxWidth: constraints.maxWidth,
              zoom: zoom,
              semanticLabel: alt.isEmpty ? null : alt,
              loading: (context) => const DcSkeleton(height: 240),
              failed: failure,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.style.space(3),
              children: [
                Row(
                  spacing: theme.style.space(1),
                  children: [
                    _ZoomButton(
                      label: ViewerCopy.zoomIn,
                      icon: LucideIcons.zoomIn,
                      onPressed: _step < imageZoomSteps.length - 1
                          ? () => _zoom(1)
                          : null,
                    ),
                    _ZoomButton(
                      label: ViewerCopy.zoomOut,
                      icon: LucideIcons.zoomOut,
                      onPressed: _step > 0 ? () => _zoom(-1) : null,
                    ),
                    _ZoomButton(
                      label: ViewerCopy.resetZoom,
                      icon: LucideIcons.rotateCcw,
                      onPressed: _step > 0
                          ? () => setState(() => _step = 0)
                          : null,
                    ),
                  ],
                ),
                if (zoom > 1)
                  FocusScrollRegion(semanticLabel: 'Zoomed image', child: image)
                else
                  image,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shows [child] once [bytes] pass the raster, size and pixel checks, else
/// [failed] with the reason, so no control is drawn for an image that
/// can't be shown.
class _Checked extends StatefulWidget {
  const _Checked({
    required this.bytes,
    required this.failed,
    required this.child,
  });

  final Uint8List bytes;
  final Widget Function(BuildContext context, Object error) failed;
  final Widget child;

  @override
  State<_Checked> createState() => _CheckedState();
}

class _CheckedState extends State<_Checked> {
  late Future<Size> _check = naturalImageSize(widget.bytes);

  @override
  void didUpdateWidget(_Checked oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _check = naturalImageSize(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Size>(
    future: _check,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return widget.failed(context, snapshot.error!);
      }
      if (!snapshot.hasData) {
        return const DcSkeleton(height: 240);
      }
      return widget.child;
    },
  );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DcTooltip(
    message: label,
    child: DcButton.icon(
      onPressed: onPressed,
      semanticLabel: label,
      icon: Icon(icon),
    ),
  );
}
