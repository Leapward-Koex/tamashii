// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenrai_api_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tenraiApi)
final tenraiApiProvider = TenraiApiProvider._();

final class TenraiApiProvider
    extends $FunctionalProvider<TenraiApi, TenraiApi, TenraiApi>
    with $Provider<TenraiApi> {
  TenraiApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tenraiApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tenraiApiHash();

  @$internal
  @override
  $ProviderElement<TenraiApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TenraiApi create(Ref ref) {
    return tenraiApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TenraiApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TenraiApi>(value),
    );
  }
}

String _$tenraiApiHash() => r'a19706c4b64184e9fa8da9333582891288612f9d';

/// Retain successful searches across navigation and discard transient failures.

@ProviderFor(searchTenraiShows)
final searchTenraiShowsProvider = SearchTenraiShowsFamily._();

/// Retain successful searches across navigation and discard transient failures.

final class SearchTenraiShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TenraiAnimeSearchResult>>,
          List<TenraiAnimeSearchResult>,
          FutureOr<List<TenraiAnimeSearchResult>>
        >
    with
        $FutureModifier<List<TenraiAnimeSearchResult>>,
        $FutureProvider<List<TenraiAnimeSearchResult>> {
  /// Retain successful searches across navigation and discard transient failures.
  SearchTenraiShowsProvider._({
    required SearchTenraiShowsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'searchTenraiShowsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchTenraiShowsHash();

  @override
  String toString() {
    return r'searchTenraiShowsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TenraiAnimeSearchResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TenraiAnimeSearchResult>> create(Ref ref) {
    final argument = this.argument as String;
    return searchTenraiShows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchTenraiShowsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchTenraiShowsHash() => r'b4a27eda707a82d1804dd79a7b65f93145686754';

/// Retain successful searches across navigation and discard transient failures.

final class SearchTenraiShowsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<TenraiAnimeSearchResult>>,
          String
        > {
  SearchTenraiShowsFamily._()
    : super(
        retry: _noRetry,
        name: r'searchTenraiShowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Retain successful searches across navigation and discard transient failures.

  SearchTenraiShowsProvider call(String query) =>
      SearchTenraiShowsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchTenraiShowsProvider';
}

@ProviderFor(catalogEntryById)
final catalogEntryByIdProvider = CatalogEntryByIdFamily._();

final class CatalogEntryByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<TenraiAnimeSearchResult?>,
          TenraiAnimeSearchResult?,
          FutureOr<TenraiAnimeSearchResult?>
        >
    with
        $FutureModifier<TenraiAnimeSearchResult?>,
        $FutureProvider<TenraiAnimeSearchResult?> {
  CatalogEntryByIdProvider._({
    required CatalogEntryByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: _noRetry,
         name: r'catalogEntryByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$catalogEntryByIdHash();

  @override
  String toString() {
    return r'catalogEntryByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TenraiAnimeSearchResult?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TenraiAnimeSearchResult?> create(Ref ref) {
    final argument = this.argument as int;
    return catalogEntryById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogEntryByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$catalogEntryByIdHash() => r'232396f1db77d8ac0cea41152e12a9e4fc700641';

final class CatalogEntryByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TenraiAnimeSearchResult?>, int> {
  CatalogEntryByIdFamily._()
    : super(
        retry: _noRetry,
        name: r'catalogEntryByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CatalogEntryByIdProvider call(int malId) =>
      CatalogEntryByIdProvider._(argument: malId, from: this);

  @override
  String toString() => r'catalogEntryByIdProvider';
}

@ProviderFor(featuredTenraiPoster)
final featuredTenraiPosterProvider = FeaturedTenraiPosterFamily._();

final class FeaturedTenraiPosterProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  FeaturedTenraiPosterProvider._({
    required FeaturedTenraiPosterFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'featuredTenraiPosterProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$featuredTenraiPosterHash();

  @override
  String toString() {
    return r'featuredTenraiPosterProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return featuredTenraiPoster(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FeaturedTenraiPosterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$featuredTenraiPosterHash() =>
    r'f013e7e7a99892b554893a3ee351afa674a8b4d6';

final class FeaturedTenraiPosterFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  FeaturedTenraiPosterFamily._()
    : super(
        retry: _noRetry,
        name: r'featuredTenraiPosterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeaturedTenraiPosterProvider call(String showTitle) =>
      FeaturedTenraiPosterProvider._(argument: showTitle, from: this);

  @override
  String toString() => r'featuredTenraiPosterProvider';
}
