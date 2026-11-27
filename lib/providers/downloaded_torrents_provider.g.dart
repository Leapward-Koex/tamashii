// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_torrents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stores a set of torrent keys that have completed downloading.

@ProviderFor(DownloadedTorrentsNotifier)
final downloadedTorrentsProvider = DownloadedTorrentsNotifierProvider._();

/// Stores a set of torrent keys that have completed downloading.
final class DownloadedTorrentsNotifierProvider
    extends $AsyncNotifierProvider<DownloadedTorrentsNotifier, Set<String>> {
  /// Stores a set of torrent keys that have completed downloading.
  DownloadedTorrentsNotifierProvider._()
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
    r'7ad652beaed7135739d0584f3ef5abf7207f3132';

/// Stores a set of torrent keys that have completed downloading.

abstract class _$DownloadedTorrentsNotifier
    extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
