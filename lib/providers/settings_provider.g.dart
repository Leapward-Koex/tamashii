// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$autoGenerateFoldersNotifierHash() =>
    r'91019bde3b904f1881ecf02e995fbd4cc8b3e3c0';

/// Whether to auto-generate subfolders for each series.
///
/// Copied from [AutoGenerateFoldersNotifier].
@ProviderFor(AutoGenerateFoldersNotifier)
final autoGenerateFoldersNotifierProvider = AutoDisposeAsyncNotifierProvider<
  AutoGenerateFoldersNotifier,
  bool
>.internal(
  AutoGenerateFoldersNotifier.new,
  name: r'autoGenerateFoldersNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$autoGenerateFoldersNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AutoGenerateFoldersNotifier = AutoDisposeAsyncNotifier<bool>;
String _$downloadBasePathNotifierHash() =>
    r'47ad11d48a89609806906c9b44c7a30affc8f934';

/// The base folder path where series subfolders are created.
///
/// Copied from [DownloadBasePathNotifier].
@ProviderFor(DownloadBasePathNotifier)
final downloadBasePathNotifierProvider =
    AutoDisposeAsyncNotifierProvider<DownloadBasePathNotifier, String>.internal(
      DownloadBasePathNotifier.new,
      name: r'downloadBasePathNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$downloadBasePathNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadBasePathNotifier = AutoDisposeAsyncNotifier<String>;
String _$seriesFolderMappingNotifierHash() =>
    r'f225632874887cf59c3b8e894f7a9d344005f845';

/// Mapping of series → custom folder path for episodes.
///
/// Copied from [SeriesFolderMappingNotifier].
@ProviderFor(SeriesFolderMappingNotifier)
final seriesFolderMappingNotifierProvider = AutoDisposeAsyncNotifierProvider<
  SeriesFolderMappingNotifier,
  Map<String, String>
>.internal(
  SeriesFolderMappingNotifier.new,
  name: r'seriesFolderMappingNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$seriesFolderMappingNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SeriesFolderMappingNotifier =
    AutoDisposeAsyncNotifier<Map<String, String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
