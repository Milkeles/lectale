import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The semantics node that has keyboard focus, or null.
SemanticsNode? focusedSemantics(WidgetTester tester) {
  SemanticsNode? found;
  bool visit(SemanticsNode node) {
    if (node.flagsCollection.isFocused == Tristate.isTrue) {
      found = node;
      return false;
    }
    node.visitChildren(visit);
    return found == null;
  }

  final root =
      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  if (root != null) {
    visit(root);
  }
  return found;
}

/// The label of the control with keyboard focus, or null when none has it.
///
/// The focused node can be merged into a parent that carries the label (a
/// link, a field), so the nearest labelled node above it speaks for it.
String? focusedLabel(WidgetTester tester) {
  var node = focusedSemantics(tester);
  while (node != null && node.label.isEmpty) {
    node = node.parent;
  }
  return node?.label;
}

/// Presses Tab once per entry of [expected] and checks, after each press,
/// that the control with keyboard focus has a semantics label starting with
/// that entry. Press Shift+Tab instead with [backwards].
///
/// Screens share it, so their keyboard-order tests read alike
/// (`docs/ux/inventory.md`, "Keyboard: every screen"). The semantics tree
/// must be on (`ensureSemantics`).
Future<void> expectTabOrder(
  WidgetTester tester,
  List<String> expected, {
  bool backwards = false,
}) async {
  for (final label in expected) {
    if (backwards) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    if (backwards) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }
    await tester.pump();
    final focused = focusedLabel(tester);
    expect(
      focused,
      isNotNull,
      reason: 'nothing labelled has focus after the Tab for "$label"',
    );
    expect(focused, startsWith(label));
  }
}
