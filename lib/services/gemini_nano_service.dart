import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class OnDeviceModelCatalog {
  const OnDeviceModelCatalog({
    required this.activeModel,
    required this.availableModels,
    required this.featureStatus,
  });

  factory OnDeviceModelCatalog.fromMap(Map<Object?, Object?> map) {
    final available = map['availableModels'] as List<Object?>? ?? const [];
    return OnDeviceModelCatalog(
      activeModel: map['activeModel'] as String?,
      availableModels:
          available
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toList(),
      featureStatus: (map['featureStatus'] as num?)?.toInt(),
    );
  }

  final String? activeModel;
  final List<String> availableModels;
  final int? featureStatus;

  bool get hasUsableModel => availableModels.isNotEmpty;
}

class OnDeviceGenerationResponse {
  const OnDeviceGenerationResponse({
    required this.text,
    required this.modelUsed,
  });

  factory OnDeviceGenerationResponse.fromMap(Map<Object?, Object?> map) {
    return OnDeviceGenerationResponse(
      text: (map['text'] as String? ?? '').trim(),
      modelUsed: map['modelUsed'] as String?,
    );
  }

  final String text;
  final String? modelUsed;
}

abstract class OnDeviceTextGenerator {
  Future<OnDeviceModelCatalog> getModelCatalog();

  Future<OnDeviceGenerationResponse> generateText({required String prompt});
}

class PlatformGeminiNanoService implements OnDeviceTextGenerator {
  const PlatformGeminiNanoService();

  static const MethodChannel _channel = MethodChannel(
    'com.leapwardkoex.tamashii/gemini_nano',
  );

  @override
  Future<OnDeviceModelCatalog> getModelCatalog() async {
    if (!_isAndroidBuild) {
      return const OnDeviceModelCatalog(
        activeModel: null,
        availableModels: <String>[],
        featureStatus: null,
      );
    }

    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'getModelCatalog',
      );
    } on MissingPluginException {
      return const OnDeviceModelCatalog(
        activeModel: null,
        availableModels: <String>[],
        featureStatus: null,
      );
    }

    if (result == null) {
      return const OnDeviceModelCatalog(
        activeModel: null,
        availableModels: <String>[],
        featureStatus: null,
      );
    }

    return OnDeviceModelCatalog.fromMap(result);
  }

  @override
  Future<OnDeviceGenerationResponse> generateText({
    required String prompt,
  }) async {
    if (!_isAndroidBuild) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'Gemini Nano is only wired up on Android builds.',
      );
    }

    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>(
        'generateText',
        <String, Object?>{'prompt': prompt},
      );
    } on MissingPluginException {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'Gemini Nano is only wired up on Android builds.',
      );
    }

    if (result == null) {
      throw PlatformException(
        code: 'empty_response',
        message: 'Gemini Nano returned an empty response.',
      );
    }

    final response = OnDeviceGenerationResponse.fromMap(result);
    if (response.text.isEmpty) {
      throw PlatformException(
        code: 'empty_response',
        message: 'Gemini Nano returned an empty response.',
      );
    }

    return response;
  }

  bool get _isAndroidBuild =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
