import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spicy/main.dart';
import 'package:spicy/screens/splash/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final channels = [
      'plugins.it_lites.com/flutter_secure_storage',
      'plugins.it-lites.com/flutter_secure_storage',
      'plugins.it-lites.com/flutter_secure_storage_io',
    ];
    for (final channelName in channels) {
      final channel = MethodChannel(channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });
    }
  });

  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(
        onGetStarted: () {},
        onLogin: () {},
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    // Verify that the splash screen shows branding subtitle
    expect(find.text('Already have account? Log in'), findsOneWidget);
  });
}
