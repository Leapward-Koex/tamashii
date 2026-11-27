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
    r'eb410ac517be71248f217fabaa413fba480c2cef';

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

String _$showCatalogMatchHash() => r'7dedee47267a786d0a2a3bf47c0a60f0e8751ab1';

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
