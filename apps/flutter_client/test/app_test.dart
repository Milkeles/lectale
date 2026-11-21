import 'package:flutter_test/flutter_test.dart';
import 'package:lectale/src/app.dart';

void main() {
  testWidgets('the app shell renders and meets text contrast', (tester) async {
    await tester.pumpWidget(const LectaleApp());

    expect(find.text('Lectale'), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
