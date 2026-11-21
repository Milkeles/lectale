/// The app's addresses (`docs/ux/inventory.md`, Routes).
abstract final class AppRoutes {
  /// Home: turn an address into an open course.
  static const String home = '/';

  /// The Course route's pattern, with its two path parameters.
  static const String coursePattern = '/preview/:repoId/:sha';

  /// The Reader route's pattern, a child of the course.
  static const String readerPattern = '$coursePattern/read/:nodeId';

  /// The Course address of a pinned course.
  ///
  /// [repoId] and [sha] come from a `CoursePreview`, so they are numeric and
  /// hexadecimal and need no escaping.
  static String course({required int repoId, required String sha}) =>
      '/preview/$repoId/$sha';
}
