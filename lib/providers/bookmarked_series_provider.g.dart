// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmarked_series_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.

@ProviderFor(BookmarkedSeriesNotifier)
const bookmarkedSeriesProvider = BookmarkedSeriesNotifierProvider._();

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
final class BookmarkedSeriesNotifierProvider
    extends
        $AsyncNotifierProvider<
          BookmarkedSeriesNotifier,
          List<BookmarkedShowInfo>
        > {
  /// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.
  const BookmarkedSeriesNotifierProvider._()
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
    r'5b979fe6249e4e37948100bef410b78b08a61520';

/// Maintains the list of bookmarked series (by slug/page ID), persisted to storage.

abstract class _$BookmarkedSeriesNotifier
    extends $AsyncNotifier<List<BookmarkedShowInfo>> {
  FutureOr<List<BookmarkedShowInfo>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
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
    element.handleValue(ref, created);
  }
}
