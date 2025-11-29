// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsplease_api_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subsPleaseApi)
const subsPleaseApiProvider = SubsPleaseApiProvider._();

final class SubsPleaseApiProvider
    extends $FunctionalProvider<SubsPleaseApi, SubsPleaseApi, SubsPleaseApi>
    with $Provider<SubsPleaseApi> {
  const SubsPleaseApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subsPleaseApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subsPleaseApiHash();

  @$internal
  @override
  $ProviderElement<SubsPleaseApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SubsPleaseApi create(Ref ref) {
    return subsPleaseApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubsPleaseApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubsPleaseApi>(value),
    );
  }
}

String _$subsPleaseApiHash() => r'5e916012b526cb15eae6eb53e409dfacc05ba54b';

@ProviderFor(latestShows)
const latestShowsProvider = LatestShowsProvider._();

final class LatestShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShowInfo>>,
          List<ShowInfo>,
          FutureOr<List<ShowInfo>>
        >
    with $FutureModifier<List<ShowInfo>>, $FutureProvider<List<ShowInfo>> {
  const LatestShowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'latestShowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$latestShowsHash();

  @$internal
  @override
  $FutureProviderElement<List<ShowInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ShowInfo>> create(Ref ref) {
    return latestShows(ref);
  }
}

String _$latestShowsHash() => r'55bbb87dbf9a7fcb5cee4e819c3dc4c25c16d8aa';

@ProviderFor(searchShows)
const searchShowsProvider = SearchShowsFamily._();

final class SearchShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShowInfo>>,
          List<ShowInfo>,
          FutureOr<List<ShowInfo>>
        >
    with $FutureModifier<List<ShowInfo>>, $FutureProvider<List<ShowInfo>> {
  const SearchShowsProvider._({
    required SearchShowsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchShowsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchShowsHash();

  @override
  String toString() {
    return r'searchShowsProvider'
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
    return searchShows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchShowsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchShowsHash() => r'7eb8ebb488f21c1d3c09dbd809a7fcebc8cc2ea3';

final class SearchShowsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  const SearchShowsFamily._()
    : super(
        retry: null,
        name: r'searchShowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SearchShowsProvider call(String searchTerm) =>
      SearchShowsProvider._(argument: searchTerm, from: this);

  @override
  String toString() => r'searchShowsProvider';
}

@ProviderFor(filteredShows)
const filteredShowsProvider = FilteredShowsFamily._();

final class FilteredShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShowInfo>>,
          List<ShowInfo>,
          FutureOr<List<ShowInfo>>
        >
    with $FutureModifier<List<ShowInfo>>, $FutureProvider<List<ShowInfo>> {
  const FilteredShowsProvider._({
    required FilteredShowsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'filteredShowsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredShowsHash();

  @override
  String toString() {
    return r'filteredShowsProvider'
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
    return filteredShows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredShowsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredShowsHash() => r'7bed9373efd283c4f71db6e38eb71ca2d95370a1';

final class FilteredShowsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ShowInfo>>, String> {
  const FilteredShowsFamily._()
    : super(
        retry: null,
        name: r'filteredShowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FilteredShowsProvider call(String searchTerm) =>
      FilteredShowsProvider._(argument: searchTerm, from: this);

  @override
  String toString() => r'filteredShowsProvider';
}

@ProviderFor(showSynopsis)
const showSynopsisProvider = ShowSynopsisFamily._();

final class ShowSynopsisProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  const ShowSynopsisProvider._({
    required ShowSynopsisFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'showSynopsisProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showSynopsisHash();

  @override
  String toString() {
    return r'showSynopsisProvider'
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
    return showSynopsis(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowSynopsisProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showSynopsisHash() => r'628c445a90cbee14311e9e9efd9e2061d45ffe19';

final class ShowSynopsisFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  const ShowSynopsisFamily._()
    : super(
        retry: null,
        name: r'showSynopsisProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShowSynopsisProvider call(String showPage) =>
      ShowSynopsisProvider._(argument: showPage, from: this);

  @override
  String toString() => r'showSynopsisProvider';
}
