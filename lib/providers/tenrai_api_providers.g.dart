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
