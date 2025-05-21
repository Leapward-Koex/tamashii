// lib/providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// Simple settings model; you can expand this.
class Settings {
  final bool isConfigured;
  Settings({required this.isConfigured});
}

/// Tracks whether the user has completed initial setup.
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Settings build() {
    return Settings(isConfigured: false);
  }

  void configure(Settings newSettings) {
    state = newSettings;
  }
}
