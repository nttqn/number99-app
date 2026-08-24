import 'package:flutter_test/flutter_test.dart';

import 'package:number99/main.dart';

void main() {
  testWidgets('App boots to the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(const Number99App());
    await tester.pump();

    expect(find.text('99 NUMBERS'), findsOneWidget);
    expect(find.text('CHƠI NGAY'), findsOneWidget);
  });
}
