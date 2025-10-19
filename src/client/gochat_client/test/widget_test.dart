// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:gochat_client/providers/settings_provider.dart';

import 'package:gochat_client/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Create a settings provider for testing
    final settingsProvider = SettingsProvider();
    await settingsProvider.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(settingsProvider: settingsProvider));

    // Verify that the splash screen appears
    expect(find.text('GoChat'), findsOneWidget);
  });
}
