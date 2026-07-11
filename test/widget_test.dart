import 'package:flutter_test/flutter_test.dart';

import 'package:sabuflix/main.dart';

void main() {
  testWidgets('App renders root shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SabuFlixApp());
    await tester.pump();
    expect(find.byType(SabuFlixApp), findsOneWidget);
  });
}
