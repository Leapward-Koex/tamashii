import 'package:flutter/services.dart';

class GeminiNanoService {
  GeminiNanoService._();

  static const MethodChannel _channel = MethodChannel(
    'com.leapwardkoex.tamashii/gemini_nano',
  );

  static Future<String> inferSeason(String text) async {
    final response = await _channel.invokeMethod<String>(
      'inferSeason',
      <String, Object?>{'text': text},
    );

    if (response == null || response.trim().isEmpty) {
      throw PlatformException(
        code: 'empty_response',
        message: 'Gemini Nano returned an empty response.',
      );
    }

    return response;
  }
}
