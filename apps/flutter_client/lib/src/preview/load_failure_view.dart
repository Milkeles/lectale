import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/home/failure_view.dart';
import 'package:lectale/src/home/home_copy.dart';
import 'package:lectale/src/preview/preview_copy.dart';

/// What failed to load, which decides the J5 row (`docs/ux/journeys-m2.md`).
enum LoadRegion {
  /// The course itself: its link no longer opens (J3a, J5b).
  course,

  /// The README: "The overview can't be shown."
  overview,

  /// A file of a lesson, inside the Reader.
  file,
}

/// The error copy for [failure] in [region], from the J5 table.
FailureCopy loadFailureCopy(Object failure, LoadRegion region) {
  final typed = switch (failure) {
    final ImportFailure known => known,
    // The viewers hand over any error; one that isn't a J5 case reads as
    // "ran into a problem", which never offers Try again.
    _ => const ImportUnexpected(retryable: false),
  };
  if (typed is ImportNotFound) {
    return switch (region) {
      LoadRegion.course => FailureCopy(
        title: 'Course not available',
        body:
            "Lectale can't open this course from this link. "
            'Enter its GitHub address to open the latest version.',
        summary: 'Course not available',
        requestId: typed.requestId,
      ),
      LoadRegion.overview => FailureCopy(
        title: "This file isn't available",
        body: "The overview can't be shown. Use Contents to start.",
        summary: "This file isn't available",
        requestId: typed.requestId,
      ),
      LoadRegion.file => FailureCopy(
        title: "This file isn't available",
        body:
            'Go on to the next item, or open the course again from its '
            'GitHub address.',
        summary: "This file isn't available",
        requestId: typed.requestId,
      ),
    };
  }
  return alertCopy(typed) ??
      const FailureCopy(title: '', body: '', summary: '');
}

/// Whether trying again can help: no response, a time-out, a rate limit, a
/// GitHub fault or a server answer marked retryable (J5 rules). Never for a
/// missing course or file.
bool canRetry(Object failure) => switch (failure) {
  ImportOffline() ||
  ImportTimedOut() ||
  ImportRateLimited() ||
  ImportGitHubUnavailable() => true,
  ImportUnexpected(:final retryable) => retryable,
  _ => false,
};

/// A failure inside the region that failed: the alert, Try again when it can
/// help, and the way to Home on a 404 (J5e).
class LoadFailureView extends StatelessWidget {
  /// Creates the view.
  const LoadFailureView({
    required this.failure,
    required this.region,
    required this.onRetry,
    super.key,
  });

  /// What went wrong.
  final Object failure;

  /// Where it happened.
  final LoadRegion region;

  /// Loads again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final style = DcTheme.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: style.space(3),
      children: [
        FailureView(copy: loadFailureCopy(failure, region)),
        if (canRetry(failure))
          DcButton(
            variant: DcButtonVariant.outline,
            onPressed: onRetry,
            child: const Text(PreviewCopy.tryAgain),
          )
        else if (failure is ImportNotFound && region != LoadRegion.overview)
          DcButton(
            variant: DcButtonVariant.link,
            onPressed: () => context.go(AppRoutes.open),
            child: const Text(PreviewCopy.enterAddress),
          ),
      ],
    );
  }
}

/// The error builder the viewers use: the file row of the J5 table.
Widget fileErrorBuilder(
  BuildContext context,
  Object error,
  VoidCallback retry,
) => LoadFailureView(failure: error, region: LoadRegion.file, onRetry: retry);

/// The error builder of the README region.
Widget overviewErrorBuilder(
  BuildContext context,
  Object error,
  VoidCallback retry,
) => LoadFailureView(
  failure: error,
  region: LoadRegion.overview,
  onRetry: retry,
);
