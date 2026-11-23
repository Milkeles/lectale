// The constants are the strings themselves; a comment on each would repeat it.
// ignore_for_file: public_member_api_docs

import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

/// Fixed texts of the Course and Reader screens
/// (`docs/ux/screens/course.md` §9, `docs/ux/screens/reader.md` §9).
abstract final class PreviewCopy {
  static const String contents = 'Contents';
  static const String contentsNav = 'Course contents';
  static const String closeContents = 'Close contents';
  static const String overview = 'Overview';
  static const String assignment = 'Assignment';
  static const String startCourse = 'Start course';
  static const String lessonSteps = 'Lesson steps';
  static const String inThisLesson = 'In this lesson';
  static const String backToCourse = 'Back to course';
  static const String endNote = "You've reached the end of this course.";
  static const String emptyLesson = 'This lesson has no files yet.';
  static const String lessonNotInCourse = "This lesson isn't in this course.";
  static const String openOverview = 'Open Overview';
  static const String noOverview =
      'This course has no overview yet. Use Contents to start.';
  static const String overviewTooLarge =
      'The overview is too large to show here. Use Contents to start.';
  static const String noLessons = 'This course has no lessons yet.';
  static const String openAnotherCourse = 'Open another course';
  static const String enterAddress = 'Enter the GitHub address';
  static const String tryAgain = 'Try again';
  static const String assignmentNote =
      'You can read this assignment here. '
      "Submitting work isn't available in Lectale yet.";
  static const String authors = 'Authors';
  static const String level = 'Level';
  static const String time = 'Time';
  static const String language = 'Language';
  static const String license = 'License';
  static const String loading = 'Loading the course';

  static String continueWith(String lesson) => 'Continue: $lesson';

  static String about(int minutes) => 'About $minutes min';

  static String levelName(OutlineCourseLevel level) => switch (level) {
    OutlineCourseLevel.introductory => 'Introductory',
    OutlineCourseLevel.intermediate => 'Intermediate',
    OutlineCourseLevel.advanced => 'Advanced',
    OutlineCourseLevel.mixed => 'Mixed levels',
  };

  /// "English" for `en`, and so on; the tag itself when the app has no name
  /// for it. The platform's locale data is not available to the widgets
  /// layer, so a short table covers the common course languages.
  static String languageName(String tag) {
    final code = tag.split(RegExp('[-_]')).first.toLowerCase();
    return _languages[code] ?? tag;
  }

  static const Map<String, String> _languages = {
    'en': 'English',
    'bg': 'Bulgarian',
    'de': 'German',
    'fr': 'French',
    'es': 'Spanish',
    'it': 'Italian',
    'pt': 'Portuguese',
    'nl': 'Dutch',
    'pl': 'Polish',
    'ro': 'Romanian',
    'el': 'Greek',
    'ru': 'Russian',
    'uk': 'Ukrainian',
    'sr': 'Serbian',
    'tr': 'Turkish',
    'cs': 'Czech',
    'sv': 'Swedish',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  /// The label of Next: names the step (S8).
  static String next(ReadingStep from, ReadingStep to) =>
      _stepLabel('Next', from, to);

  /// The label of Previous.
  static String previous(ReadingStep from, ReadingStep to) =>
      _stepLabel('Previous', from, to);

  static String _stepLabel(String direction, ReadingStep from, ReadingStep to) {
    if (from.lesson.id == to.lesson.id) {
      return '$direction file: ${to.resource?.title ?? to.lesson.title}';
    }
    final kind = to.lesson.isAssignment ? 'assignment' : 'lesson';
    return '$direction $kind: ${to.lesson.title}';
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "4 Dec 2026, 00:59 CET": a moment in the learner's time zone.
  static String moment(DateTime when) {
    final local = when.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final zone = local.timeZoneName;
    return '${local.day} ${_months[local.month - 1]} ${local.year}, '
        '$hour:$minute${zone.isEmpty ? '' : ' $zone'}';
  }

  static String due(DateTime when) => 'Due ${moment(when)}';
  static String opens(DateTime when) => 'Opens ${moment(when)}';
  static String closes(DateTime when) => 'Closes ${moment(when)}';
}
