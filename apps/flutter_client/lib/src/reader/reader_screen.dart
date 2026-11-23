import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/app/layout.dart';
import 'package:lectale/src/app/reading_text.dart';
import 'package:lectale/src/preview/load_failure_view.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale/src/preview/preview_navigation.dart';
import 'package:lectale/src/preview/preview_providers.dart';
import 'package:lectale/src/reader/lesson_steps_bar.dart';
import 'package:lectale/src/reader/resource_list.dart';
import 'package:lectale/src/reading/reading_frame.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// Reader: one resource of one lesson or assignment, with the way on
/// (`docs/ux/screens/reader.md`).
///
/// One primary action, Next. The resource is drawn through the registry, so
/// a kind with no viewer shows a card with Download and nothing here changes.
class ReaderScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [resourceId] of [lessonId] in [previewKey].
  const ReaderScreen({
    required this.previewKey,
    required this.lessonId,
    required this.resourceId,
    required this.panelOpen,
    super.key,
  });

  /// The pinned course.
  final PreviewKey previewKey;

  /// The lesson ID, or `assignment~{id}`.
  final String lessonId;

  /// The resource ID, or `-` for a lesson with no files.
  final String resourceId;

  /// Whether the route asks for the Contents panel.
  final bool panelOpen;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final FocusNode _title = FocusNode(debugLabel: 'lesson title');
  final FocusNode _resourceTitle = FocusNode(debugLabel: 'resource title');

  @override
  void initState() {
    super.initState();
    // After Next, Previous or a choice in the lesson, focus goes to the new
    // heading; a plain open leaves focus at the start of the page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Read after the build: a provider can't change during one.
      final request = ref.read(pendingReaderFocusProvider.notifier).take();
      ref
          .read(lastOpenedProvider.notifier)
          .set(widget.previewKey, widget.lessonId);
      switch (request) {
        case ReaderFocusTarget.lessonTitle:
          _title.requestFocus();
        case ReaderFocusTarget.resourceTitle:
          (_resourceTitle.context != null ? _resourceTitle : _title)
              .requestFocus();
        case null:
          break;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _resourceTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.previewKey;
    final outline = ref.watch(outlineProvider(key));
    final model = outline.value;
    final nav = PreviewNavigation(
      context,
      ref,
      key,
      panelOpen: widget.panelOpen,
    );
    final lesson = model?.lesson(widget.lessonId);
    return ReadingFrame(
      outline: model,
      selectedLessonId: lesson?.id,
      placeLessonId: lesson?.id,
      placeIsCurrent: true,
      placeTitle: lesson?.title,
      panelOpen: widget.panelOpen,
      onOpenOverview: nav.overview,
      onOpenLesson: (next) =>
          nav.lesson(next, currentLessonId: widget.lessonId),
      child: outline.when(
        data: (model) => lesson == null
            ? _NotInCourse(nav: nav)
            : _Lesson(
                previewKey: key,
                outline: model,
                lesson: lesson,
                resourceId: widget.resourceId,
                titleNode: _title,
                resourceTitleNode: _resourceTitle,
                nav: nav,
              ),
        loading: () => const _ReaderSkeleton(),
        error: (error, stack) => Padding(
          padding: EdgeInsets.only(top: DcTheme.of(context).style.space(6)),
          child: LoadFailureView(
            failure: error,
            region: LoadRegion.course,
            onRetry: () => ref.invalidate(outlineProvider(key)),
          ),
        ),
      ),
    );
  }
}

