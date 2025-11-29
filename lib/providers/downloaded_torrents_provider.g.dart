// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_torrents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stores a set of torrent keys that have completed downloading.

@ProviderFor(DownloadedTorrentsNotifier)
const downloadedTorrentsProvider = DownloadedTorrentsNotifierProvider._();

/// Stores a set of torrent keys that have completed downloading.
final class DownloadedTorrentsNotifierProvider
    extends $AsyncNotifierProvider<DownloadedTorrentsNotifier, Set<String>> {
  /// Stores a set of torrent keys that have completed downloading.
  const DownloadedTorrentsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedTorrentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedTorrentsNotifierHash();

  @$internal
  @override
  DownloadedTorrentsNotifier create() => DownloadedTorrentsNotifier();
}

String _$downloadedTorrentsNotifierHash() =>
    r'bba187e43f8be7b98226a420da1f0546e7779ec6';

/// Stores a set of torrent keys that have completed downloading.

abstract class _$DownloadedTorrentsNotifier
    extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
