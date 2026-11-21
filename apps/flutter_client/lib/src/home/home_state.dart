import 'package:flutter/foundation.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// What the Home screen is doing (`docs/ux/screens/home.md` §6).
@immutable
sealed class HomeState {
  const HomeState();
}

/// Nothing has been tried yet, or the learner edited the address while a
/// request ran and so cancelled it.
final class HomeIdle extends HomeState {
  /// Creates the state.
  const HomeIdle();
}

/// An import is running.
final class HomeLoading extends HomeState {
  /// Creates the state.
  const HomeLoading({this.slow = false});

  /// Whether it has run long enough to say so (8 s).
  final bool slow;
}

/// The last attempt failed.
final class HomeFailure extends HomeState {
  /// Creates the state.
  const HomeFailure(
    this.failure, {
    this.canSubmit = true,
    this.waitOver = false,
  });

  /// What went wrong.
  final ImportFailure failure;

  /// Whether Open course is enabled. False while a rate-limit wait runs, and
  /// after a failure that trying again can't help, until the address changes.
  final bool canSubmit;

  /// Whether a rate-limit wait has ended, so the screen can say so once.
  final bool waitOver;
}

/// The course opened.
final class HomeSuccess extends HomeState {
  /// Creates the state.
  const HomeSuccess(this.preview);

  /// The pinned course; its `repoId` and `sha` make the Course route.
  final CoursePreview preview;
}
