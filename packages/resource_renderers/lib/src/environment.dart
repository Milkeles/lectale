import 'package:flutter/widgets.dart';
import 'package:resource_renderers/src/host.dart';

/// The text styles of course content, supplied by the app so the package
/// does not know the brand colors or the reading face's language rules
/// (ADR-0012).
abstract interface class ContentStyles {
  /// Course text: Source Serif 4 at 18 on 30.
  TextStyle get reading;

  /// The style of heading [level] (1 to 6), semibold in the brand color.
  TextStyle title(int level);

  /// The color of underlined links.
  Color get link;

  /// The language the text is shaped for; null for the platform's.
  Locale? get locale;
}

/// Everything a viewer needs besides the resource itself.
@immutable
class ResourceEnvironment {
  /// Creates the environment.
  const ResourceEnvironment({
    required this.host,
    required this.errorBuilder,
    required this.styles,
    this.headingShift = 1,
  });

  /// Reads the pinned repository and opens addresses.
  final ResourceHost host;

  /// Draws a failure inside the viewer.
  final ResourceErrorBuilder errorBuilder;

  /// The text styles of course content.
  final ContentStyles styles;

  /// How many levels Markdown headings move down: 1 on Course, and on the
  /// Reader 2 when the lesson has a resource h2, else 1 (token plan, heading
  /// map).
  final int headingShift;

  /// The same environment with another [headingShift].
  ResourceEnvironment withHeadingShift(int shift) => ResourceEnvironment(
    host: host,
    errorBuilder: errorBuilder,
    styles: styles,
    headingShift: shift,
  );
}
