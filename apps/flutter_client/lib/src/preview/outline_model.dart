import 'package:flutter/foundation.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// A lesson or an assignment: one place the reader can open, in outline
/// order.
@immutable
class Lesson {
  /// Creates a lesson.
  const Lesson({
    required this.id,
    required this.title,
    required this.isAssignment,
    required this.resources,
    this.moduleTitle,
    this.description,
    this.openAt,
    this.dueAt,
    this.closeAt,
  });

  /// The ID in a Reader address: the manifest lesson ID, or
  /// `assignment~{assignmentId}` for an assignment, as in the resource hrefs.
  final String id;

  /// The title shown in Contents and as the Reader's h1.
  final String title;

  /// Whether this is an assignment.
  final bool isAssignment;

  /// The title of the module the lesson sits in, or null at the top level.
  final String? moduleTitle;

  /// The lesson's files, in manifest order.
  final List<OutlineResource> resources;

  /// The author's description.
  final String? description;

  /// When an assignment opens for submissions.
  final DateTime? openAt;

  /// When an assignment is due.
  final DateTime? dueAt;

  /// When an assignment closes.
  final DateTime? closeAt;

  /// The resource with [id], or null.
  OutlineResource? resource(String id) {
    for (final resource in resources) {
      if (resource.id.value == id) {
        return resource;
      }
    }
    return null;
  }
}

/// A row of Contents below Overview.
@immutable
sealed class OutlineRow {
  const OutlineRow(this.depth);

  /// How deep the row sits: 0 at the top level.
  final int depth;
}

/// A module heading: not a target.
final class ModuleRow extends OutlineRow {
  /// Creates the row.
  const ModuleRow(this.title, super.depth);

  /// The module's title.
  final String title;
}

/// A lesson or assignment row.
final class LessonRow extends OutlineRow {
  /// Creates the row.
  const LessonRow(this.lesson, super.depth);

  /// The place it opens.
  final Lesson lesson;
}

/// One step of reading: a file of a lesson. A lesson with no files has one
/// step with no [resource], so Next and Previous still pass through it.
@immutable
class ReadingStep {
  /// Creates a step.
  const ReadingStep(this.lesson, this.resource);

  /// The lesson or assignment.
  final Lesson lesson;

  /// The file, or null for a lesson with no files.
  final OutlineResource? resource;

  /// The Reader's resource ID segment for this step.
  String get resourceId => resource?.id.value ?? '-';

  @override
  bool operator ==(Object other) =>
      other is ReadingStep &&
      other.lesson.id == lesson.id &&
      other.resourceId == resourceId;

  @override
  int get hashCode => Object.hash(lesson.id, resourceId);
}

/// The outline of a course, flattened for Contents and for Next and
/// Previous.
class OutlineModel {
  /// Reads the outline of [preview].
  factory OutlineModel.of(CoursePreview preview) {
    final outline = preview.outline;
    final assignments = {
      for (final assignment in outline.assignments)
        assignment.id.value: assignment,
    };
    final rows = <OutlineRow>[];
    final lessons = <Lesson>[];

    void visit(CourseOutlineNode node, int depth, String? module) {
      switch (node.kind) {
        case CourseOutlineNodeKind.module:
          rows.add(ModuleRow(node.title, depth));
          for (final child in node.children) {
            visit(child, depth + 1, node.title);
          }
        case CourseOutlineNodeKind.lesson:
          final lesson = Lesson(
            id: node.id.value,
            title: node.title,
            isAssignment: false,
            moduleTitle: module,
            description: node.description,
            resources: node.resources,
          );
          lessons.add(lesson);
          rows.add(LessonRow(lesson, depth));
        case CourseOutlineNodeKind.assignment:
          final id = node.assignmentId?.value;
          final assignment = id == null ? null : assignments[id];
          final lesson = Lesson(
            id: 'assignment~${id ?? node.id.value}',
            title: node.title,
            isAssignment: true,
            moduleTitle: module,
            description: assignment?.description,
            resources: assignment?.resources ?? const [],
            openAt: assignment?.openAt,
            dueAt: assignment?.dueAt,
            closeAt: assignment?.closeAt,
          );
          lessons.add(lesson);
          rows.add(LessonRow(lesson, depth));
      }
    }

    for (final node in outline.nodes) {
      visit(node, 0, null);
    }
    final steps = [
      for (final lesson in lessons)
        if (lesson.resources.isEmpty)
          ReadingStep(lesson, null)
        else
          for (final resource in lesson.resources)
            ReadingStep(lesson, resource),
    ];
    return OutlineModel._(preview, rows, lessons, steps);
  }

  const OutlineModel._(this.preview, this.rows, this.lessons, this.steps);

  /// The import result this was read from.
  final CoursePreview preview;

  /// Module headings and lessons below Overview, in outline order.
  final List<OutlineRow> rows;

  /// Every lesson and assignment, in outline order.
  final List<Lesson> lessons;

  /// Every step of reading, in order.
  final List<ReadingStep> steps;

  /// The course.
  OutlineCourse get course => preview.outline.course;

  /// The lesson with [id], or null.
  Lesson? lesson(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) {
        return lesson;
      }
    }
    return null;
  }

  /// The step for [lessonId] and [resourceId], or null when either is not in
  /// the outline.
  ReadingStep? step(String lessonId, String resourceId) {
    for (final step in steps) {
      if (step.lesson.id == lessonId && step.resourceId == resourceId) {
        return step;
      }
    }
    return null;
  }

  /// The step before [step], or null at the start.
  ReadingStep? before(ReadingStep step) {
    final index = steps.indexOf(step);
    return index > 0 ? steps[index - 1] : null;
  }

  /// The step after [step], or null at the end.
  ReadingStep? after(ReadingStep step) {
    final index = steps.indexOf(step);
    return index >= 0 && index < steps.length - 1 ? steps[index + 1] : null;
  }
}
