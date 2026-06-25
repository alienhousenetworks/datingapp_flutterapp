import 'package:flutter_test/flutter_test.dart';
import 'package:spicy/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SpyceApp());

    // Verify that the splash screen shows branding subtitle
    expect(find.text('find your connection'), findsOneWidget);
  });
}
