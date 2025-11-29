// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_episodes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages cached episodes from bookmarked series

@ProviderFor(CachedEpisodesNotifier)
const cachedEpisodesProvider = CachedEpisodesNotifierProvider._();

/// Manages cached episodes from bookmarked series
final class CachedEpisodesNotifierProvider
    extends $AsyncNotifierProvider<CachedEpisodesNotifier, List<ShowInfo>> {
  /// Manages cached episodes from bookmarked series
  const CachedEpisodesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cachedEpisodesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cachedEpisodesNotifierHash();

  @$internal
  @override
  CachedEpisodesNotifier create() => CachedEpisodesNotifier();
}

String _$cachedEpisodesNotifierHash() =>
    r'8d410d20ba674c2b8a4922c2fc28cce84edab4d9';

/// Manages cached episodes from bookmarked series

abstract class _$CachedEpisodesNotifier extends $AsyncNotifier<List<ShowInfo>> {
  FutureOr<List<ShowInfo>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<ShowInfo>>, List<ShowInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ShowInfo>>, List<ShowInfo>>,
              AsyncValue<List<ShowInfo>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Combined provider that merges API data with cached episodes

@ProviderFor(combinedEpisodes)
const combinedEpisodesProvider = CombinedEpisodesFamily._();

/// Combined provider that merges API data with cached episodes

final class CombinedEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShowInfo>>,
          List<ShowInfo>,
          FutureOr<List<ShowInfo>>
        >
    with $FutureModifier<List<ShowInfo>>, $FutureProvider<List<ShowInfo>> {
  /// Combined provider that merges API data with cached episodes
  const CombinedEpisodesProvider._({
    required CombinedEpisodesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'combinedEpisodesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$combinedEpisodesHash();

  @override
  String toString() {
    return r'combinedEpisodesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ShowInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ShowInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return combinedEpisodes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CombinedEpisodesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$combinedEpisodesHash() => r'b3afc4340ae526296fa0bc9f9fb201897f197e19';

/// Combined provider that merges API data with cached episodes

final class CombinedEpisodesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  const CombinedEpisodesFamily._()
    : super(
        retry: null,
        name: r'combinedEpisodesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Combined provider that merges API data with cached episodes

  CombinedEpisodesProvider call(String searchTerm) =>
      CombinedEpisodesProvider._(argument: searchTerm, from: this);

  @override
  String toString() => r'combinedEpisodesProvider';
}

/// Filtered combined episodes provider (replaces the existing filteredShows)

@ProviderFor(filteredCombinedEpisodes)
const filteredCombinedEpisodesProvider = FilteredCombinedEpisodesFamily._();

/// Filtered combined episodes provider (replaces the existing filteredShows)

final class FilteredCombinedEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShowInfo>>,
          List<ShowInfo>,
          FutureOr<List<ShowInfo>>
        >
    with $FutureModifier<List<ShowInfo>>, $FutureProvider<List<ShowInfo>> {
  /// Filtered combined episodes provider (replaces the existing filteredShows)
  const FilteredCombinedEpisodesProvider._({
    required FilteredCombinedEpisodesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'filteredCombinedEpisodesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredCombinedEpisodesHash();

  @override
  String toString() {
    return r'filteredCombinedEpisodesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ShowInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ShowInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return filteredCombinedEpisodes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredCombinedEpisodesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredCombinedEpisodesHash() =>
    r'baf678233abfe3e1644dd65b77efbfe5b9e93b1c';

/// Filtered combined episodes provider (replaces the existing filteredShows)

final class FilteredCombinedEpisodesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  const FilteredCombinedEpisodesFamily._()
    : super(
        retry: null,
        name: r'filteredCombinedEpisodesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Filtered combined episodes provider (replaces the existing filteredShows)

  FilteredCombinedEpisodesProvider call(String searchTerm) =>
      FilteredCombinedEpisodesProvider._(argument: searchTerm, from: this);

  @override
  String toString() => r'filteredCombinedEpisodesProvider';
}
