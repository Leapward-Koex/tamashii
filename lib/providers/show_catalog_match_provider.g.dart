// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'show_catalog_match_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The presence of a null entry means the user explicitly chose "unmatched".
/// A key per choice allows independent releases to be saved without replacing
/// another release's data.

@ProviderFor(CatalogMatchOverrides)
final catalogMatchOverridesProvider = CatalogMatchOverridesProvider._();

/// The presence of a null entry means the user explicitly chose "unmatched".
/// A key per choice allows independent releases to be saved without replacing
/// another release's data.
final class CatalogMatchOverridesProvider
    extends
        $AsyncNotifierProvider<
          CatalogMatchOverrides,
          Map<String, TenraiAnimeSearchResult?>
        > {
  /// The presence of a null entry means the user explicitly chose "unmatched".
  /// A key per choice allows independent releases to be saved without replacing
  /// another release's data.
  CatalogMatchOverridesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogMatchOverridesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogMatchOverridesHash();

  @$internal
  @override
  CatalogMatchOverrides create() => CatalogMatchOverrides();
}

String _$catalogMatchOverridesHash() =>
    r'ce4d210e1d91de6a1b0358c95be643dbfcf43b51';

/// The presence of a null entry means the user explicitly chose "unmatched".
/// A key per choice allows independent releases to be saved without replacing
/// another release's data.

abstract class _$CatalogMatchOverrides
    extends $AsyncNotifier<Map<String, TenraiAnimeSearchResult?>> {
  FutureOr<Map<String, TenraiAnimeSearchResult?>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<String, TenraiAnimeSearchResult?>>,
              Map<String, TenraiAnimeSearchResult?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, TenraiAnimeSearchResult?>>,
                Map<String, TenraiAnimeSearchResult?>
              >,
              AsyncValue<Map<String, TenraiAnimeSearchResult?>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Successful lookups are shared by ordinary episodes in a series. Manual
/// choices (including "unmatched") live separately and always take priority.

@ProviderFor(ResolvedCatalogMatches)
final resolvedCatalogMatchesProvider = ResolvedCatalogMatchesProvider._();

/// Successful lookups are shared by ordinary episodes in a series. Manual
/// choices (including "unmatched") live separately and always take priority.
final class ResolvedCatalogMatchesProvider
    extends
        $AsyncNotifierProvider<
          ResolvedCatalogMatches,
          Map<String, ShowCatalogMatch>
        > {
  /// Successful lookups are shared by ordinary episodes in a series. Manual
  /// choices (including "unmatched") live separately and always take priority.
  ResolvedCatalogMatchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resolvedCatalogMatchesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resolvedCatalogMatchesHash();

  @$internal
  @override
  ResolvedCatalogMatches create() => ResolvedCatalogMatches();
}

String _$resolvedCatalogMatchesHash() =>
    r'c0523527f8e6abdf92442039721bb7f83ce747c6';

/// Successful lookups are shared by ordinary episodes in a series. Manual
/// choices (including "unmatched") live separately and always take priority.

abstract class _$ResolvedCatalogMatches
    extends $AsyncNotifier<Map<String, ShowCatalogMatch>> {
  FutureOr<Map<String, ShowCatalogMatch>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<String, ShowCatalogMatch>>,
              Map<String, ShowCatalogMatch>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, ShowCatalogMatch>>,
                Map<String, ShowCatalogMatch>
              >,
              AsyncValue<Map<String, ShowCatalogMatch>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(catalogCacheReady)
final catalogCacheReadyProvider = CatalogCacheReadyProvider._();

final class CatalogCacheReadyProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  CatalogCacheReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogCacheReadyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogCacheReadyHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return catalogCacheReady(ref);
  }
}

String _$catalogCacheReadyHash() => r'76d55db11681c4e520146629353f89c904c599ed';

@ProviderFor(_catalogBookmarks)
final _catalogBookmarksProvider = _CatalogBookmarksProvider._();

