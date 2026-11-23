import 'package:devchat_ui/devchat_ui.dart';
import 'package:flutter/widgets.dart';

/// The style of instructional metadata: a module line, a file's kind and size,
/// a fact's label. Plex Sans at 14 on 20, muted; [strong] sets it in the
/// foreground color and a medium weight, for a label that has to be found
/// (design review, Codex §2.9).
TextStyle metaTextStyle(DcThemeData theme, {bool strong = false}) =>
    theme.typography.body.copyWith(
      fontSize: 14,
      height: 20 / 14,
      color: strong ? theme.colors.foreground : theme.colors.mutedForeground,
      fontWeight: strong ? theme.typography.medium : theme.typography.regular,
    );
