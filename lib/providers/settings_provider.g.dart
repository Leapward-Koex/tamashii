// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether to auto-generate subfolders for each series.

@ProviderFor(AutoGenerateFolders)
const autoGenerateFoldersProvider = AutoGenerateFoldersProvider._();

/// Whether to auto-generate subfolders for each series.
final class AutoGenerateFoldersProvider
    extends $AsyncNotifierProvider<AutoGenerateFolders, bool> {
  /// Whether to auto-generate subfolders for each series.
  const AutoGenerateFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoGenerateFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoGenerateFoldersHash();

  @$internal
  @override
  AutoGenerateFolders create() => AutoGenerateFolders();
}

String _$autoGenerateFoldersHash() =>
    r'f83887b8377c72834d12c7c6631119e7442cb35f';

/// Whether to auto-generate subfolders for each series.

abstract class _$AutoGenerateFolders extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The base folder path where series subfolders are created.

@ProviderFor(DownloadBasePath)
const downloadBasePathProvider = DownloadBasePathProvider._();

/// The base folder path where series subfolders are created.
final class DownloadBasePathProvider
    extends $AsyncNotifierProvider<DownloadBasePath, String> {
  /// The base folder path where series subfolders are created.
  const DownloadBasePathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadBasePathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadBasePathHash();

  @$internal
  @override
  DownloadBasePath create() => DownloadBasePath();
}

String _$downloadBasePathHash() => r'1b98b77c86e099eaf0fba4a39901e614a3e39f94';

/// The base folder path where series subfolders are created.

abstract class _$DownloadBasePath extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Mapping of series → custom folder path for episodes.

@ProviderFor(SeriesFolderMapping)
const seriesFolderMappingProvider = SeriesFolderMappingProvider._();

/// Mapping of series → custom folder path for episodes.
final class SeriesFolderMappingProvider
    extends $AsyncNotifierProvider<SeriesFolderMapping, Map<String, String>> {
  /// Mapping of series → custom folder path for episodes.
  const SeriesFolderMappingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seriesFolderMappingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seriesFolderMappingHash();

  @$internal
  @override
  SeriesFolderMapping create() => SeriesFolderMapping();
}

String _$seriesFolderMappingHash() =>
    r'e84e8d3c39128aec74523d26221b21ee74d550c8';

/// Mapping of series → custom folder path for episodes.

abstract class _$SeriesFolderMapping
    extends $AsyncNotifier<Map<String, String>> {
  FutureOr<Map<String, String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, String>>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, String>>, Map<String, String>>,
              AsyncValue<Map<String, String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Whether downloads may continue on networks Android marks as metered.

@ProviderFor(AllowMeteredDownloads)
const allowMeteredDownloadsProvider = AllowMeteredDownloadsProvider._();

/// Whether downloads may continue on networks Android marks as metered.
final class AllowMeteredDownloadsProvider
    extends $AsyncNotifierProvider<AllowMeteredDownloads, bool> {
  /// Whether downloads may continue on networks Android marks as metered.
  const AllowMeteredDownloadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allowMeteredDownloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allowMeteredDownloadsHash();

  @$internal
  @override
  AllowMeteredDownloads create() => AllowMeteredDownloads();
}

String _$allowMeteredDownloadsHash() =>
    r'8b1ef618501cc244f677420b65da8e3aae047195';

/// Whether downloads may continue on networks Android marks as metered.

abstract class _$AllowMeteredDownloads extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Whether downloads may continue over an Android cellular transport.
///
/// This is intentionally separate from Android's metered-network flag because
/// a VPN can otherwise obscure whether its underlying network is cellular.

@ProviderFor(AllowMobileData)
const allowMobileDataProvider = AllowMobileDataProvider._();

/// Whether downloads may continue over an Android cellular transport.
///
/// This is intentionally separate from Android's metered-network flag because
/// a VPN can otherwise obscure whether its underlying network is cellular.
final class AllowMobileDataProvider
    extends $AsyncNotifierProvider<AllowMobileData, bool> {
  /// Whether downloads may continue over an Android cellular transport.
  ///
  /// This is intentionally separate from Android's metered-network flag because
  /// a VPN can otherwise obscure whether its underlying network is cellular.
  const AllowMobileDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allowMobileDataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allowMobileDataHash();

  @$internal
  @override
  AllowMobileData create() => AllowMobileData();
}

String _$allowMobileDataHash() => r'73d45b5127f0119c5a4ccce44685382163a4b72b';

/// Whether downloads may continue over an Android cellular transport.
///
/// This is intentionally separate from Android's metered-network flag because
/// a VPN can otherwise obscure whether its underlying network is cellular.

abstract class _$AllowMobileData extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