final class _CatalogBookmarksProvider
    extends
        $FunctionalProvider<
          Map<String, BookmarkedShowInfo>,
          Map<String, BookmarkedShowInfo>,
          Map<String, BookmarkedShowInfo>
        >
    with $Provider<Map<String, BookmarkedShowInfo>> {
  _CatalogBookmarksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_catalogBookmarksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_catalogBookmarksHash();

  @$internal
  @override
  $ProviderElement<Map<String, BookmarkedShowInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, BookmarkedShowInfo> create(Ref ref) {
    return _catalogBookmarks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, BookmarkedShowInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, BookmarkedShowInfo>>(
        value,
      ),
    );
  }
}

String _$_catalogBookmarksHash() => r'74e6fd894f25d18db70052549cdce488aec8376c';

@ProviderFor(cachedShowCatalogMatch)
final cachedShowCatalogMatchProvider = CachedShowCatalogMatchFamily._();

final class CachedShowCatalogMatchProvider
    extends
        $FunctionalProvider<
          ShowCatalogMatch?,
          ShowCatalogMatch?,
          ShowCatalogMatch?
        >
    with $Provider<ShowCatalogMatch?> {
  CachedShowCatalogMatchProvider._({
    required CachedShowCatalogMatchFamily super.from,
    required ShowCatalogTarget super.argument,
  }) : super(
         retry: null,
         name: r'cachedShowCatalogMatchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cachedShowCatalogMatchHash();

  @override
  String toString() {
    return r'cachedShowCatalogMatchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ShowCatalogMatch?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShowCatalogMatch? create(Ref ref) {
    final argument = this.argument as ShowCatalogTarget;
    return cachedShowCatalogMatch(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowCatalogMatch? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowCatalogMatch?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CachedShowCatalogMatchProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cachedShowCatalogMatchHash() =>
    r'29f7fa141c23b7e151c1714e586670dd1e613835';

final class CachedShowCatalogMatchFamily extends $Family
    with $FunctionalFamilyOverride<ShowCatalogMatch?, ShowCatalogTarget> {
  CachedShowCatalogMatchFamily._()
    : super(
        retry: null,
        name: r'cachedShowCatalogMatchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CachedShowCatalogMatchProvider call(ShowCatalogTarget target) =>
      CachedShowCatalogMatchProvider._(argument: target, from: this);

  @override
  String toString() => r'cachedShowCatalogMatchProvider';
}

@ProviderFor(showCatalogMatch)
final showCatalogMatchProvider = ShowCatalogMatchFamily._();

final class ShowCatalogMatchProvider
    extends
        $FunctionalProvider<
          AsyncValue<ShowCatalogMatch>,
          ShowCatalogMatch,
          FutureOr<ShowCatalogMatch>
        >
    with $FutureModifier<ShowCatalogMatch>, $FutureProvider<ShowCatalogMatch> {
  ShowCatalogMatchProvider._({
    required ShowCatalogMatchFamily super.from,
    required ShowCatalogTarget super.argument,
  }) : super(
         retry: _noRetry,
         name: r'showCatalogMatchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showCatalogMatchHash();

  @override
  String toString() {
    return r'showCatalogMatchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ShowCatalogMatch> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ShowCatalogMatch> create(Ref ref) {
    final argument = this.argument as ShowCatalogTarget;
    return showCatalogMatch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowCatalogMatchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showCatalogMatchHash() => r'06fc03e1d4a097209a510dde8c9820338a09f290';

final class ShowCatalogMatchFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ShowCatalogMatch>,
          ShowCatalogTarget
        > {
  ShowCatalogMatchFamily._()
    : super(
        retry: _noRetry,
        name: r'showCatalogMatchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShowCatalogMatchProvider call(ShowCatalogTarget target) =>
      ShowCatalogMatchProvider._(argument: target, from: this);

  @override
  String toString() => r'showCatalogMatchProvider';
}
