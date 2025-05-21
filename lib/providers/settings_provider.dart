import 'dart:async';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.g.dart';

/// Whether to auto-generate subfolders for each series.
@riverpod
class AutoGenerateFoldersNotifier extends _$AutoGenerateFoldersNotifier {
  static const _key = 'auto_generate_folders';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  /// Toggle auto-generate setting.
  Future<void> setAutoGenerate(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// The base folder path where series subfolders are created.
@riverpod
class DownloadBasePathNotifier extends _$DownloadBasePathNotifier {
  static const _key = 'download_base_path';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? '';
  }

  /// Set the base download folder.
  Future<void> setBasePath(String path) async {
    state = AsyncValue.data(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
}

/// Mapping of series → custom folder path for episodes.
@riverpod
class SeriesFolderMappingNotifier extends _$SeriesFolderMappingNotifier {
  static const _key = 'series_folder_mapping';

  @override
  Future<Map<String, String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null && jsonString.isNotEmpty) {
      final Map<String, dynamic> raw = json.decode(jsonString) as Map<String, dynamic>;
      return raw.map((key, value) => MapEntry(key, value as String));
    }
    return <String, String>{};
  }

  /// Assign a custom folder for a series.
  Future<void> setFolder(String series, String path) async {
    final current = state.value ?? <String, String>{};
    final updated = {...current, series: path};
    state = AsyncValue.data(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(updated));
  }
}
