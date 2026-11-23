/// The app's addresses (`docs/ux/inventory.md`, Routes; ADR-0014: the app
/// lives under `/app/` with hash URLs).
abstract final class AppRoutes {
  /// The app's root. It redirects to [open] until the new app home exists.
  static const String root = '/';

  /// Open a course by its link: turn a pasted address into an open course.
  static const String open = '/open';

  /// The Course route's pattern, with its two path parameters.
  static const String coursePattern = '/preview/:repoId/:sha';

  /// The Reader route's pattern, a child of the course.
  static const String readerPattern = '$coursePattern/:lessonId/:resourceId';

  /// The query that opens the Contents panel on a single-column layout. It is
  /// part of the address, so system Back closes the panel.
  static const String contentsQuery = 'contents';

  /// The resource id in a Reader address for a lesson with no files.
  static const String noResource = '-';

  /// The Course address of a pinned course.
  ///
  /// [repoId] and [sha] come from a `CoursePreview`, so they are numeric and
  /// hexadecimal and need no escaping.
  static String course({required int repoId, required String sha}) =>
      '/preview/$repoId/$sha';

  /// The Reader address of one resource of one lesson or assignment.
  ///
  /// [lessonId] is a manifest lesson ID, or `assignment~{id}` for an
  /// assignment; manifest IDs are lower-case letters, digits and hyphens, so
  /// no escaping is needed.
  static String reader({
    required int repoId,
    required String sha,
    required String lessonId,
    required String resourceId,
  }) => '${course(repoId: repoId, sha: sha)}/$lessonId/$resourceId';
}
