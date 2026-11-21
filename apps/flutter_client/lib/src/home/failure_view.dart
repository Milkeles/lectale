import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/home/home_copy.dart';

/// The alert for a failure that isn't about the address field: its title,
/// what to do, the problems list of an invalid course.yaml, and the support
/// reference (`docs/ux/screens/home.md` §5, §6).
///
/// The alert itself does not announce. `FailureCopy.summary` sits in a
/// separate polite live region that speaks the title and, for the problems
/// list, the count (S2), so a screen-reader user isn't read every problem
/// unasked.
class FailureView extends StatelessWidget {
  /// Shows [copy].
  const FailureView({required this.copy, super.key});

  /// What to show.
  final FailureCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DcAlert(
          variant: DcAlertVariant.destructive,
          title: Text(copy.title),
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: style.space(2),
            children: [
              Text(copy.body),
              if (copy.problems.isNotEmpty)
                _ProblemList(problems: copy.problems),
              if (copy.truncated) const Text(HomeCopy.truncated),
              if (copy.requestId case final id?) _Reference(id),
            ],
          ),
        ),
        // A node with no size of its own, only words for the screen reader.
        Semantics(
          container: true,
          liveRegion: true,
          label: copy.summary,
          child: const SizedBox.square(dimension: 1),
        ),
      ],
    );
  }
}

class _ProblemList extends StatelessWidget {
  const _ProblemList({required this.problems});

  final List<ProblemCopy> problems;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    return Semantics(
      container: true,
      role: SemanticsRole.list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: style.space(3),
        children: [
          for (final problem in problems)
            Semantics(
              container: true,
              role: SemanticsRole.listItem,
              child: _Problem(problem),
            ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.problem);

  final ProblemCopy problem;

  @override
  Widget build(BuildContext context) {
    final typography = DcTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(problem.message),
        Text(problem.location, style: typography.small),
        // The exact pointer is for the author, who can search the file for it.
        Text.rich(
          TextSpan(
            children: [
              if (problem.pointer.isNotEmpty)
                TextSpan(text: problem.pointer, style: typography.code),
              if (problem.pointer.isNotEmpty) const TextSpan(text: '  '),
              TextSpan(text: problem.code, style: typography.small),
            ],
          ),
        ),
      ],
    );
  }
}

class _Reference extends StatelessWidget {
  const _Reference(this.requestId);

  final String requestId;

  @override
  Widget build(BuildContext context) {
    // A reference is quoted to support, so it must be selectable. litse-ui's
    // controls draw the handles and the copy menu without Material.
    return SelectableRegion(
      selectionControls: DcTextSelectionControls(),
      contextMenuBuilder: (context, state) => DcTextContextMenu(
        anchors: state.contextMenuAnchors,
        buttonItems: state.contextMenuButtonItems,
      ),
      child: Text(
        'Reference $requestId',
        style: DcTheme.of(context).typography.small,
      ),
    );
  }
}
