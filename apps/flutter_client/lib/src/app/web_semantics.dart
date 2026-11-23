import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// Turns the semantics tree on from the first frame when running on the web,
/// and returns the handle that keeps it on; returns null elsewhere.
///
/// Flutter's web engine picks the DOM element that receives typing the first
/// time a text field takes focus, and never picks again. If that happens
/// before semantics are on (an autofocused field, or one the learner clicks
/// before a screen reader asks for semantics), the engine types into its own
/// unlabelled `<input>` for the rest of the page's life, and the labelled
/// input of the semantics tree is never used (A11Y-003, WCAG 4.1.2). Starting
/// semantics first makes the engine pick the labelled one. A side effect is
/// that the "Enable accessibility" placeholder, which screen-reader users
/// otherwise have to find and activate, is no longer needed.
///
/// [isWeb] is a parameter so a test can reach both branches.
SemanticsHandle? ensureWebSemantics({bool isWeb = kIsWeb}) {
  if (!isWeb) {
    return null;
  }
  return SemanticsBinding.instance.ensureSemantics();
}
