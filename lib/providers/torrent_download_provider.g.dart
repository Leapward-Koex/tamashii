// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_download_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TorrentManager)
const torrentManagerProvider = TorrentManagerProvider._();

final class TorrentManagerProvider
    extends $NotifierProvider<TorrentManager, TorrentManagerState> {
  const TorrentManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'torrentManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$torrentManagerHash();

  @$internal
  @override
  TorrentManager create() => TorrentManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TorrentManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TorrentManagerState>(value),
    );
  }
}

String _$torrentManagerHash() => r'93f4317b4263bb8398612be3960293e1f30f1e20';

abstract class _$TorrentManager extends $Notifier<TorrentManagerState> {
  TorrentManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<TorrentManagerState, TorrentManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TorrentManagerState, TorrentManagerState>,
              TorrentManagerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(torrentForShow)
const torrentForShowProvider = TorrentForShowFamily._();

final class TorrentForShowProvider
    extends
        $FunctionalProvider<
          TorrentDownloadState,
          TorrentDownloadState,
          TorrentDownloadState
        >
    with $Provider<TorrentDownloadState> {
  const TorrentForShowProvider._({
    required TorrentForShowFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'torrentForShowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$torrentForShowHash();

  @override
  String toString() {
    return r'torrentForShowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TorrentDownloadState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TorrentDownloadState create(Ref ref) {
    final argument = this.argument as String;
    return torrentForShow(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TorrentDownloadState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TorrentDownloadState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TorrentForShowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$torrentForShowHash() => r'a52b771af4ba67a95a1c7d63f01a827259c77c44';

final class TorrentForShowFamily extends $Family
    with $FunctionalFamilyOverride<TorrentDownloadState, String> {
  const TorrentForShowFamily._()
    : super(
        retry: null,
        name: r'torrentForShowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TorrentForShowProvider call(String showId) =>
      TorrentForShowProvider._(argument: showId, from: this);

  @override
  String toString() => r'torrentForShowProvider';
}
