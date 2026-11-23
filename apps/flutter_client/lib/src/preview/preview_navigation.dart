import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_key.dart';

/// Where focus goes when the Reader opens after Next, Previous or a choice in
/// In this lesson (reader.md §8): the new h1 when the lesson changed, the new
/// h2 when only the file did. Null on a plain open, so the first Tab still
/// reaches the skip link (inventory: Keyboard).
enum ReaderFocusTarget {
  /// The lesson's h1.
  lessonTitle,

  /// The resource's h2.
  resourceTitle,
}

/// The pending focus request for the next Reader that opens.
final NotifierProvider<PendingReaderFocus, ReaderFocusTarget?>
pendingReaderFocusProvider =
    NotifierProvider<PendingReaderFocus, ReaderFocusTarget?>(
      PendingReaderFocus.new,
    );

/// The request behind [pendingReaderFocusProvider].
class PendingReaderFocus extends Notifier<ReaderFocusTarget?> {
  @override
  ReaderFocusTarget? build() => null;

  /// Asks the next Reader to focus [target].
  // ignore: use_setters_to_change_properties
  void request(ReaderFocusTarget? target) => state = target;

  /// Returns the request and clears it.
  ReaderFocusTarget? take() {
    final target = state;
    state = null;
    return target;
  }
}

/// Moves between Course and Reader, with the history rules of the spec: a
/// lesson change pushes an entry; a file change within a lesson replaces it
/// (reader.md §8, S8). When the Contents panel is open it is closed first,
/// because it is its own history entry.
class PreviewNavigation {
  /// Creates the navigator for [key].
  PreviewNavigation(this.context, this.ref, this.key, {this.panelOpen = false});

  /// The screen's context.
  final BuildContext context;

  /// For the pending focus request.
  final WidgetRef ref;

  /// The course.
  final PreviewKey key;

  /// Whether the Contents panel entry is on top of the stack.
  final bool panelOpen;

  String _reader(ReadingStep step) => AppRoutes.reader(
    repoId: key.repoId,
    sha: key.sha,
    lessonId: step.lesson.id,
    resourceId: step.resourceId,
  );

  void _closePanel() {
    if (panelOpen && context.canPop()) {
      context.pop();
    }
  }

  /// Opens Overview.
  void overview() {
    _closePanel();
    context.go(AppRoutes.course(repoId: key.repoId, sha: key.sha));
  }

  /// Opens the first file of [lesson].
  void lesson(Lesson lesson, {String? currentLessonId}) {
    _closePanel();
    if (lesson.id == currentLessonId) {
      return;
    }
    final step = ReadingStep(
      lesson,
      lesson.resources.isEmpty ? null : lesson.resources.first,
    );
    unawaited(context.push(_reader(step)));
  }

  /// Moves from [from] to [to] with Next, Previous or a choice in the lesson.
  void step(ReadingStep from, ReadingStep to) {
    final sameLesson = from.lesson.id == to.lesson.id;
    ref
        .read(pendingReaderFocusProvider.notifier)
        .request(
          sameLesson
              ? ReaderFocusTarget.resourceTitle
              : ReaderFocusTarget.lessonTitle,
        );
    if (sameLesson) {
      context.pushReplacement(_reader(to));
    } else {
      unawaited(context.push(_reader(to)));
    }
  }
}
