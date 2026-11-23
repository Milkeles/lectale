import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/environment.dart';

/// Runs [load] once, shows skeleton lines meanwhile, then [builder]; a
/// failure shows the environment's error view in place, and its Try again
/// runs [load] again (J5e: a failure stays inside the region that failed).
class LoadOnce<T> extends StatefulWidget {
  /// Creates the loader.
  const LoadOnce({
    required this.load,
    required this.environment,
    required this.builder,
    this.onError,
    this.placeholder,
    super.key,
  });

  /// Starts the work. Called again for Try again.
  final Future<T> Function() load;

  /// Supplies the error view.
  final ResourceEnvironment environment;

  /// Builds the result.
  final Widget Function(BuildContext context, T data) builder;

  /// Replaces the error view for failures the caller handles itself: return
  /// a widget to use it, or null to fall back to the standard error view.
  final Widget? Function(BuildContext context, Object error)? onError;

  /// Shown while loading; skeleton lines when null.
  final Widget? placeholder;

  @override
  State<LoadOnce<T>> createState() => _LoadOnceState<T>();
}

class _LoadOnceState<T> extends State<LoadOnce<T>> {
  late Future<T> _future = widget.load();

  void _retry() {
    final next = widget.load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error!;
          return widget.onError?.call(context, error) ??
              widget.environment.errorBuilder(context, error, _retry);
        }
        if (snapshot.hasData) {
          return widget.builder(context, snapshot.requireData);
        }
        return widget.placeholder ?? const SkeletonLines();
      },
    );
  }
}

/// Six lines of loading placeholder in the shape of text, announced as
/// "Loading".
class SkeletonLines extends StatelessWidget {
  /// Creates the placeholder with [lines] lines.
  const SkeletonLines({this.lines = 6, super.key});

  /// How many lines to draw.
  final int lines;

  @override
  Widget build(BuildContext context) {
    final style = DcTheme.of(context).style;
    return Semantics(
      container: true,
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: style.space(3),
          children: [
            for (var i = 0; i < lines; i++)
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: i == lines - 1 ? 0.6 : 1,
                child: DcSkeleton(height: style.space(4)),
              ),
          ],
        ),
      ),
    );
  }
}
