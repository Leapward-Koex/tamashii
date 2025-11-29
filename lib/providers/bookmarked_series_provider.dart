import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tamashii/models/show_models.dart';

part 'bookmarked_series_provider.g.dart';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
@riverpod
class BookmarkedSeriesNotifier extends _$BookmarkedSeriesNotifier {
  static const String _storageKey = 'bookmarked_series';

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
  Future<void> add(BookmarkedShowInfo series) async {
    final List<BookmarkedShowInfo> currentList =
        state.value ?? <BookmarkedShowInfo>[];
    if (!currentList.any((s) => s.showName == series.showName)) {
      final List<BookmarkedShowInfo> updatedList = [...currentList, series];
      state = AsyncValue.data(updatedList);
      await _save(updatedList);
    }
  }

  /// Remove [showName] from the bookmarks (if present).
  Future<void> remove(String showName) async {
    final List<BookmarkedShowInfo> currentList =
        state.value ?? <BookmarkedShowInfo>[];
    if (currentList.any((s) => s.showName == showName)) {
      final List<BookmarkedShowInfo> updatedList =
          currentList.where((s) => s.showName != showName).toList();
      state = AsyncValue.data(updatedList);
      await _save(updatedList);
    }
  }

  Future<void> _save(List<BookmarkedShowInfo> list) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> rawList =
        list.map((e) => jsonEncode(e.toJson())).toList();
    await preferences.setStringList(_storageKey, rawList);
  }
}
