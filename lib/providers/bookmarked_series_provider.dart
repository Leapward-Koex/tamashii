import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'bookmarked_series_provider.g.dart';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
@riverpod
class BookmarkedSeriesNotifier extends _$BookmarkedSeriesNotifier {
  static const String _storageKey = 'bookmarked_series';

  @override
  Future<List<String>> build() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_storageKey) ?? <String>[];
  }

  /// Add [seriesPage] to the bookmarks (if not already present).
  Future add(String seriesPage) async {
    final List<String> currentList = state.value ?? <String>[];
    if (!currentList.contains(seriesPage)) {
      final List<String> updatedList = [...currentList, seriesPage];
      state = AsyncValue.data(updatedList);
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey, updatedList);
    }
  }

  /// Remove [seriesPage] from the bookmarks (if present).
  Future remove(String seriesPage) async {
    final List<String> currentList = state.value ?? <String>[];
    if (currentList.contains(seriesPage)) {
      final List<String> updatedList = currentList.where((String e) => e != seriesPage).toList();
      state = AsyncValue.data(updatedList);
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey, updatedList);
    }
  }

  /// Toggle the bookmark state of [seriesPage].
  Future toggle(String seriesPage) async {
    final List<String> currentList = state.value ?? <String>[];
    if (currentList.contains(seriesPage)) {
      await remove(seriesPage);
    } else {
      await add(seriesPage);
    }
  }
}
