import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/pages/settings_page.dart';

void main() {
  testWidgets('settings page no longer shows the Gemini Nano demo entry', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download Base Folder'), findsOneWidget);
    expect(find.text('Gemini Nano Demo'), findsNothing);
  });
}
