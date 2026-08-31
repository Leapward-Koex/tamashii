import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/pages/settings_page.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('shows Android data-policy controls with stable keys', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': false,
      'allow_mobile_data': false,
      'allow_metered_downloads': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SettingsPage(platform: TargetPlatform.android)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download Base Folder'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('allowMobileDataSwitch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('allowMeteredDownloadsSwitch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('transferPolicyStatus')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey<String>('allowMobileDataSwitch')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey<String>('allowMeteredDownloadsSwitch')),
          )
          .value,
      isFalse,
    );
    expect(
      find.text('Network cost unknown; downloads allowed'),
      findsOneWidget,
    );
    expect(find.text('Gemini Nano Demo'), findsNothing);
  });

  testWidgets('hides Android-only data-policy controls on Windows', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auto_generate_folders': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SettingsPage(platform: TargetPlatform.windows)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('allowMobileDataSwitch')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('allowMeteredDownloadsSwitch')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('transferPolicyStatus')),
      findsNothing,
    );
  });
}
