import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/preview/preview_navigation.dart';

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

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.navigation,
      label: PreviewCopy.lessonSteps,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (after == null) ...[
            Text(
              PreviewCopy.endNote,
              style: theme.typography.body.copyWith(
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: style.space(3)),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide =
                  previous != null &&
                  _fitsTogether(
                    context,
                    constraints.maxWidth,
                    previousLabel!,
                    nextLabel,
                  );
              if (previous == null) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: next,
                );
              }
              if (sideBySide) {
                return Row(
                  spacing: style.space(3),
                  children: [previous, const Spacer(), next],
                );
              }
              // Stacked, Next comes first. Full width only on a phone; on a
              // wider window the buttons keep their own width and share the
              // start edge, so the footer never turns into a banner.
              final phone =
                  MediaQuery.sizeOf(context).width < Breakpoints.compact;
              return Column(
                crossAxisAlignment: phone
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                spacing: style.space(3),
                children: [next, previous],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Whether both labels fit on one line each beside one another, with the
  /// buttons' padding, at the current text size.
  bool _fitsTogether(
    BuildContext context,
    double available,
    String previousLabel,
    String nextLabel,
  ) {
    if (MediaQuery.sizeOf(context).width < Breakpoints.compact) {
      return false;
    }
    final theme = DcTheme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: theme.typography.label),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    // 24 dp of padding on each side of a label, and a 13.5 dp gap.
    const padding = 48.0;
    return width(previousLabel) + width(nextLabel) + 2 * padding + 13.5 + 8 <=
        available;
  }
}
