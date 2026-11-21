import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The Lectale app shell.
///
/// Built on [WidgetsApp] rather than a Material app: all UI comes from
/// devchat_ui (ADR-0004). The theme follows the platform's brightness and
/// high-contrast setting so readers get their system preference from the
/// first frame.
class LectaleApp extends StatelessWidget {
  /// Creates the app.
  const LectaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Lectale',
      // The color of the app in the system's list of running apps.
      color: const Color(0xFF1F2937),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DcLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: DcLocalizations.supportedLocales,
      // Plain page routes; go_router replaces this in milestone M2.
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      builder: (context, child) => DcAnimatedTheme(
        data: DcThemeData(
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
      home: const _Placeholder(),
    );
  }
}

/// Stands in for the home screen until milestone M2 designs it.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Lectale'));
  }
}
