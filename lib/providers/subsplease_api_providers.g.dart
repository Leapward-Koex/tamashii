// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsplease_api_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subsPleaseApiHash() => r'5e916012b526cb15eae6eb53e409dfacc05ba54b';

/// See also [subsPleaseApi].
@ProviderFor(subsPleaseApi)
final subsPleaseApiProvider = AutoDisposeProvider<SubsPleaseApi>.internal(
  subsPleaseApi,
  name: r'subsPleaseApiProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$subsPleaseApiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubsPleaseApiRef = AutoDisposeProviderRef<SubsPleaseApi>;
String _$latestShowsHash() => r'55bbb87dbf9a7fcb5cee4e819c3dc4c25c16d8aa';

/// See also [latestShows].
@ProviderFor(latestShows)
final latestShowsProvider = AutoDisposeFutureProvider<List<ShowInfo>>.internal(
  latestShows,
  name: r'latestShowsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$latestShowsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LatestShowsRef = AutoDisposeFutureProviderRef<List<ShowInfo>>;
String _$searchShowsHash() => r'7eb8ebb488f21c1d3c09dbd809a7fcebc8cc2ea3';

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

/// See also [searchShows].
@ProviderFor(searchShows)
const searchShowsProvider = SearchShowsFamily();

/// See also [searchShows].
class SearchShowsFamily extends Family<AsyncValue<List<ShowInfo>>> {
  /// See also [searchShows].
  const SearchShowsFamily();

  /// See also [searchShows].
  SearchShowsProvider call(String searchTerm) {
    return SearchShowsProvider(searchTerm);
  }

  @override
  SearchShowsProvider getProviderOverride(
    covariant SearchShowsProvider provider,
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
  String? get name => r'searchShowsProvider';
}

/// See also [searchShows].
class SearchShowsProvider extends AutoDisposeFutureProvider<List<ShowInfo>> {
  /// See also [searchShows].
  SearchShowsProvider(String searchTerm)
    : this._internal(
        (ref) => searchShows(ref as SearchShowsRef, searchTerm),
        from: searchShowsProvider,
        name: r'searchShowsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$searchShowsHash,
        dependencies: SearchShowsFamily._dependencies,
        allTransitiveDependencies: SearchShowsFamily._allTransitiveDependencies,
        searchTerm: searchTerm,
      );

  SearchShowsProvider._internal(
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
    FutureOr<List<ShowInfo>> Function(SearchShowsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchShowsProvider._internal(
        (ref) => create(ref as SearchShowsRef),
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
    return _SearchShowsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchShowsProvider && other.searchTerm == searchTerm;
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
mixin SearchShowsRef on AutoDisposeFutureProviderRef<List<ShowInfo>> {
  /// The parameter `searchTerm` of this provider.
  String get searchTerm;
}

class _SearchShowsProviderElement
    extends AutoDisposeFutureProviderElement<List<ShowInfo>>
    with SearchShowsRef {
  _SearchShowsProviderElement(super.provider);

  @override
  String get searchTerm => (origin as SearchShowsProvider).searchTerm;
}

String _$filteredShowsHash() => r'7bed9373efd283c4f71db6e38eb71ca2d95370a1';

/// See also [filteredShows].
@ProviderFor(filteredShows)
const filteredShowsProvider = FilteredShowsFamily();

/// See also [filteredShows].
class FilteredShowsFamily extends Family<AsyncValue<List<ShowInfo>>> {
  /// See also [filteredShows].
  const FilteredShowsFamily();

  /// See also [filteredShows].
  FilteredShowsProvider call(String searchTerm) {
    return FilteredShowsProvider(searchTerm);
  }

  @override
  FilteredShowsProvider getProviderOverride(
    covariant FilteredShowsProvider provider,
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
  String? get name => r'filteredShowsProvider';
}

/// See also [filteredShows].
class FilteredShowsProvider extends AutoDisposeFutureProvider<List<ShowInfo>> {
  /// See also [filteredShows].
  FilteredShowsProvider(String searchTerm)
    : this._internal(
        (ref) => filteredShows(ref as FilteredShowsRef, searchTerm),
        from: filteredShowsProvider,
        name: r'filteredShowsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$filteredShowsHash,
        dependencies: FilteredShowsFamily._dependencies,
        allTransitiveDependencies:
            FilteredShowsFamily._allTransitiveDependencies,
        searchTerm: searchTerm,
      );

  FilteredShowsProvider._internal(
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
    FutureOr<List<ShowInfo>> Function(FilteredShowsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FilteredShowsProvider._internal(
        (ref) => create(ref as FilteredShowsRef),
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
    return _FilteredShowsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredShowsProvider && other.searchTerm == searchTerm;
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
mixin FilteredShowsRef on AutoDisposeFutureProviderRef<List<ShowInfo>> {
  /// The parameter `searchTerm` of this provider.
  String get searchTerm;
}

class _FilteredShowsProviderElement
    extends AutoDisposeFutureProviderElement<List<ShowInfo>>
    with FilteredShowsRef {
  _FilteredShowsProviderElement(super.provider);

  @override
  String get searchTerm => (origin as FilteredShowsProvider).searchTerm;
}

String _$showSynopsisHash() => r'628c445a90cbee14311e9e9efd9e2061d45ffe19';

/// See also [showSynopsis].
@ProviderFor(showSynopsis)
const showSynopsisProvider = ShowSynopsisFamily();

/// See also [showSynopsis].
class ShowSynopsisFamily extends Family<AsyncValue<String?>> {
  /// See also [showSynopsis].
  const ShowSynopsisFamily();

  /// See also [showSynopsis].
  ShowSynopsisProvider call(String showPage) {
    return ShowSynopsisProvider(showPage);
  }

  @override
  ShowSynopsisProvider getProviderOverride(
    covariant ShowSynopsisProvider provider,
  ) {
    return call(provider.showPage);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'showSynopsisProvider';
}

/// See also [showSynopsis].
class ShowSynopsisProvider extends AutoDisposeFutureProvider<String?> {
  /// See also [showSynopsis].
  ShowSynopsisProvider(String showPage)
    : this._internal(
        (ref) => showSynopsis(ref as ShowSynopsisRef, showPage),
        from: showSynopsisProvider,
        name: r'showSynopsisProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$showSynopsisHash,
        dependencies: ShowSynopsisFamily._dependencies,
        allTransitiveDependencies:
            ShowSynopsisFamily._allTransitiveDependencies,
        showPage: showPage,
      );

  ShowSynopsisProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.showPage,
  }) : super.internal();

  final String showPage;

  @override
  Override overrideWith(
    FutureOr<String?> Function(ShowSynopsisRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ShowSynopsisProvider._internal(
        (ref) => create(ref as ShowSynopsisRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        showPage: showPage,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _ShowSynopsisProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowSynopsisProvider && other.showPage == showPage;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, showPage.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ShowSynopsisRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `showPage` of this provider.
  String get showPage;
}

class _ShowSynopsisProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with ShowSynopsisRef {
  _ShowSynopsisProviderElement(super.provider);

  @override
  String get showPage => (origin as ShowSynopsisProvider).showPage;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
