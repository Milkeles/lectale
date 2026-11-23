import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/reading_text.dart';
import 'package:lectale/src/app/routes.dart';
import 'package:lectale/src/app/theme.dart';
import 'package:lectale/src/contents/contents_list.dart';
import 'package:lectale/src/course/course_cover.dart';
import 'package:lectale/src/preview/load_failure_view.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale/src/preview/preview_navigation.dart';
import 'package:lectale/src/preview/preview_providers.dart';
import 'package:lectale/src/reading/reading_frame.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// Course: what a course is and where to begin
/// (`docs/ux/screens/course.md`).
///
/// One primary action, Start course (or Continue after a lesson was opened
/// this visit). The header comes from the preview at once; the README, the
/// overview, loads below it and fails on its own.
class CourseScreen extends ConsumerWidget {
  /// Creates the screen for the course at [previewKey].
  const CourseScreen({
    required this.previewKey,
    required this.panelOpen,
    super.key,
  });

  /// The pinned course.
  final PreviewKey previewKey;

  /// Whether the route asks for the Contents panel.
  final bool panelOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(outlineProvider(previewKey));
    final model = outline.value;
    final lastOpened = ref.watch(lastOpenedProvider)[previewKey];
    final nav = PreviewNavigation(
      context,
      ref,
      previewKey,
      panelOpen: panelOpen,
    );
    final lesson = model == null || lastOpened == null
        ? null
        : model.lesson(lastOpened);
    return ReadingFrame(
      outline: model,
      selectedLessonId: null,
      placeLessonId: lesson?.id,
      placeIsCurrent: false,
      placeTitle:
          lesson?.title ?? (model == null ? null : PreviewCopy.overview),
      panelOpen: panelOpen,
      hideContentsControl:
          model != null &&
          !model.preview.readmePresent &&
          !isWideWindow(context),
      onOpenOverview: nav.overview,
      onOpenLesson: nav.lesson,
      child: outline.when(
        data: (model) => _CourseBody(
          previewKey: previewKey,
          outline: model,
          resumeLesson: lesson,
          nav: nav,
        ),
        loading: () => const _CourseSkeleton(),
        error: (error, stack) => Padding(
          padding: EdgeInsets.only(top: DcTheme.of(context).style.space(6)),
          child: LoadFailureView(
            failure: error,
            region: LoadRegion.course,
            onRetry: () => ref.invalidate(outlineProvider(previewKey)),
          ),
        ),
      ),
    );
  }
}

class _CourseSkeleton extends StatelessWidget {
  const _CourseSkeleton();

  @override
  Widget build(BuildContext context) {
    final style = DcTheme.of(context).style;
    return Semantics(
      container: true,
      liveRegion: true,
      label: PreviewCopy.loading,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(top: style.space(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: style.space(3),
            children: [
              DcSkeleton(height: style.space(8)),
              DcSkeleton(height: style.space(4)),
              DcSkeleton(height: style.space(4)),
              DcSkeleton(height: style.space(12)),
              for (var i = 0; i < 6; i++) DcSkeleton(height: style.space(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseBody extends ConsumerWidget {
  const _CourseBody({
    required this.previewKey,
    required this.outline,
    required this.resumeLesson,
    required this.nav,
  });

  final PreviewKey previewKey;
  final OutlineModel outline;
  final Lesson? resumeLesson;
  final PreviewNavigation nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final course = outline.course;
    final styles = ReadingStyles.of(
      context,
      locale: localeFromLanguageTag(course.language),
    );
    final environment = ResourceEnvironment(
      host: ref.watch(resourceHostProvider(previewKey)),
      errorBuilder: overviewErrorBuilder,
      styles: styles,
    );
    final hasLessons = outline.lessons.isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.compact;
    final first = hasLessons ? outline.lessons.first : null;
    final target = resumeLesson ?? first;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          headingLevel: 1,
          child: Text(course.title, style: styles.title()),
        ),
        SizedBox(height: style.space(3)),
        Text(course.summary, style: styles.reading),
      ],
    );
    // The cover stands beside the title and summary on a wide window, and
    // gives its room back when there is none, so the title reads first.
    final withCover = wide && CourseCover.isDrawable(course.cover);

    return Padding(
      padding: EdgeInsets.only(
        top: wide ? style.space(6) : style.space(3.5),
        bottom: style.space(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withCover)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CourseCover(cover: course.cover, environment: environment),
                Expanded(child: title),
              ],
            )
          else
            title,
          if (target != null) ...[
            SizedBox(height: style.space(5)),
            DcButton(
              size: DcButtonSize.large,
              onPressed: () => nav.lesson(target),
              child: Text(
                resumeLesson == null
                    ? PreviewCopy.startCourse
                    : PreviewCopy.continueWith(resumeLesson!.title),
              ),
            ),
          ],
          SizedBox(height: style.space(5)),
          _Facts(outline: outline, previewKey: previewKey),
          if (!hasLessons) ...[
            SizedBox(height: style.space(5)),
            const DcAlert(title: Text(PreviewCopy.noLessons)),
            SizedBox(height: style.space(2)),
            DcButton(
              variant: DcButtonVariant.link,
              onPressed: () => context.go(AppRoutes.open),
              child: const Text(PreviewCopy.openAnotherCourse),
            ),
          ],
          SizedBox(height: style.space(6)),
          _Overview(
            previewKey: previewKey,
            outline: outline,
            environment: environment,
            nav: nav,
          ),
        ],
      ),
    );
  }
}

/// The overview: the root README, or the notice that there is none.
class _Overview extends ConsumerWidget {
  const _Overview({
    required this.previewKey,
    required this.outline,
    required this.environment,
    required this.nav,
  });

