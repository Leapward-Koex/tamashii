// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_torrent_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ForegroundTorrentManager)
const foregroundTorrentManagerProvider = ForegroundTorrentManagerProvider._();

final class ForegroundTorrentManagerProvider
    extends $NotifierProvider<ForegroundTorrentManager, TorrentManagerState> {
  const ForegroundTorrentManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundTorrentManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundTorrentManagerHash();

  @$internal
  @override
  ForegroundTorrentManager create() => ForegroundTorrentManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TorrentManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TorrentManagerState>(value),
    );
  }
}

String _$foregroundTorrentManagerHash() =>
    r'b7e8bb03403b184f68c06d3a3926a08b1e075915';

abstract class _$ForegroundTorrentManager
    extends $Notifier<TorrentManagerState> {
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

@ProviderFor(foregroundTorrentForShow)
const foregroundTorrentForShowProvider = ForegroundTorrentForShowFamily._();

final class ForegroundTorrentForShowProvider
    extends
        $FunctionalProvider<
          TorrentDownloadState,
          TorrentDownloadState,
          TorrentDownloadState
        >
    with $Provider<TorrentDownloadState> {
  const ForegroundTorrentForShowProvider._({
    required ForegroundTorrentForShowFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'foregroundTorrentForShowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foregroundTorrentForShowHash();

  @override
  String toString() {
    return r'foregroundTorrentForShowProvider'
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
    return foregroundTorrentForShow(ref, argument);
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
    return other is ForegroundTorrentForShowProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foregroundTorrentForShowHash() =>
    r'a2d636afdfd807e38dcee61a798f3ee1bf3420d4';

final class ForegroundTorrentForShowFamily extends $Family
    with $FunctionalFamilyOverride<TorrentDownloadState, String> {
  const ForegroundTorrentForShowFamily._()
    : super(
        retry: null,
        name: r'foregroundTorrentForShowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ForegroundTorrentForShowProvider call(String showId) =>
      ForegroundTorrentForShowProvider._(argument: showId, from: this);

  @override
  String toString() => r'foregroundTorrentForShowProvider';
}
