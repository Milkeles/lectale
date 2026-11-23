import 'dart:async';
import 'dart:math' as math;

import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/app_copy.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/app/theme.dart';
import 'package:lectale/src/contents/contents_list.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/preview/preview_providers.dart';
import 'package:lectale/src/widgets/measured_size.dart';
import 'package:lectale/src/widgets/ribbon.dart';
import 'package:lectale/src/widgets/skip_link.dart';
import 'package:lectale/src/widgets/top_bar.dart';

/// The width of the Contents pane at wide windows.
const double contentsPaneWidth = 272;

/// The frame of Course and Reader: skip link, top bar, the sticky Contents
/// bar, the Contents pane or panel, and the main column
/// (`docs/ux/inventory.md`, Shared layout).
///
/// One scroll view holds the top bar and the main column, so the top bar
/// scrolls away at every width while the Contents bar stays. At wide windows
/// the 272 dp pane sits beside the main column and scrolls on its own; below
/// that the Contents control opens a panel that is part of the address
/// (`?contents`), so system Back closes it.
///
/// While [outline] is null (loading, or the link failed) the Contents
/// control is disabled and no pane is drawn.
class ReadingFrame extends ConsumerStatefulWidget {
  /// Creates the frame around [child], the main column's content.
  const ReadingFrame({
    required this.outline,
    required this.selectedLessonId,
    required this.placeLessonId,
    required this.placeIsCurrent,
    required this.placeTitle,
    required this.panelOpen,
    required this.onOpenOverview,
    required this.onOpenLesson,
    required this.child,
    this.hideContentsControl = false,
    super.key,
  });

  /// The course's outline; null while it isn't known.
  final OutlineModel? outline;

  /// The lesson on screen; null when Overview is.
  final String? selectedLessonId;

  /// The lesson that carries the ribbon; null for Overview.
  final String? placeLessonId;

  /// Whether the ribbon row is the open lesson (Reader) or the last-opened
  /// one (Course).
  final bool placeIsCurrent;

  /// The title shown beside the ribbon when the pane is off screen; null
  /// shows nothing.
  final String? placeTitle;

  /// Whether the route asks for the Contents panel.
  final bool panelOpen;

  /// Opens Overview.
  final VoidCallback onOpenOverview;

  /// Opens a lesson's first resource.
  final ValueChanged<Lesson> onOpenLesson;

  /// Hides the Contents control, for a course with no overview whose
  /// outline is already shown inline (S5).
  final bool hideContentsControl;

  /// The main column's content.
  final Widget child;

  @override
  ConsumerState<ReadingFrame> createState() => _ReadingFrameState();
}

class _ReadingFrameState extends ConsumerState<ReadingFrame> {
  final FocusNode _main = FocusNode(debugLabel: 'main content');
  final FocusNode _list = FocusNode(debugLabel: 'contents list');
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  late final ScrollController _paneScroll;

  // Initial guesses at 100 percent text; measured after the first frame.
  double _topBarHeight = 54;
  double _barHeight = 52;

  @override
  void initState() {
    super.initState();
    // The pane keeps its scroll position across Course and Reader.
    _paneScroll = ScrollController(
      initialScrollOffset: ref.read(contentsScrollProvider),
    )..addListener(_rememberPaneScroll);
    FocusManager.instance.addListener(_keepFocusClearOfBar);
    if (widget.panelOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _list.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepFocusClearOfBar);
    _paneScroll
      ..removeListener(_rememberPaneScroll)
      ..dispose();
    _scroll.dispose();
    _main.dispose();
    _list.dispose();
    super.dispose();
  }

  void _rememberPaneScroll() {
    if (_paneScroll.hasClients) {
      ref.read(contentsScrollProvider.notifier).remember(_paneScroll.offset);
    }
  }

