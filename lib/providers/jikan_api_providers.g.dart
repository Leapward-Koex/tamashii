// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jikan_api_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(jikanApi)
const jikanApiProvider = JikanApiProvider._();

final class JikanApiProvider
    extends $FunctionalProvider<JikanApi, JikanApi, JikanApi>
    with $Provider<JikanApi> {
  const JikanApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jikanApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jikanApiHash();

  @$internal
  @override
  $ProviderElement<JikanApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JikanApi create(Ref ref) {
    return jikanApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JikanApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JikanApi>(value),
    );
  }
}

String _$jikanApiHash() => r'410124518c8c02f904697fdea385f6218c5ffbc4';

/// Cache Jikan search results per query so rebuilds/navigation do not re-hit
/// the API unless the query actually changes.

@ProviderFor(searchJikanShows)
const searchJikanShowsProvider = SearchJikanShowsFamily._();

/// Cache Jikan search results per query so rebuilds/navigation do not re-hit
/// the API unless the query actually changes.

final class SearchJikanShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JikanAnimeSearchResult>>,
          List<JikanAnimeSearchResult>,
          FutureOr<List<JikanAnimeSearchResult>>
        >
    with
        $FutureModifier<List<JikanAnimeSearchResult>>,
        $FutureProvider<List<JikanAnimeSearchResult>> {
  /// Cache Jikan search results per query so rebuilds/navigation do not re-hit
  /// the API unless the query actually changes.
  const SearchJikanShowsProvider._({
    required SearchJikanShowsFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'searchJikanShowsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchJikanShowsHash();

  @override
  String toString() {
    return r'searchJikanShowsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<JikanAnimeSearchResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<JikanAnimeSearchResult>> create(Ref ref) {
    final argument = this.argument as String;
    return searchJikanShows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchJikanShowsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchJikanShowsHash() => r'e0c80818ff15d3083a7fdfb1a74e7f7b8ec87487';

/// Cache Jikan search results per query so rebuilds/navigation do not re-hit
/// the API unless the query actually changes.

final class SearchJikanShowsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<JikanAnimeSearchResult>>,
          String
        > {
  const SearchJikanShowsFamily._()
    : super(
        retry: _noRetry,
        name: r'searchJikanShowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Cache Jikan search results per query so rebuilds/navigation do not re-hit
  /// the API unless the query actually changes.

  SearchJikanShowsProvider call(String query) =>
      SearchJikanShowsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchJikanShowsProvider';
}
