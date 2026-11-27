import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

part 'bookmarked_series_provider.g.dart';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
@riverpod
class BookmarkedSeriesNotifier extends _$BookmarkedSeriesNotifier {
  static const String _storageKey = 'bookmarked_series';
  Future<void> _pendingWrite = Future<void>.value();

  @override
  Future<List<BookmarkedShowInfo>> build() async {
    ref.listen(catalogMatchOverridesProvider, (_, next) {
      final choices = next.asData?.value;
      final current = state.asData?.value;
      if (choices == null || current == null) return;
      final updated = [for (final show in current) _effective(show, choices)];
      if (!listEquals(current, updated)) state = AsyncData(updated);
    });
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
    final choices = await ref.read(catalogMatchOverridesProvider.future);
    return [for (final show in bookmarks) _effective(show, choices)];
  }

  BookmarkedShowInfo _effective(
    BookmarkedShowInfo show,
    Map<String, TenraiAnimeSearchResult?> choices,
  ) {
    if (!show.isManualEntry) return show;
    final key = ShowCatalogTarget.fromSchedule(show).scopeKey;
    if (!choices.containsKey(key)) return show;
    final entry = choices[key];
    return show.copyWith(malId: entry?.malId, imageUrl: entry?.imageUrl ?? '');
  }

  /// Add [series] to the bookmarks (if not already present).
  Future<bool> add(BookmarkedShowInfo series) {
    return _update((current) {
      final effective = _effective(
        series,
        ref.read(catalogMatchOverridesProvider).requireValue,
      );
      final title = effective.showName.trim().toLowerCase();
      final exists = current.any(
        (show) =>
            (series.isManualEntry
                ? show.showName.trim().toLowerCase() == title
                : show.showName == series.showName) ||
            (effective.malId != null && show.malId == effective.malId),
      );
      return exists ? null : [...current, effective];
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
  ) => _serialize(() async {
    final updated = update(await future);
    if (updated == null) return false;
    await _save(updated);
    if (ref.mounted) state = AsyncValue.data(updated);
    return true;
  });

  /// A manual correction and a concurrent addition must see each other's MAL
  /// IDs. Only existing manual bookmark corrections enter this write queue.
  Future<void> saveCatalogChoice(
    ShowCatalogTarget target,
    TenraiAnimeSearchResult? entry,
  ) async {
    final choices = ref.read(catalogMatchOverridesProvider.notifier);
    bool isTarget(BookmarkedShowInfo show) =>
        show.isManualEntry &&
        ShowCatalogTarget.fromSchedule(show).scopeKey == target.scopeKey;
    if (target.isReleaseScoped ||
        target.episode != null &&
            entry != null &&
            catalogEntryIsSpecial(entry) ||
        !(await future).any(isTarget)) {
      return choices.save(target, entry);
    }
    return _serialize(() async {
      final current = await future;
      if (entry != null &&
          current.any(isTarget) &&
          current.any((show) => !isTarget(show) && show.malId == entry.malId)) {
        throw const DuplicateScheduleMatch();
      }
      await choices.save(target, entry);
    });
  }

  Future<T> _serialize<T>(Future<T> Function() write) {
    final link = ref.keepAlive();
    final result = _pendingWrite.then((_) => write()).whenComplete(link.close);
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

class DuplicateScheduleMatch implements Exception {
  const DuplicateScheduleMatch();
  @override
  String toString() => 'That catalog entry is already on your schedule.';
}
