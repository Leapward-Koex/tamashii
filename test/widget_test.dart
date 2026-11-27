// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/providers/download_queue_provider.dart';

import 'package:tamashii/main.dart';
import 'package:tamashii/theme/paper_lantern.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeDownloadCountProvider.overrideWithValue(0)],
        child: const TamashiiApp(),
      ),
    );

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.scaffoldBackgroundColor, PaperLantern.paper);
    expect(theme.colorScheme.primary, PaperLantern.red);
    expect(theme.textTheme.headlineLarge?.fontFamily, PaperLantern.serif);
  });
}
