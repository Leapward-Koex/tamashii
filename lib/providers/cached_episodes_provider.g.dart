// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_episodes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages cached episodes from bookmarked series

@ProviderFor(CachedEpisodesNotifier)
final cachedEpisodesProvider = CachedEpisodesNotifierProvider._();

/// Manages cached episodes from bookmarked series
final class CachedEpisodesNotifierProvider
    extends $AsyncNotifierProvider<CachedEpisodesNotifier, List<ShowInfo>> {
  /// Manages cached episodes from bookmarked series
  CachedEpisodesNotifierProvider._()
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
    r'38a7fd2ecee35937508ca7b9005143c4c5bf41d1';

/// Manages cached episodes from bookmarked series

abstract class _$CachedEpisodesNotifier extends $AsyncNotifier<List<ShowInfo>> {
  FutureOr<List<ShowInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ShowInfo>>, List<ShowInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ShowInfo>>, List<ShowInfo>>,
              AsyncValue<List<ShowInfo>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Combined provider that merges API data with cached episodes

@ProviderFor(combinedEpisodes)
final combinedEpisodesProvider = CombinedEpisodesFamily._();

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
  CombinedEpisodesProvider._({
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

String _$combinedEpisodesHash() => r'49eac0d3b5ff036a63cdfd8099861161df02d3e6';

/// Combined provider that merges API data with cached episodes

final class CombinedEpisodesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  CombinedEpisodesFamily._()
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
final filteredCombinedEpisodesProvider = FilteredCombinedEpisodesFamily._();

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
  FilteredCombinedEpisodesProvider._({
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
    r'd135b88b6f3c42551f0b47ff69ef4d73cda7ccce';

/// Filtered combined episodes provider (replaces the existing filteredShows)

final class FilteredCombinedEpisodesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  FilteredCombinedEpisodesFamily._()
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
