import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// New completions use independent keys so separate Flutter engines can write
/// different episodes without racing a read/modify/write of the entire list.
const _markerPrefix = 'downloaded_episode.';
const _legacyKey = 'downloaded_torrents';

Future<Set<String>> readDownloadedTorrentKeys() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final legacy = prefs.get(_legacyKey);
  final completed = <String>{};
  if (legacy is String) {
    try {
      final list = jsonDecode(legacy);
      if (list is List) completed.addAll(list.whereType<String>());
    } on FormatException {
      // A malformed old list must not hide valid individual markers.
    }
  }
  for (final marker in prefs.getKeys().where(
    (k) => k.startsWith(_markerPrefix),
  )) {
    final key = marker.substring(_markerPrefix.length);
    if (prefs.get(marker) == true) {
      completed.add(key);
    } else {
      completed.remove(key);
    }
  }
  return completed;
}

Future<void> writeDownloadedTorrentKey(String key, bool downloaded) async {
  final prefs = await SharedPreferences.getInstance();
  if (!await prefs.setBool('$_markerPrefix$key', downloaded)) {
    throw StateError('Could not save download history for $key.');
  }
}
