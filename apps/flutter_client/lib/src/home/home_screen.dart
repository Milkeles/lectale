import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/app_shell.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/home/failure_view.dart';
import 'package:lectale/src/home/home_controller.dart';
import 'package:lectale/src/home/home_copy.dart';
import 'package:lectale/src/home/home_state.dart';

/// Home: turn a pasted GitHub address into an open course, or say exactly
/// why it can't open (`docs/ux/screens/home.md`).
///
/// One primary action, Open course. The column is 560 dp wide on the page's
/// start line and nothing else is drawn.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const double _columnWidth = 560;

  final TextEditingController _address = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'repository address');

  @override
  void dispose() {
    _address.dispose();
    _field.dispose();
    super.dispose();
  }

  void _submit() =>
      ref.read(homeControllerProvider.notifier).submit(_address.text);

  void _onStateChanged(HomeState? previous, HomeState next) {
    switch (next) {
      case HomeSuccess(:final preview):
        context.go(
          AppRoutes.course(
            repoId: preview.repoId.value,
            sha: preview.sha.value,
          ),
        );
      case HomeFailure(:final failure):
        // One focus rule (S2): after any error, focus goes to the field. A
        // wait that ends is not a new error.
        final isNew = previous is! HomeFailure || previous.failure != failure;
        if (isNew) {
          _field.requestFocus();
        }
      case HomeIdle() || HomeLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeControllerProvider, _onStateChanged);
    final state = ref.watch(homeControllerProvider);
    final theme = DcTheme.of(context);
    final colors = theme.colors;
    final style = theme.style;
    final typography = theme.typography;

    final loading = state is HomeLoading;
    final failure = state is HomeFailure ? state.failure : null;
    final canSubmit = state is! HomeFailure || state.canSubmit;
    final fieldMessage = failure is ImportInvalidAddress
        ? addressMessage(failure.issue)
        : null;
    final alert = failure == null ? null : alertCopy(failure);

    final width = MediaQuery.sizeOf(context).width;
    // The button is full width below 600 dp, and also when large text would
    // leave the field too little room beside it.
    final stacked =
        width < Breakpoints.compact ||
        MediaQuery.textScalerOf(context).scale(14) >= 28;
    final topGap = width < Breakpoints.compact
        ? style.space(8)
        : width < Breakpoints.wide(context)
        ? style.space(12)
        : style.space(16);

    final field = _AddressField(
      controller: _address,
      focusNode: _field,
      invalid: fieldMessage != null,
      autofocus: isWideWindow(context),
      message: fieldMessage,
      onChanged: () => ref.read(homeControllerProvider.notifier).edited(),
      onSubmitted: _submit,
    );
    final button = DcButton(
      onPressed: canSubmit ? _submit : null,
      size: DcButtonSize.large,
      // Not `loading: true`: that disables the button, and pressing it again
      // while a request runs must restart with the current text.
      leading: loading
          ? ExcludeSemantics(
              child: DcSpinner(size: 16, color: colors.primaryForeground),
            )
          : null,
      child: const Text(HomeCopy.button),
    );

    return AppShell(
      homeLink: false,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              ref.read(homeControllerProvider.notifier).cancel(),
        },
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _columnWidth),
            child: Padding(
              padding: EdgeInsets.only(top: topGap, bottom: style.space(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      HomeCopy.title,
                      style: typography.display.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  SizedBox(height: style.space(2)),
                  Text(
                    HomeCopy.help,
                    style: typography.body.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  SizedBox(height: style.space(6)),
                  // The visible label names the field through the field's own
                  // semantics, so the text is not read twice.
                  ExcludeSemantics(
                    child: DcLabel(HomeCopy.label, onTap: _field.requestFocus),
                  ),
                  SizedBox(height: style.space(1.5)),
                  if (stacked) ...[
                    field,
                    SizedBox(height: style.space(3)),
                    button,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: style.space(3),
                      children: [
                        Expanded(child: field),
                        button,
                      ],
                    ),
                  if (state case HomeLoading(:final slow)) ...[
                    SizedBox(height: style.space(4)),
                    Semantics(
                      container: true,
                      liveRegion: true,
                      child: Text(
                        slow ? HomeCopy.slowProgress : HomeCopy.progress,
                        style: typography.small.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                  if (alert != null) ...[
                    SizedBox(height: style.space(4)),
                    FailureView(copy: alert),
                  ],
                  if (state is HomeFailure && state.waitOver)
                    // Says once that the wait ended; nothing is drawn.
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: HomeCopy.waitOver,
                      child: const SizedBox.square(dimension: 1),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The address field with its hint and inline error, read by a screen reader
/// as one control.
class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.focusNode,
    required this.invalid,
    required this.autofocus,
    required this.message,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool invalid;
  final bool autofocus;
  final String? message;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final colors = theme.colors;
    final style = theme.style;
    final small = theme.typography.small;
    // Flutter has no "described by" link, so the field's name is its label
    // followed by the hint and the error, and the visible texts are hidden
    // from the tree to avoid reading them twice. The name starts with the
    // visible label (WCAG 2.5.3).
    final name = [HomeCopy.label, HomeCopy.hint, ?message].join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DcInput(
          controller: controller,
          focusNode: focusNode,
          semanticLabel: name,
          autofocus: autofocus,
          invalid: invalid,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.url],
          // As tall as the button beside it.
          style: DcInputStyle(height: style.controlHeights.large),
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
        SizedBox(height: style.space(1.5)),
        ExcludeSemantics(
          child: Text(
            HomeCopy.hint,
            style: small.copyWith(color: colors.mutedForeground),
          ),
        ),
        if (message != null) ...[
          SizedBox(height: style.space(1)),
          ExcludeSemantics(
            child: Text(
              message!,
              style: small.copyWith(color: colors.destructive),
            ),
          ),
        ],
      ],
    );
  }
}
