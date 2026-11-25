// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmarked_series_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.

@ProviderFor(BookmarkedSeriesNotifier)
final bookmarkedSeriesProvider = BookmarkedSeriesNotifierProvider._();

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
final class BookmarkedSeriesNotifierProvider
    extends
        $AsyncNotifierProvider<
          BookmarkedSeriesNotifier,
          List<BookmarkedShowInfo>
        > {
  /// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
  BookmarkedSeriesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkedSeriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkedSeriesNotifierHash();

  @$internal
  @override
  BookmarkedSeriesNotifier create() => BookmarkedSeriesNotifier();
}

String _$bookmarkedSeriesNotifierHash() =>
    r'2aae0bcf5117acebcee17e3a1090b58a174754ce';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.

abstract class _$BookmarkedSeriesNotifier
    extends $AsyncNotifier<List<BookmarkedShowInfo>> {
  FutureOr<List<BookmarkedShowInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<BookmarkedShowInfo>>,
              List<BookmarkedShowInfo>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<BookmarkedShowInfo>>,
                List<BookmarkedShowInfo>
              >,
              AsyncValue<List<BookmarkedShowInfo>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
