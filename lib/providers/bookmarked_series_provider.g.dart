// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmarked_series_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookmarkedSeriesNotifierHash() =>
    r'cd98de6e888dd49ebcfccb51e152e62f32cf2d48';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
///
/// Copied from [BookmarkedSeriesNotifier].
@ProviderFor(BookmarkedSeriesNotifier)
final bookmarkedSeriesNotifierProvider = AutoDisposeAsyncNotifierProvider<
  BookmarkedSeriesNotifier,
  List<String>
>.internal(
  BookmarkedSeriesNotifier.new,
  name: r'bookmarkedSeriesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookmarkedSeriesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BookmarkedSeriesNotifier = AutoDisposeAsyncNotifier<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
