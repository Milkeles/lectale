import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/widgets/hover_fill.dart';
import 'package:lectale/src/widgets/ribbon.dart';
import 'package:lectale/src/widgets/roving_list.dart';

/// The rows of Contents: Overview, module headings, lessons and assignments
/// (`docs/ux/inventory.md`, Contents pane).
///
/// It is one tab stop with roving focus. Two marks, two meanings: the
/// *selected* row is the view on screen (Sand fill, semibold, `selected`);
/// the *ribbon* marks the learner's place. Only one ribbon is ever drawn.
class ContentsList extends StatelessWidget {
  /// Creates the list for [outline].
  const ContentsList({
    required this.outline,
    required this.selectedLessonId,
    required this.placeLessonId,
    required this.placeIsCurrent,
    required this.onOpenOverview,
    required this.onOpenLesson,
    this.focusNode,
    super.key,
  });

  /// The course.
  final OutlineModel outline;

  /// The lesson on screen, or null when Overview is.
  final String? selectedLessonId;

  /// The lesson that carries the ribbon, or null for Overview.
  final String? placeLessonId;

  /// Whether the ribbon row is the open lesson (Reader, ", current") or the
  /// last-opened one (Course, ", last opened").
  final bool placeIsCurrent;

  /// Opens Overview.
  final VoidCallback onOpenOverview;

  /// Opens the lesson's first resource.
  final ValueChanged<Lesson> onOpenLesson;

  /// Lets a screen move focus into the list.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final rows = outline.rows;
    final selectedIndex = selectedLessonId == null
        ? 0
        : 1 +
              rows.indexWhere(
                (row) => row is LessonRow && row.lesson.id == selectedLessonId,
              );
    final placeIndex = placeLessonId == null
        ? 0
        : 1 +
              rows.indexWhere(
                (row) => row is LessonRow && row.lesson.id == placeLessonId,
              );
    return RovingList(
      focusNode: focusNode,
      revealIndex: placeIndex < 0 ? null : placeIndex,
      itemCount: rows.length + 1,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      isNavigable: (index) => index == 0 || rows[index - 1] is LessonRow,
      onActivate: (index) {
        if (index == 0) {
          onOpenOverview();
        } else if (rows[index - 1] case LessonRow(:final lesson)) {
          onOpenLesson(lesson);
        }
      },
      itemBuilder: (context, index, {required active}) {
        if (index == 0) {
          return _ContentsRow(
            title: PreviewCopy.overview,
            semanticLabel: PreviewCopy.overview,
            selected: selectedLessonId == null,
            ribbon: placeLessonId == null,
            active: active,
            depth: 0,
            onTap: onOpenOverview,
          );
        }
        return switch (rows[index - 1]) {
          ModuleRow(:final title, :final depth) => _ModuleHeading(
            title: title,
            depth: depth,
          ),
          LessonRow(:final lesson, :final depth) => _ContentsRow(
            title: lesson.title,
            detail: lesson.isAssignment
                ? [
                    PreviewCopy.assignment,
                    if (lesson.dueAt != null) PreviewCopy.due(lesson.dueAt!),
                  ]
                : const [],
            semanticLabel: _lessonLabel(lesson),
            selected: lesson.id == selectedLessonId,
            ribbon: lesson.id == placeLessonId,
            active: active,
            depth: depth,
            onTap: () => onOpenLesson(lesson),
          ),
        };
      },
    );
  }

  String _lessonLabel(Lesson lesson) {
    final base = lesson.isAssignment
        ? [
            lesson.title,
            'assignment',
            if (lesson.dueAt != null)
              'due ${PreviewCopy.moment(lesson.dueAt!)}',
          ].join(', ')
        : '${lesson.title}, lesson';
    if (lesson.id != placeLessonId) {
      return base;
    }
    return placeIsCurrent ? '$base, current' : '$base, last opened';
  }
}

/// How far a row is indented: 18 dp per level, drawn to three levels.
double indentOf(DcStyle style, int depth) =>
    style.space(4) * (depth.clamp(0, 2));

class _ModuleHeading extends StatelessWidget {
  const _ModuleHeading({required this.title, required this.depth});

  final String title;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    return Semantics(
      container: true,
      header: true,
      label: title,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: Ribbon.width + style.space(3) + indentOf(style, depth),
          end: style.space(3),
          top: style.space(4),
          bottom: style.space(1),
        ),
        child: Text(
          title,
          style: theme.typography.subtitle.copyWith(
            color: theme.colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _ContentsRow extends StatelessWidget {
  const _ContentsRow({
    required this.title,
    required this.semanticLabel,
    required this.selected,
    required this.ribbon,
    required this.active,
    required this.depth,
    required this.onTap,
    this.detail = const [],
  });

  final String title;
  final List<String> detail;
  final String semanticLabel;
  final bool selected;
  final bool ribbon;
  final bool active;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final colors = theme.colors;
    final typography = theme.typography;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      focused: active,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: style.space(0.5)),
        child: HoverFill(
          builder: (context, {required hovered}) => DcFocusRing(
            visible: active,
            child: ColoredBox(
              // Sand marks the view on screen; a fill alone is under 3:1, so
              // the title is also semibold and the row says `selected`. A
              // lighter Sand under the pointer shows a row can be opened.
              color: selected
                  ? colors.muted
                  : hovered
                  ? hoverColor(theme)
                  : const Color(0x00000000),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: style.controlHeights.medium,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ribbon)
                        Ribbon(color: colors.primary)
                      else
                        const SizedBox(width: Ribbon.width),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: style.space(3) + indentOf(style, depth),
                            end: style.space(3),
                            top: style.space(1.5),
                            bottom: style.space(1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: typography.body.copyWith(
                                  color: colors.foreground,
                                  fontWeight: selected
                                      ? typography.semibold
                                      : typography.regular,
                                ),
                              ),
                              for (final line in detail)
                                Text(
                                  line,
                                  style: typography.small.copyWith(
                                    color: colors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
