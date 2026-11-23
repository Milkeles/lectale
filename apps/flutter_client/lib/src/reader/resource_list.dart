import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lectale/src/preview/preview_copy.dart';
import 'package:lectale/src/widgets/hover_fill.dart';
import 'package:lectale/src/widgets/roving_list.dart';
import 'package:lectale_api_client/lectale_api_client.dart';
import 'package:resource_renderers/resource_renderers.dart';

/// "In this lesson": the files of a lesson with two or more, as rows
/// (reader.md §5). One tab stop with roving focus; the open file is the
/// selected row (Sand, semibold, `selected`), and the ribbon is never used
/// here (S7).
class ResourceList extends StatelessWidget {
  /// Creates the list of [resources] with [selectedId] open.
  const ResourceList({
    required this.resources,
    required this.selectedId,
    required this.onOpen,
    super.key,
  });

  /// The lesson's files.
  final List<OutlineResource> resources;

  /// The ID of the open file.
  final String? selectedId;

  /// Opens a file.
  final ValueChanged<OutlineResource> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DcTheme.of(context);
    final style = theme.style;
    final colors = theme.colors;
    final typography = theme.typography;
    final selectedIndex = resources.indexWhere((r) => r.id.value == selectedId);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: PreviewCopy.inThisLesson,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: style.space(1)),
            child: ExcludeSemantics(
              child: Text(
                PreviewCopy.inThisLesson,
                style: typography.label.copyWith(color: colors.foreground),
              ),
            ),
          ),
          RovingList(
            itemCount: resources.length,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onActivate: (index) => onOpen(resources[index]),
            itemBuilder: (context, index, {required active}) {
              final resource = resources[index];
              final selected = resource.id.value == selectedId;
              return Semantics(
                container: true,
                button: true,
                selected: selected,
                focused: active,
                label: '${resource.title}, ${kindAndSize(resource)}',
                onTap: () => onOpen(resource),
                excludeSemantics: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: style.space(0.5)),
                  child: HoverFill(
                    builder: (context, {required hovered}) => DcFocusRing(
                      visible: active,
                      borderRadius: BorderRadius.circular(style.radiusSmall),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // Sand marks the open file; a lighter Sand under
                          // the pointer shows the others can be opened.
                          color: selected
                              ? colors.muted
                              : hovered
                              ? hoverColor(theme)
                              : null,
                          borderRadius: BorderRadius.circular(
                            style.radiusSmall,
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: style.controlHeights.medium,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: style.space(3),
                              vertical: style.space(1.5),
                            ),
                            // A file list: the title at the start and its
                            // kind and size at the far edge when there is
                            // room; on a phone the title wraps over a second
                            // line.
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final title = Text(
                                  resource.title,
                                  style: typography.body.copyWith(
                                    color: colors.foreground,
                                    fontWeight: selected
                                        ? typography.semibold
                                        : typography.regular,
                                  ),
                                );
                                final meta = Text(
                                  kindAndSize(resource),
                                  style: metaTextStyle(theme),
                                );
                                return constraints.maxWidth >= 420
                                    ? Row(
                                        spacing: style.space(3),
                                        children: [
                                          Expanded(child: title),
                                          meta,
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [title, meta],
                                      );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
