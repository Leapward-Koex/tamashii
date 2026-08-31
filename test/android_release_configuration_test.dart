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
}
