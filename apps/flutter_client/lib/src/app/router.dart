import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/course/course_screen.dart';
import 'package:lectale/src/home/home_screen.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale/src/reader/reader_screen.dart';

/// The routes of the app. Each screen frames itself.
///
/// `/` redirects to the open-by-link screen until the new app home exists.
/// The Contents panel is the `?contents` query of a Course or Reader
/// address, so system Back closes it.
final List<RouteBase> appRoutes = [
  GoRoute(path: AppRoutes.root, redirect: (context, state) => AppRoutes.open),
  GoRoute(
    path: AppRoutes.open,
    builder: (context, state) => const HomeScreen(),
  ),
  GoRoute(
    path: AppRoutes.coursePattern,
    redirect: (context, state) =>
        PreviewKey.tryParse(
              state.pathParameters['repoId'],
              state.pathParameters['sha'],
            ) ==
            null
        ? AppRoutes.open
        : null,
    builder: (context, state) => CourseScreen(
      previewKey: PreviewKey.tryParse(
        state.pathParameters['repoId'],
        state.pathParameters['sha'],
      )!,
      panelOpen: state.uri.queryParameters.containsKey(AppRoutes.contentsQuery),
    ),
    routes: [
      GoRoute(
        path: ':lessonId/:resourceId',
        builder: (context, state) => ReaderScreen(
          previewKey: PreviewKey.tryParse(
            state.pathParameters['repoId'],
            state.pathParameters['sha'],
          )!,
          lessonId: state.pathParameters['lessonId']!,
          resourceId: state.pathParameters['resourceId']!,
          panelOpen: state.uri.queryParameters.containsKey(
            AppRoutes.contentsQuery,
          ),
        ),
      ),
    ],
  ),
];

/// Creates a router for the app's routes. The web build starts at the
/// browser's address; elsewhere [initialLocation] is where it starts.
GoRouter createRouter({String initialLocation = AppRoutes.root}) {
  // A pushed lesson or the Contents panel must show in the browser's address
  // and in its history, so Back and a shared link work (ADR-0014).
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(routes: appRoutes, initialLocation: initialLocation);
}

/// The app's router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