  final PreviewKey previewKey;
  final OutlineModel outline;
  final ResourceEnvironment environment;
  final PreviewNavigation nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = DcTheme.of(context).style;
    if (!outline.preview.readmePresent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: style.space(4),
        children: [
          const DcAlert(title: Text(PreviewCopy.noOverview)),
          // On a single column the outline shows here, because the Contents
          // control is hidden (S5).
          if (!isWideWindow(context))
            Semantics(
              container: true,
              explicitChildNodes: true,
              role: SemanticsRole.navigation,
              label: PreviewCopy.contentsNav,
              child: ContentsList(
                outline: outline,
                selectedLessonId: null,
                placeLessonId: null,
                placeIsCurrent: false,
                onOpenOverview: nav.overview,
                onOpenLesson: nav.lesson,
              ),
            ),
        ],
      );
    }
    final readme = ref.watch(readmeProvider(previewKey));
    return readme.when(
      data: (source) => MarkdownView(
        source: source,
        environment: environment,
        basePath: 'README.md',
        // The page's own title is above; the README's first heading is not
        // drawn again when it says the same.
        hideLeadingTitle: outline.course.title,
      ),
      loading: SkeletonLines.new,
      // A README over the size limit is refused while it is read; the rest of
      // the page stays usable.
      error: (error, stack) => error is ResourceTooLarge
          ? const DcAlert(title: Text(PreviewCopy.overviewTooLarge))
          : LoadFailureView(
              failure: error,
              region: LoadRegion.overview,
              onRetry: () => ref.invalidate(readmeProvider(previewKey)),
            ),
    );
  }
}

/// Authors, level, time, language and license as labelled pairs.
class _Facts extends StatelessWidget {
  const _Facts({required this.outline, required this.previewKey});

  final OutlineModel outline;
  final PreviewKey previewKey;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final course = outline.course;
    final showTime =
        outline.preview.outline.display?.showEstimatedDuration != false;
    final rows = <(String, Widget)>[
      if (course.authors?.isNotEmpty ?? false)
        (
          PreviewCopy.authors,
          _Authors(authors: course.authors!, previewKey: previewKey),
        ),
      if (course.level != null)
        (PreviewCopy.level, Text(PreviewCopy.levelName(course.level!))),
      if (showTime && course.estimatedMinutes != null)
        (PreviewCopy.time, Text(PreviewCopy.about(course.estimatedMinutes!))),
      (PreviewCopy.language, Text(PreviewCopy.languageName(course.language))),
      if (course.license != null && course.license!.isNotEmpty)
        (PreviewCopy.license, Text(course.license!)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.style.space(1),
      children: [
        for (final (label, value) in rows)
          MergeSemantics(
            child: Wrap(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label, style: metaTextStyle(theme)),
                ),
                DefaultTextStyle.merge(
                  style: metaTextStyle(theme)
                      .copyWith(color: theme.colors.foreground),
                  child: value,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Authors extends ConsumerWidget {
  const _Authors({required this.authors, required this.previewKey});

  final List<OutlineAuthor> authors;
  final PreviewKey previewKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DcTheme.of(context);
    final link = LectaleColors.of(context).link;
    final spans = <InlineSpan>[];
    for (final (index, author) in authors.indexed) {
      if (index > 0) {
        spans.add(const TextSpan(text: ', '));
      }
      final target = classifyLink(author.url);
      if (target is ExternalLink) {
        spans
          ..add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InlineLink(
                text: author.name,
                semanticLabel: ViewerCopy.externalLinkName(author.name),
                style: metaTextStyle(theme).copyWith(color: link),
                onPressed: () =>
                    ref.read(resourceHostProvider(previewKey)).open(target.uri),
              ),
            ),
          )
          // The host is shown before the link is opened, so a name can't pass
          // for another site (threat 5.6).
          ..add(
            TextSpan(
              text: ' (${target.uri.host})',
              style: metaTextStyle(theme),
            ),
          );
      } else {
        spans.add(TextSpan(text: author.name));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }
}
