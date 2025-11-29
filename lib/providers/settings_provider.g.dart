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
    r'9dc9f8829be9649052f4d12c8f7338830367a6e8';

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

String _$downloadBasePathHash() => r'36f19d237598d3cb76affdda8a65703e06ede9bc';

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
    r'29dd63d8103501606e17a1cb598673d6ff6e125d';

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
