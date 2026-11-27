import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps constructors for reflectively loaded component registrars', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();

    expect(
      rules,
      contains(
        '-keep class * implements '
        'com.google.firebase.components.ComponentRegistrar',
      ),
    );
    expect(rules, contains('public <init>();'));
  });

  test('keeps ONNX Runtime JNI targets in minified Android builds', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();

    expect(rules, contains('-keep class ai.onnxruntime.** { *; }'));
  });

  test('removes ONNX Runtime telemetry from app startup', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(
      manifest,
      matches(
        RegExp(
          r'<provider\s+android:name="ai\.onnxruntime\.TelemetryInitializer"\s+'
          r'tools:node="remove"\s*/>',
        ),
      ),
    );
  });
}