  /// WCAG 2.2 2.4.11: a focused element is never hidden behind the sticky
  /// bar. When focus lands under it, the page scrolls the difference.
  void _keepFocusClearOfBar() {
    final focus = FocusManager.instance.primaryFocus;
    final target = focus?.context;
    if (target == null || !_scroll.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !target.mounted) {
        return;
      }
      final scrollable = Scrollable.maybeOf(target, axis: Axis.vertical);
      if (scrollable?.position != _scroll.position) {
        return;
      }
      final box = target.findRenderObject();
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (box is! RenderBox ||
          viewport is! RenderBox ||
          !box.attached ||
          !box.hasSize) {
        return;
      }
      final top = box.localToGlobal(Offset.zero).dy;
      final viewportTop = viewport.localToGlobal(Offset.zero).dy;
      final barTop = viewportTop + math.max(0, _topBarHeight - _scroll.offset);
      final barBottom = barTop + _barHeight;
      if (top < barBottom && top + box.size.height > barTop) {
        final next = _scroll.offset - (barBottom - top) - 4;
        _scroll.jumpTo(
          next.clamp(
            _scroll.position.minScrollExtent,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _closePanel() {
    if (context.canPop()) {
      context.pop();
    } else {
      // A shared link that opens the panel directly has nothing to pop to.
      final uri = GoRouterState.of(context).uri;
      final query = Map<String, String>.of(uri.queryParameters)
        ..remove(AppRoutes.contentsQuery);
      context.go(uri.replace(queryParameters: query).toString());
    }
  }

  void _openPanel() {
    final uri = GoRouterState.of(context).uri;
    final next = uri.replace(
      queryParameters: {...uri.queryParameters, AppRoutes.contentsQuery: ''},
    );
    unawaited(context.push(next.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final colors = theme.colors;
    final gutter = pageGutter(context);
    final wide = isWideWindow(context);
    final outline = widget.outline;
    final paneOpen = ref.watch(paneOpenProvider);
    final showPane = wide && outline != null && paneOpen;
    final showPanel = !wide && outline != null && widget.panelOpen;
    final em = MediaQuery.textScalerOf(context).scale(Breakpoints.readingEm);
    // The pane and the text column are one group, centred in the window with
    // a 72 dp gap between them, so the outline stays next to the lesson it
    // controls on a wide screen (design review, Codex §2.1).
    final windowWidth = MediaQuery.sizeOf(context).width;
    final groupWidth = contentsPaneWidth + Breakpoints.contentsGap + 32 * em;
    final groupStart = showPane
        ? gutter + math.max(0.0, (windowWidth - 2 * gutter - groupWidth) / 2)
        : gutter;
    final columnStart = showPane
        ? groupStart + contentsPaneWidth + Breakpoints.contentsGap
        : gutter;

    final column = Padding(
      padding: EdgeInsetsDirectional.only(start: columnStart, end: gutter),
      child: Align(
        alignment: showPane
            ? AlignmentDirectional.topStart
            : AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 32 * em),
          child: showPanel ? _panel(context, outline) : widget.child,
        ),
      ),
    );

    return FocusTraversalGroup(
      // Chrome has explicit orders; the main column follows in reading
      // order: skip link, home, Contents control, Contents, then the page.
      policy: OrderedTraversalPolicy(),
      child: CallbackShortcuts(
        bindings: {
          if (showPanel)
            const SingleActivator(LogicalKeyboardKey.escape): _closePanel,
        },
        child: Stack(
          key: _viewportKey,
          children: [
            Positioned.fill(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: MeasuredSize(
                      onChanged: (size) =>
                          setState(() => _topBarHeight = size.height),
                      child: Padding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: gutter,
                        ),
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(1),
                          child: TopBar(
                            wordmark: AppCopy.wordmark,
                            markColor: LectaleColors.of(context).brand,
                            homeLabel: AppCopy.homeLink,
                            onHome: () => context.go(AppRoutes.open),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Room for the sticky bar, which is drawn above the scroll.
                  SliverToBoxAdapter(child: SizedBox(height: _barHeight)),
                  SliverToBoxAdapter(
                    child: Semantics(
                      container: true,
                      role: SemanticsRole.main,
                      child: Focus(
                        focusNode: _main,
                        // Reachable by the skip link, not a stop of its own.
                        skipTraversal: true,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: column,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _scroll,
              builder: (context, child) {
                final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                return Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: math.max(0, _topBarHeight - offset),
                  start: 0,
                  end: 0,
                  child: child!,
                );
              },
              child: MeasuredSize(
                onChanged: (size) => setState(() => _barHeight = size.height),
                child: _ContentsBar(
                  enabled: outline != null,
                  hideControl: widget.hideContentsControl,
                  paneVisible: showPane,
                  expanded: wide ? paneOpen : widget.panelOpen,
                  showExpanded: wide,
                  placeTitle: widget.placeTitle,
                  startInset: groupStart,
                  onPressed: () {
                    if (wide) {
                      ref.read(paneOpenProvider.notifier).set(open: !paneOpen);
                    } else if (widget.panelOpen) {
                      _closePanel();
                    } else {
                      _openPanel();
                    }
                  },
                ),
              ),
            ),
            if (showPane)
              AnimatedBuilder(
                animation: _scroll,
                builder: (context, child) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  return Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: math.max(0, _topBarHeight - offset) + _barHeight,
                    bottom: 0,
                    start: groupStart,
                    width: contentsPaneWidth,
                    child: child!,
                  );
                },
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    role: SemanticsRole.navigation,
                    label: PreviewCopy.contentsNav,
                    child: ColoredBox(
                      color: colors.canvas,
                      child: SingleChildScrollView(
                        controller: _paneScroll,
                        padding: EdgeInsets.only(bottom: style.space(8)),
                        child: _contentsList(outline),
                      ),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              // Below the window edge by the ring's gap and width, so the
              // ring is not cut off at the top (WCAG 2.4.7, 2.4.11).
              top: style.space(2),
              start: gutter,
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: SkipLink(label: AppCopy.skipLink, target: _main),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentsList(OutlineModel outline) => ContentsList(
    outline: outline,
    selectedLessonId: widget.selectedLessonId,
    placeLessonId: widget.placeLessonId,
    placeIsCurrent: widget.placeIsCurrent,
    onOpenOverview: widget.onOpenOverview,
    onOpenLesson: widget.onOpenLesson,
    focusNode: _list,
  );

  Widget _panel(BuildContext context, OutlineModel outline) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    return FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.navigation,
        label: PreviewCopy.contentsNav,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: style.space(3)),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      headingLevel: 2,
                      child: Text(
                        PreviewCopy.contents,
                        style: theme.typography.title.copyWith(
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  DcButton(
                    variant: DcButtonVariant.ghost,
                    semanticLabel: PreviewCopy.closeContents,
                    onPressed: _closePanel,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            SizedBox(height: style.space(2)),
            _contentsList(outline),
            SizedBox(height: style.space(8)),
          ],
        ),
      ),
    );
  }
}

/// The row under the top bar that stays when the page scrolls: the Contents
/// control and, when the pane is off screen, the ribbon and the title of the
/// learner's place.
class _ContentsBar extends StatelessWidget {
  const _ContentsBar({
    required this.enabled,
    required this.hideControl,
    required this.paneVisible,
    required this.expanded,
    required this.showExpanded,
    required this.placeTitle,
    required this.onPressed,
    required this.startInset,
  });

  /// Where the bar's content starts: the pane's start line on a wide window.
  final double startInset;
  final bool enabled;
  final bool hideControl;
  final bool paneVisible;
  final bool expanded;
  final bool showExpanded;
  final String? placeTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final colors = theme.colors;
    final gutter = pageGutter(context);
    final title = placeTitle;
    return ColoredBox(
      color: colors.canvas,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: style.controlHeights.medium),
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: startInset, end: gutter),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // The ribbon leads the collapsed control, with the title of
                // the learner's place after it, so the three read as one
                // group and the place shows on a phone.
                if (!paneVisible && enabled && title != null) ...[
                  SizedBox(
                    height: style.controlHeights.small,
                    child: Ribbon(color: colors.primary),
                  ),
                  SizedBox(width: style.space(2)),
                ],
                if (!hideControl)
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: Semantics(
                      expanded: showExpanded ? expanded : null,
                      child: DcButton(
                        variant: DcButtonVariant.ghost,
                        onPressed: enabled ? onPressed : null,
                        // A chevron says the control opens and closes.
                        trailing: ExcludeSemantics(
                          child: Icon(
                            expanded
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                          ),
                        ),
                        child: const Text(PreviewCopy.contents),
                      ),
                    ),
                  ),
                if (!paneVisible && enabled && title != null)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: style.space(2),
                        top: style.space(1),
                        bottom: style.space(1),
                      ),
                      child: Text(
                        title,
                        style: theme.typography.small.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
