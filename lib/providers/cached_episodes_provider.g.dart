// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_episodes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$combinedEpisodesHash() => r'cd4461523c686dcf7f0390a45737163f3a5c5d53';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Combined provider that merges API data with cached episodes
///
/// Copied from [combinedEpisodes].
@ProviderFor(combinedEpisodes)
const combinedEpisodesProvider = CombinedEpisodesFamily();

/// Combined provider that merges API data with cached episodes
///
/// Copied from [combinedEpisodes].
class CombinedEpisodesFamily extends Family<AsyncValue<List<ShowInfo>>> {
  /// Combined provider that merges API data with cached episodes
  ///
  /// Copied from [combinedEpisodes].
  const CombinedEpisodesFamily();

  /// Combined provider that merges API data with cached episodes
  ///
  /// Copied from [combinedEpisodes].
  CombinedEpisodesProvider call(String searchTerm) {
    return CombinedEpisodesProvider(searchTerm);
  }

  @override
  CombinedEpisodesProvider getProviderOverride(
    covariant CombinedEpisodesProvider provider,
  ) {
    return call(provider.searchTerm);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'combinedEpisodesProvider';
}

/// Combined provider that merges API data with cached episodes
///
/// Copied from [combinedEpisodes].
class CombinedEpisodesProvider
    extends AutoDisposeFutureProvider<List<ShowInfo>> {
  /// Combined provider that merges API data with cached episodes
  ///
  /// Copied from [combinedEpisodes].
  CombinedEpisodesProvider(String searchTerm)
    : this._internal(
        (ref) => combinedEpisodes(ref as CombinedEpisodesRef, searchTerm),
        from: combinedEpisodesProvider,
        name: r'combinedEpisodesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$combinedEpisodesHash,
        dependencies: CombinedEpisodesFamily._dependencies,
        allTransitiveDependencies:
            CombinedEpisodesFamily._allTransitiveDependencies,
        searchTerm: searchTerm,
      );

  CombinedEpisodesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.searchTerm,
  }) : super.internal();

  final String searchTerm;

  @override
  Override overrideWith(
    FutureOr<List<ShowInfo>> Function(CombinedEpisodesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CombinedEpisodesProvider._internal(
        (ref) => create(ref as CombinedEpisodesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        searchTerm: searchTerm,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ShowInfo>> createElement() {
    return _CombinedEpisodesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CombinedEpisodesProvider && other.searchTerm == searchTerm;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, searchTerm.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CombinedEpisodesRef on AutoDisposeFutureProviderRef<List<ShowInfo>> {
  /// The parameter `searchTerm` of this provider.
  String get searchTerm;
}

class _CombinedEpisodesProviderElement
    extends AutoDisposeFutureProviderElement<List<ShowInfo>>
    with CombinedEpisodesRef {
  _CombinedEpisodesProviderElement(super.provider);

  @override
  String get searchTerm => (origin as CombinedEpisodesProvider).searchTerm;
}

String _$filteredCombinedEpisodesHash() =>
    r'e787e819360702b234972a95a63abcfec694eebb';

/// Filtered combined episodes provider (replaces the existing filteredShows)
///
/// Copied from [filteredCombinedEpisodes].
@ProviderFor(filteredCombinedEpisodes)
const filteredCombinedEpisodesProvider = FilteredCombinedEpisodesFamily();

/// Filtered combined episodes provider (replaces the existing filteredShows)
///
/// Copied from [filteredCombinedEpisodes].
class FilteredCombinedEpisodesFamily
    extends Family<AsyncValue<List<ShowInfo>>> {
  /// Filtered combined episodes provider (replaces the existing filteredShows)
  ///
  /// Copied from [filteredCombinedEpisodes].
  const FilteredCombinedEpisodesFamily();

  /// Filtered combined episodes provider (replaces the existing filteredShows)
  ///
  /// Copied from [filteredCombinedEpisodes].
  FilteredCombinedEpisodesProvider call(String searchTerm) {
    return FilteredCombinedEpisodesProvider(searchTerm);
  }

  @override
  FilteredCombinedEpisodesProvider getProviderOverride(
    covariant FilteredCombinedEpisodesProvider provider,
  ) {
    return call(provider.searchTerm);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'filteredCombinedEpisodesProvider';
}

/// Filtered combined episodes provider (replaces the existing filteredShows)
///
/// Copied from [filteredCombinedEpisodes].
class FilteredCombinedEpisodesProvider
    extends AutoDisposeFutureProvider<List<ShowInfo>> {
  /// Filtered combined episodes provider (replaces the existing filteredShows)
  ///
  /// Copied from [filteredCombinedEpisodes].
  FilteredCombinedEpisodesProvider(String searchTerm)
    : this._internal(
        (ref) => filteredCombinedEpisodes(
          ref as FilteredCombinedEpisodesRef,
          searchTerm,
        ),
        from: filteredCombinedEpisodesProvider,
        name: r'filteredCombinedEpisodesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$filteredCombinedEpisodesHash,
        dependencies: FilteredCombinedEpisodesFamily._dependencies,
        allTransitiveDependencies:
            FilteredCombinedEpisodesFamily._allTransitiveDependencies,
        searchTerm: searchTerm,
      );

  FilteredCombinedEpisodesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.searchTerm,
  }) : super.internal();

  final String searchTerm;

  @override
  Override overrideWith(
    FutureOr<List<ShowInfo>> Function(FilteredCombinedEpisodesRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FilteredCombinedEpisodesProvider._internal(
        (ref) => create(ref as FilteredCombinedEpisodesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        searchTerm: searchTerm,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ShowInfo>> createElement() {
    return _FilteredCombinedEpisodesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredCombinedEpisodesProvider &&
        other.searchTerm == searchTerm;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, searchTerm.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FilteredCombinedEpisodesRef
    on AutoDisposeFutureProviderRef<List<ShowInfo>> {
  /// The parameter `searchTerm` of this provider.
  String get searchTerm;
}

class _FilteredCombinedEpisodesProviderElement
    extends AutoDisposeFutureProviderElement<List<ShowInfo>>
    with FilteredCombinedEpisodesRef {
  _FilteredCombinedEpisodesProviderElement(super.provider);

  @override
  String get searchTerm =>
      (origin as FilteredCombinedEpisodesProvider).searchTerm;
}

String _$cachedEpisodesNotifierHash() =>
    r'a925d8a178f1dd23185a8523ab6f8083b72cfac1';

/// Manages cached episodes from bookmarked series
///
/// Copied from [CachedEpisodesNotifier].
@ProviderFor(CachedEpisodesNotifier)
final cachedEpisodesNotifierProvider = AutoDisposeAsyncNotifierProvider<
  CachedEpisodesNotifier,
  List<ShowInfo>
>.internal(
  CachedEpisodesNotifier.new,
  name: r'cachedEpisodesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cachedEpisodesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CachedEpisodesNotifier = AutoDisposeAsyncNotifier<List<ShowInfo>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
