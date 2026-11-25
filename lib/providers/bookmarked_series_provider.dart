import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';

part 'bookmarked_series_provider.g.dart';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
@riverpod
class BookmarkedSeriesNotifier extends _$BookmarkedSeriesNotifier {
  static const String _storageKey = 'bookmarked_series';
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<List<BookmarkedShowInfo>> build() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> rawList =
        preferences.getStringList(_storageKey) ?? <String>[];
    final List<BookmarkedShowInfo> bookmarks = <BookmarkedShowInfo>[];
    for (final String item in rawList) {
      try {
        final Map<String, dynamic> json = jsonDecode(item);
        bookmarks.add(BookmarkedShowInfo.fromJson(json));
      } catch (e) {
        // Skip legacy or invalid entries
      }
    }
    return bookmarks;
  }

  /// Add [series] to the bookmarks (if not already present).
  Future<bool> add(BookmarkedShowInfo series) {
    final title = series.showName.trim().toLowerCase();
    return _update((current) {
      final exists = current.any(
        (show) =>
            (series.isManualEntry
                ? show.showName.trim().toLowerCase() == title
                : show.showName == series.showName) ||
            (series.malId != null && show.malId == series.malId),
      );
      return exists ? null : [...current, series];
    });
  }

  /// Remove [showName] from the bookmarks (if present).
  Future<bool> remove(String showName) {
    return _update((current) {
      final updated = current
          .where((show) => show.showName != showName)
          .toList();
      return updated.length == current.length ? null : updated;
    });
  }

  /// Change the schedule day for [showName], if it is currently bookmarked.
  Future<bool> updateReleaseDay(String showName, int releaseDayOfWeek) async {
    RangeError.checkValueInInterval(releaseDayOfWeek, 1, 7, 'releaseDayOfWeek');

    return _update((current) {
      final index = current.indexWhere((show) => show.showName == showName);
      if (index == -1 || current[index].releaseDayOfWeek == releaseDayOfWeek) {
        return null;
      }

      return [...current]
        ..[index] = current[index].copyWith(releaseDayOfWeek: releaseDayOfWeek);
    });
  }

  /// Link a title-only entry to a MyAnimeList ID and cover in place.
  Future<bool> matchManualEntry(
    String showName, {
    required int malId,
    required String imageUrl,
  }) {
    return _update((current) {
      final index = current.indexWhere(
        (show) =>
            show.showName == showName &&
            show.isManualEntry &&
            show.malId == null,
      );
      if (index == -1 || current.any((show) => show.malId == malId)) {
        return null;
      }

      return [...current]
        ..[index] = current[index].copyWith(malId: malId, imageUrl: imageUrl);
    });
  }

  Future<bool> _update(
    List<BookmarkedShowInfo>? Function(List<BookmarkedShowInfo>) update,
  ) {
    final link = ref.keepAlive();
    final result = _pendingWrite
        .then((_) async {
          if (state.isLoading) {
            await future;
          }
          final updated = update(state.requireValue);
          if (updated == null) {
            return false;
          }

          await _save(updated);
          if (ref.mounted) {
            state = AsyncValue.data(updated);
          }
          return true;
        })
        .whenComplete(link.close);
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _save(List<BookmarkedShowInfo> list) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> rawList = list
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    if (!await preferences.setStringList(_storageKey, rawList)) {
      throw StateError('Unable to save your schedule.');
    }
  }
}
