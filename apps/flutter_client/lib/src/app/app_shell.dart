import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/app_copy.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/app/theme.dart';
import 'package:lectale/src/widgets/skip_link.dart';
import 'package:lectale/src/widgets/top_bar.dart';

/// The frame every screen shares: the skip link, the top bar and the main
/// content, scrolling together so the bar scrolls away with the page at every
/// width (C13).
///
/// Each screen builds its own frame rather than sharing one above the
/// router: Tab only moves within one route's focus scope, so a skip link
/// outside the screen could not be the first stop.
class AppShell extends StatefulWidget {
  /// Frames [child] as the screen's main content.
  ///
  /// Set [homeLink] to false on the start screen, where the bar is plain
  /// text; everywhere else the bar links to it.
  const AppShell({required this.child, this.homeLink = true, super.key});

  /// The main content.
  final Widget child;

  /// Whether the top bar is a link to the start screen.
  final bool homeLink;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final FocusNode _main = FocusNode(debugLabel: 'main content');

  @override
  void dispose() {
    _main.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = pageGutter(context);
    return FocusTraversalGroup(
      // The skip link is the first stop, then the screen in reading order.
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: gutter,
                    ),
                    child: TopBar(
                      wordmark: AppCopy.wordmark,
                      markColor: LectaleColors.of(context).brand,
                      homeLabel: widget.homeLink ? AppCopy.homeLink : null,
                      onHome: widget.homeLink
                          ? () => context.go(AppRoutes.open)
                          : null,
                    ),
                  ),
                  Semantics(
                    container: true,
                    role: SemanticsRole.main,
                    child: Focus(
                      focusNode: _main,
                      // Reachable by the skip link, not a stop of its own.
                      skipTraversal: true,
                      // Each text and control inside is its own node, so the
                      // heading stays a heading and the live regions stay
                      // separate instead of merging into the landmark.
                      child: Semantics(
                        container: true,
                        explicitChildNodes: true,
                        child: Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: gutter,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            // Below the window edge by the ring's 2 dp gap and 2 dp width, so
            // the ring is not cut off at the top (WCAG 2.4.7, 2.4.11).
            top: DcTheme.of(context).style.space(2),
            start: gutter,
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: SkipLink(label: AppCopy.skipLink, target: _main),
            ),
          ),
        ],
      ),
    );
  }
}
