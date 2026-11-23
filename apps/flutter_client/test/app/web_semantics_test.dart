import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app/web_semantics.dart';

void main() {
  testWidgets('on the web, semantics start before any field can take focus', (
    tester,
  ) async {
    final before = tester.binding.debugOutstandingSemanticsHandles;

    final handle = ensureWebSemantics(isWeb: true);

    expect(handle, isNotNull);
    expect(tester.binding.debugOutstandingSemanticsHandles, before + 1);
    handle!.dispose();
    expect(tester.binding.debugOutstandingSemanticsHandles, before);
  });

  testWidgets('elsewhere, semantics stay on demand', (tester) async {
    final before = tester.binding.debugOutstandingSemanticsHandles;

    final handle = ensureWebSemantics(isWeb: false);

    expect(handle, isNull);
    expect(tester.binding.debugOutstandingSemanticsHandles, before);
  });
}
