import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class _FakeOnDeviceTextGenerator implements OnDeviceTextGenerator {
  _FakeOnDeviceTextGenerator({required this.catalog});

  final OnDeviceModelCatalog catalog;
  int catalogCalls = 0;

  @override
  Future<OnDeviceModelCatalog> getModelCatalog() async {
    catalogCalls += 1;
    return catalog;
  }

  @override
  Future<OnDeviceGenerationResponse> generateText({required String prompt}) {
    throw UnimplementedError();
  }
}

void _setMockPreferences(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('shows Android data-policy controls with stable keys', (
    WidgetTester tester,
  ) async {
    final textGenerator = _FakeOnDeviceTextGenerator(
      catalog: const OnDeviceModelCatalog(
        activeModel: null,
        availableModels: <String>[],
        featureStatus: 0,
      ),
    );
    _setMockPreferences(<String, Object>{
      'auto_generate_folders': false,
      'allow_mobile_data': false,
      'allow_metered_downloads': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDeviceTextGeneratorProvider.overrideWithValue(textGenerator),
        ],
        child: const MaterialApp(
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
    expect(
      find.byKey(const ValueKey<String>('onDeviceAiStatus')),
      findsNothing,
    );
    expect(textGenerator.catalogCalls, 0);
  });

  testWidgets('shows a detected on-device model when folder AI is enabled', (
    WidgetTester tester,
  ) async {
    final textGenerator = _FakeOnDeviceTextGenerator(
      catalog: const OnDeviceModelCatalog(
        activeModel: 'gemini-nano',
        availableModels: <String>['gemini-nano'],
        featureStatus: 3,
      ),
    );
    _setMockPreferences(<String, Object>{
      'auto_generate_folders': true,
      'allow_mobile_data': false,
      'allow_metered_downloads': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDeviceTextGeneratorProvider.overrideWithValue(textGenerator),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsPage(platform: TargetPlatform.android)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('onDeviceAiStatus')),
      findsOneWidget,
    );
    expect(find.text('Detected model: gemini-nano'), findsOneWidget);
    expect(textGenerator.catalogCalls, 1);
  });

  testWidgets('uses a concise fallback when the model check fails', (
    WidgetTester tester,
  ) async {
    final error = PlatformException(
      code: 'error',
      message: 'java.lang.NullPointerException',
    );
    _setMockPreferences(<String, Object>{
      'auto_generate_folders': true,
      'allow_mobile_data': false,
      'allow_metered_downloads': false,
      'download_base_path': '',
      'series_folder_mapping': '{}',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onDeviceModelCatalogProvider.overrideWithValue(
            AsyncValue<OnDeviceModelCatalog>.error(error, StackTrace.current),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsPage(platform: TargetPlatform.android)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statusTile = tester.widget<ListTile>(
      find.byKey(const ValueKey<String>('onDeviceAiStatus')),
    );
    expect(
      (statusTile.subtitle! as Text).data,
      'Unavailable. Folder generation will fall back to plain series names.',
    );
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('NullPointerException'), findsNothing);
  });

  testWidgets('hides Android-only data-policy controls on Windows', (
    WidgetTester tester,
  ) async {
    _setMockPreferences(<String, Object>{
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
