// lib/providers/downloaded_torrents_provider.dart

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'downloaded_torrents_provider.g.dart';

/// Stores a set of torrent keys that have completed downloading.
@riverpod
class DownloadedTorrentsNotifier extends _$DownloadedTorrentsNotifier {
  static const String _storageKey = 'downloaded_torrents';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> raw = json.decode(jsonString) as List<dynamic>;
        return raw.cast<String>().toSet();
      } catch (_) {
        await prefs.remove(_storageKey);
      }
    }
    return <String>{};
  }

  Future<void> _save(Set<String> set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(set.toList()));
  }

  Future<void> addDownloaded(String torrentKey) async {
    final current = state.value ?? <String>{};
    if (current.contains(torrentKey)) return;
    final updated = {...current, torrentKey};
    state = AsyncValue.data(updated);
    await _save(updated);
  }

  Future<void> removeDownloaded(String torrentKey) async {
    final current = state.value ?? <String>{};
    if (!current.contains(torrentKey)) return;
    final updated = Set<String>.from(current)..remove(torrentKey);
    state = AsyncValue.data(updated);
    await _save(updated);
  }

  /// Remove all torrent keys that correspond to [showId] prefix.
  Future<void> removeByShow(String showId) async {
    final current = state.value ?? <String>{};
    final updated = current.where((k) => !k.startsWith('$showId-')).toSet();
    state = AsyncValue.data(updated);
    await _save(updated);
  }
}
