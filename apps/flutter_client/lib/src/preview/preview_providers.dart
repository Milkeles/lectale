import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/course/course_providers.dart';
import 'package:lectale/src/course/course_repository.dart';
import 'package:lectale/src/preview/outline_model.dart';
import 'package:lectale/src/preview/preview_host.dart';
import 'package:lectale/src/preview/preview_key.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// Import results held in memory, so a course opened from Home needs no
/// second request (`docs/ux/screens/course.md` §6, "unless the import result
/// is already in memory").
final NotifierProvider<ImportedPreviews, Map<PreviewKey, CoursePreview>>
importedPreviewsProvider =
    NotifierProvider<ImportedPreviews, Map<PreviewKey, CoursePreview>>(
      ImportedPreviews.new,
    );

/// The map behind [importedPreviewsProvider].
class ImportedPreviews extends Notifier<Map<PreviewKey, CoursePreview>> {
  @override
  Map<PreviewKey, CoursePreview> build() => const {};

  /// Remembers [preview] under its own key.
  void put(CoursePreview preview) {
    state = {...state, PreviewKey.of(preview): preview};
  }
}

// A failure is shown with Try again, so Riverpod must not retry by itself:
// the J5 table says when trying again can help.
Duration? _never(int retryCount, Object error) => null;

/// The course at a pinned commit: from memory when Home just imported it,
/// else from `GET /api/preview/{repoId}/{sha}`. A failure is thrown as an
/// `ImportFailure`; `ref.invalidate` loads again (Try again).
// The family's own type is long and says nothing the factory doesn't.
// ignore: specify_nonobvious_property_types
final outlineProvider = FutureProvider.family<OutlineModel, PreviewKey>(
  retry: _never,
  (ref, key) async {
    final known = ref.read(importedPreviewsProvider)[key];
    final preview =
        known ?? await ref.watch(courseRepositoryProvider).preview(key);
    return OutlineModel.of(preview);
  },
);

/// The course's root README.
// ignore: specify_nonobvious_property_types
final readmeProvider = FutureProvider.family<String, PreviewKey>(
  retry: _never,
  (ref, key) => ref.watch(courseRepositoryProvider).readme(key),
);

/// The viewers' host for one pinned course.
// ignore: specify_nonobvious_property_types
final resourceHostProvider = Provider.family<ResourceHost, PreviewKey>(
  (ref, key) => PreviewResourceHost(dio: ref.watch(dioProvider), key: key),
);

/// The lesson last opened in each course during this visit. In memory only:
/// a reading position is not strictly necessary storage, so nothing is kept
/// on the device (`docs/ux/inventory.md`, D11). It drives the ribbon on
/// Course and the "Continue" label of Start course.
final NotifierProvider<LastOpened, Map<PreviewKey, String>> lastOpenedProvider =
    NotifierProvider<LastOpened, Map<PreviewKey, String>>(LastOpened.new);

/// The map behind [lastOpenedProvider].
class LastOpened extends Notifier<Map<PreviewKey, String>> {
  @override
  Map<PreviewKey, String> build() => const {};

  /// Records that [lessonId] was opened in [key].
  void set(PreviewKey key, String lessonId) {
    if (state[key] != lessonId) {
      state = {...state, key: lessonId};
    }
  }
}

/// Whether the Contents pane is open on wide windows. Open by default;
/// remembered for the visit only.
final NotifierProvider<PaneOpen, bool> paneOpenProvider =
    NotifierProvider<PaneOpen, bool>(PaneOpen.new);

/// The flag behind [paneOpenProvider].
class PaneOpen extends Notifier<bool> {
  @override
  bool build() => true;

  /// Opens or closes the pane.
  // The setter-like method reads better at the call site than a property.
  // ignore: use_setters_to_change_properties
  void set({required bool open}) => state = open;
}

/// The scroll position of the Contents pane, kept across Course and Reader
/// (inventory: "The pane keeps its scroll position").
final NotifierProvider<ContentsScroll, double> contentsScrollProvider =
    NotifierProvider<ContentsScroll, double>(ContentsScroll.new);

/// The offset behind [contentsScrollProvider].
class ContentsScroll extends Notifier<double> {
  @override
  double build() => 0;

  /// Remembers [offset].
  // ignore: use_setters_to_change_properties
  void remember(double offset) => state = offset;
}
