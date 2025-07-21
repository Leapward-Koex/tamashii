import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'filter_provider.g.dart';

/// Enum for different filter types
enum ShowFilter {
  all,      // Show all series
  saved,    // Show only bookmarked/saved series
}

/// Provider that manages the current filter state and persists it
@riverpod
class ShowFilterNotifier extends _$ShowFilterNotifier {
  static const String _storageKey = 'show_filter';

  @override
  Future<ShowFilter> build() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? filterString = preferences.getString(_storageKey);
    
    // Default to showing all series
    if (filterString == null) {
      return ShowFilter.all;
    }
    
    // Parse the stored filter
    switch (filterString) {
      case 'saved':
        return ShowFilter.saved;
      case 'all':
      default:
        return ShowFilter.all;
    }
  }

  /// Set the current filter and persist it
  Future<void> setFilter(ShowFilter filter) async {
    state = AsyncValue.data(filter);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, filter.name);
  }

  /// Toggle between all and saved filters
  Future<void> toggleFilter() async {
    final currentFilter = state.value ?? ShowFilter.all;
    final newFilter = currentFilter == ShowFilter.all ? ShowFilter.saved : ShowFilter.all;
    await setFilter(newFilter);
  }
}

/// Extension to provide user-friendly names for filters
extension ShowFilterExtension on ShowFilter {
  String get displayName {
    switch (this) {
      case ShowFilter.all:
        return 'All Series';
      case ShowFilter.saved:
        return 'Saved Series';
    }
  }
  
  IconData get icon {
    switch (this) {
      case ShowFilter.all:
        return Icons.list;
      case ShowFilter.saved:
        return Icons.bookmark;
    }
  }
}
