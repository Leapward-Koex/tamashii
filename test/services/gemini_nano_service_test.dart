import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.leapwardkoex.tamashii/gemini_nano');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parses the native model catalog', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getModelCatalog');
          return <String, Object?>{
            'activeModel': 'gemini-nano',
            'availableModels': <String>['gemini-nano'],
            'featureStatus': 3,
          };
        });

    final catalog = await const PlatformGeminiNanoService().getModelCatalog();

    expect(catalog.activeModel, 'gemini-nano');
    expect(catalog.availableModels, <String>['gemini-nano']);
    expect(catalog.featureStatus, 3);
    expect(catalog.hasUsableModel, isTrue);
  });

  test('treats a native availability exception as unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'error',
            message: 'java.lang.NullPointerException',
            stacktrace: 'at java.util.Objects.requireNonNull',
          );
        });

    final catalog = await const PlatformGeminiNanoService().getModelCatalog();

    expect(catalog.activeModel, isNull);
    expect(catalog.availableModels, isEmpty);
    expect(catalog.featureStatus, isNull);
    expect(catalog.hasUsableModel, isFalse);
  });

  test('treats a missing native handler as unavailable', () async {
    final catalog = await const PlatformGeminiNanoService().getModelCatalog();

    expect(catalog.availableModels, isEmpty);
    expect(catalog.hasUsableModel, isFalse);
  });
}
