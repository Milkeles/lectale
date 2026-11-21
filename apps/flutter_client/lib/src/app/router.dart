import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/course/course_screen.dart';
import 'package:lectale/src/home/home_screen.dart';
import 'package:lectale/src/reader/reader_screen.dart';

/// The routes of the app. Each screen frames itself with `AppShell`.
///
/// Course and Reader are placeholders until the next task builds them.
final List<RouteBase> appRoutes = [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const HomeScreen(),
  ),
  GoRoute(
    path: AppRoutes.coursePattern,
    builder: (context, state) => const CourseScreen(),
    routes: [
      GoRoute(
        path: 'read/:nodeId',
        builder: (context, state) => const ReaderScreen(),
      ),
    ],
  ),
];

/// Creates a router for the app's routes. The web build starts at the
/// browser's address; elsewhere [initialLocation] is where it starts.
GoRouter createRouter({String initialLocation = AppRoutes.home}) =>
    GoRouter(routes: appRoutes, initialLocation: initialLocation);

/// The app's router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
