import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/app/app_copy.dart';
import 'package:lectale/src/app/router.dart';
import 'package:lectale/src/app/theme.dart';

/// The Lectale app.
///
/// Built on [WidgetsApp.router] rather than a Material app: all UI comes from
/// devchat_ui (ADR-0004). The theme follows the platform's brightness and
/// high-contrast setting from the first frame.
class LectaleApp extends ConsumerWidget {
  /// Creates the app. It needs a [ProviderScope] above it.
  ///
  /// [themeFor] picks the theme for the platform's brightness and contrast
  /// setting; tests replace it to draw text with a font that contrast checks
  /// can read.
  const LectaleApp({this.themeFor = lectaleTheme, super.key});

  /// Builds the theme for a brightness and contrast setting.
  final DcThemeData Function({
    required Brightness brightness,
    bool highContrast,
  })
  themeFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WidgetsApp.router(
      routerConfig: ref.watch(routerProvider),
      title: AppCopy.title,
      // The color of the app in the system's list of running apps.
      color: lectaleMulberry,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DcLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: DcLocalizations.supportedLocales,
      builder: (context, child) => DcAnimatedTheme(
        data: themeFor(
          brightness: MediaQuery.platformBrightnessOf(context),
          highContrast: MediaQuery.highContrastOf(context),
        ),
        child: Builder(
          builder: (context) => ColoredBox(
            color: DcTheme.of(context).colors.canvas,
            child: child,
          ),
        ),
      ),
    );
  }
}
