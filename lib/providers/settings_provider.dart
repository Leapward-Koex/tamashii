import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/services/transfer_policy.dart';

part 'settings_provider.g.dart';

// Construct on demand so every read reaches the current platform store and
// background-engine/test platform instances are never captured accidentally.
SharedPreferencesAsync get _preferences => SharedPreferencesAsync();

/// Whether to auto-generate subfolders for each series.
@riverpod
class AutoGenerateFolders extends _$AutoGenerateFolders {
  static const _key = 'auto_generate_folders';

  @override
  Future<bool> build() async {
    return await _preferences.getBool(_key) ?? true;
  }

  /// Toggle auto-generate setting.
  Future<void> setAutoGenerate(bool value) async {
    state = AsyncValue.data(value);
    await _preferences.setBool(_key, value);
  }
}

/// The base folder path where series subfolders are created.
@riverpod
class DownloadBasePath extends _$DownloadBasePath {
  static const _key = 'download_base_path';

  @override
  Future<String> build() async {
    return await _preferences.getString(_key) ?? '';
  }

  /// Set the base download folder.
  Future<void> setBasePath(String path) async {
    state = AsyncValue.data(path);
    await _preferences.setString(_key, path);
  }
}

/// Mapping of series → custom folder path for episodes.
@riverpod
class SeriesFolderMapping extends _$SeriesFolderMapping {
  static const _key = 'series_folder_mapping';
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<Map<String, String>> build() async {
    final jsonString = await _preferences.getString(_key);
    if (jsonString != null && jsonString.isNotEmpty) {
      final Map<String, dynamic> raw =
          json.decode(jsonString) as Map<String, dynamic>;
      return raw.map((key, value) => MapEntry(key, value as String));
    }
    return <String, String>{};
  }

  /// Assign a custom folder for a series.
  Future<void> setFolder(String series, String path) {
    return _update((current) => {...current, series: path});
  }

  /// Remove mapping for a series and persist.
  Future<void> removeFolder(String series) {
    return _update((current) {
      if (!current.containsKey(series)) {
        return null;
      }
      return Map<String, String>.of(current)..remove(series);
    });
  }

  Future<void> _update(
    Map<String, String>? Function(Map<String, String>) update,
  ) {
    final link = ref.keepAlive();
    final result = _pendingWrite
        .then((_) async {
          if (state.isLoading) {
            await future;
          }
          final updated = update(state.requireValue);
          if (updated == null) {
            return;
          }

          await _preferences.setString(_key, json.encode(updated));
          if (ref.mounted) {
            state = AsyncValue.data(updated);
          }
        })
        .whenComplete(link.close);
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

/// Whether downloads may continue on networks Android marks as metered.
@Riverpod(keepAlive: true)
class AllowMeteredDownloads extends _$AllowMeteredDownloads {
  @override
  Future<bool> build() async {
    return await _preferences.getBool(allowMeteredDownloadsPreferenceKey) ??
        false;
  }

  Future<void> setAllowed(bool value) async {
    await _preferences.setBool(allowMeteredDownloadsPreferenceKey, value);
    state = AsyncValue.data(value);
  }
}

/// Whether downloads may continue over an Android cellular transport.
///
/// This is intentionally separate from Android's metered-network flag because
/// a VPN can otherwise obscure whether its underlying network is cellular.
@Riverpod(keepAlive: true)
class AllowMobileData extends _$AllowMobileData {
  @override
  Future<bool> build() async {
    return await _preferences.getBool(allowMobileDataPreferenceKey) ?? false;
  }

  Future<void> setAllowed(bool value) async {
    await _preferences.setBool(allowMobileDataPreferenceKey, value);
    state = AsyncValue.data(value);
  }
}
