import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/app/app_shell.dart';

/// The Course route. A placeholder: the next task builds the screen
/// (`docs/ux/screens/course.md`).
class CourseScreen extends StatelessWidget {
  /// Creates the placeholder.
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    return AppShell(
      child: Padding(
        padding: EdgeInsets.only(top: theme.style.space(8)),
        child: Semantics(
          header: true,
          child: Text(
            'Course',
            style: theme.typography.display.copyWith(
              color: theme.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
