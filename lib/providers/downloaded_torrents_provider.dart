// lib/providers/downloaded_torrents_provider.dart

import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores a set of torrent keys that have completed downloading.
class DownloadedTorrentsNotifier
    extends StateNotifier<AsyncValue<Set<String>>> {
  DownloadedTorrentsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const String _storageKey = 'downloaded_torrents';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> raw = json.decode(jsonString) as List<dynamic>;
        state = AsyncValue.data(raw.cast<String>().toSet());
        return;
      } catch (_) {
        await prefs.remove(_storageKey);
      }
    }
    state = const AsyncValue.data(<String>{});
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
}

final downloadedTorrentsProvider =
    StateNotifierProvider<DownloadedTorrentsNotifier, AsyncValue<Set<String>>>(
      (ref) => DownloadedTorrentsNotifier(),
    );