class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

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
              for (var i = 0; i < 8; i++) DcSkeleton(height: style.space(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotInCourse extends StatelessWidget {
  const _NotInCourse({required this.nav});

  final PreviewNavigation nav;

  @override
  Widget build(BuildContext context) {
    final style = DcTheme.of(context).style;
    return Padding(
      padding: EdgeInsets.only(top: style.space(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: style.space(3),
        children: [
          const DcAlert(title: Text(PreviewCopy.lessonNotInCourse)),
          DcButton(
            variant: DcButtonVariant.link,
            onPressed: nav.overview,
            child: const Text(PreviewCopy.openOverview),
          ),
        ],
      ),
    );
  }
}

class _Lesson extends ConsumerWidget {
  const _Lesson({
    required this.previewKey,
    required this.outline,
    required this.lesson,
    required this.resourceId,
    required this.titleNode,
    required this.resourceTitleNode,
    required this.nav,
  });

  final PreviewKey previewKey;
  final OutlineModel outline;
  final Lesson lesson;
  final String resourceId;
  final FocusNode titleNode;
  final FocusNode resourceTitleNode;
  final PreviewNavigation nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final typography = theme.typography;
    final colors = theme.colors;
    final step = outline.step(lesson.id, resourceId);
    final resource = step?.resource;
    final hasSeveral = lesson.resources.length >= 2;
    final styles = ReadingStyles.of(
      context,
      locale: localeFromLanguageTag(
        resource?.language ?? outline.course.language,
      ),
    );
    final registry = ResourceRendererRegistry.standard();
    final environment = ResourceEnvironment(
      host: ref.watch(resourceHostProvider(previewKey)),
      errorBuilder: fileErrorBuilder,
      styles: styles,
      // The h2 of the resource, when there is one, pushes Markdown headings
      // down a second level (token plan, heading map).
      headingShift: hasSeveral ? 2 : 1,
    );
    final showDownloads =
        outline.preview.outline.display?.showFileDownloads != false;
    final dates = [
      if (lesson.openAt != null) PreviewCopy.opens(lesson.openAt!),
      if (lesson.dueAt != null) PreviewCopy.due(lesson.dueAt!),
      if (lesson.closeAt != null) PreviewCopy.closes(lesson.closeAt!),
    ];
    final description = lesson.description;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).width < Breakpoints.compact
            ? style.space(3.5)
            : style.space(6),
        bottom: style.space(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson.moduleTitle != null) ...[
            Text(
              lesson.moduleTitle!,
              style: metaTextStyle(theme, strong: true),
            ),
            SizedBox(height: style.space(1)),
          ],
          Semantics(
            container: true,
            header: true,
            headingLevel: 1,
            child: Focus(
              focusNode: titleNode,
              skipTraversal: true,
              child: Text(lesson.title, style: styles.title()),
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            SizedBox(height: style.space(2)),
            Text(description, style: styles.reading),
          ],
          if (lesson.isAssignment) ...[
            SizedBox(height: style.space(3)),
            for (final date in dates)
              Text(
                date,
                style: typography.small.copyWith(color: colors.foreground),
              ),
            SizedBox(height: style.space(1)),
            Text(
              PreviewCopy.assignmentNote,
              style: typography.small.copyWith(color: colors.mutedForeground),
            ),
          ],
          SizedBox(height: style.space(5)),
          if (hasSeveral) ...[
            ResourceList(
              resources: lesson.resources,
              selectedId: resource?.id.value,
              onOpen: (next) {
                if (step != null) {
                  nav.step(step, ReadingStep(lesson, next));
                }
              },
            ),
            SizedBox(height: style.space(5)),
            if (resource != null)
              Semantics(
                container: true,
                header: true,
                headingLevel: 2,
                child: Focus(
                  focusNode: resourceTitleNode,
                  skipTraversal: true,
                  child: Text(resource.title, style: styles.title(2)),
                ),
              ),
            SizedBox(height: style.space(2)),
          ],
          if (resource == null)
            Text(
              step == null
                  ? PreviewCopy.lessonNotInCourse
                  : PreviewCopy.emptyLesson,
              style: styles.reading,
            )
          else ...[
            if (showDownloads &&
                registry.offersBarDownload(resource) &&
                resource.href != null)
              _DownloadBar(resource: resource, environment: environment),
            SizedBox(height: style.space(4)),
            // A new file is a new viewer, so it loads from the start.
            KeyedSubtree(
              key: ValueKey('${lesson.id}/${resource.id.value}'),
              child: registry.build(context, resource, environment),
            ),
          ],
          SizedBox(height: style.space(8)),
          if (step != null)
            LessonStepsBar(outline: outline, step: step, nav: nav),
        ],
      ),
    );
  }
}

class _DownloadBar extends StatelessWidget {
  const _DownloadBar({required this.resource, required this.environment});

  final OutlineResource resource;
  final ResourceEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final name = resourceFileName(resource);
    // File name and kind lead; Download sits at the trailing edge of the same
    // row, and the details wrap as a unit on a narrow screen.
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.typography.code.copyWith(
            color: theme.colors.foreground,
            fontWeight: theme.typography.semibold,
          ),
        ),
        Text(kindAndSize(resource), style: metaTextStyle(theme)),
      ],
    );
    final download = DownloadButton(
      host: environment.host,
      target: ApiHref(resource.href!),
      fileName: name,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 360
          ? Row(
              spacing: theme.style.space(3),
              children: [
                Expanded(child: details),
                download,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.style.space(2),
              children: [details, download],
            ),
    );
  }
}
