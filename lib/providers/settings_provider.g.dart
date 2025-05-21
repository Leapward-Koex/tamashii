// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$autoGenerateFoldersHash() =>
    r'9dc9f8829be9649052f4d12c8f7338830367a6e8';

/// Whether to auto-generate subfolders for each series.
///
/// Copied from [AutoGenerateFolders].
@ProviderFor(AutoGenerateFolders)
final autoGenerateFoldersProvider =
    AutoDisposeAsyncNotifierProvider<AutoGenerateFolders, bool>.internal(
      AutoGenerateFolders.new,
      name: r'autoGenerateFoldersProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$autoGenerateFoldersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AutoGenerateFolders = AutoDisposeAsyncNotifier<bool>;
String _$downloadBasePathHash() => r'36f19d237598d3cb76affdda8a65703e06ede9bc';

/// The base folder path where series subfolders are created.
///
/// Copied from [DownloadBasePath].
@ProviderFor(DownloadBasePath)
final downloadBasePathProvider =
    AutoDisposeAsyncNotifierProvider<DownloadBasePath, String>.internal(
      DownloadBasePath.new,
      name: r'downloadBasePathProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$downloadBasePathHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadBasePath = AutoDisposeAsyncNotifier<String>;
String _$seriesFolderMappingHash() =>
    r'084bc1a55efd24924ce585e31d21daa2782333ce';

/// Mapping of series → custom folder path for episodes.
///
/// Copied from [SeriesFolderMapping].
@ProviderFor(SeriesFolderMapping)
final seriesFolderMappingProvider = AutoDisposeAsyncNotifierProvider<
  SeriesFolderMapping,
  Map<String, String>
>.internal(
  SeriesFolderMapping.new,
  name: r'seriesFolderMappingProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$seriesFolderMappingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SeriesFolderMapping = AutoDisposeAsyncNotifier<Map<String, String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
