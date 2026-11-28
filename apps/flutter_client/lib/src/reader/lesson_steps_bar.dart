import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/reading_text.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/preview/preview_navigation.dart';
import 'package:lectale/src/widgets/step_footer.dart';

/// Previous and Next, at the end of the lesson (reader.md §5, S8).
///
/// Next is the screen's one primary action and names the step: "Next file",
/// "Next lesson" or "Next assignment". On the last step it becomes Back to
/// course, above a calm end note. The two sit side by side, Previous first,
/// only when both full labels fit at the current text size; otherwise they
/// stack full width with Next first. Labels wrap and are never cut.
class LessonStepsBar extends StatelessWidget {
  /// Creates the bar for [step] of [outline].
  const LessonStepsBar({
    required this.outline,
    required this.step,
    required this.nav,
    super.key,
  });

  /// The course.
  final OutlineModel outline;

  /// The step on screen.
  final ReadingStep step;

  /// Moves between steps.
  final PreviewNavigation nav;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final before = outline.before(step);
    final after = outline.after(step);

    final nextLabel = after == null
        ? PreviewCopy.backToCourse
        : PreviewCopy.next(step, after);
    final previousLabel = before == null
        ? null
        : PreviewCopy.previous(step, before);

    final next = DcButton(
      size: DcButtonSize.large,
      onPressed: after == null ? nav.overview : () => nav.step(step, after),
      child: Text(nextLabel),
    );
    final previous = previousLabel == null
        ? null
        : DcButton(
            variant: DcButtonVariant.ghost,
            onPressed: () => nav.step(step, before!),
            child: Text(previousLabel),
          );

    final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.navigation,
      label: PreviewCopy.lessonSteps,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (after == null) ...[
            // The calm end of the course is reading text (reader.md §5).
            Text(PreviewCopy.endNote, style: ReadingStyles.of(context).reading),
            SizedBox(height: style.space(3)),
          ],
          // Both full labels side by side when they fit with an 18 dp gap,
          // measured from the real buttons; else stacked, Next first, full
          // width only on a phone.
          StepFooter(
            next: next,
            previous: previous,
            gap: style.space(4),
            stackGap: style.space(3),
            stretch: phone,
          ),
        ],
      ),
    );
  }
}
