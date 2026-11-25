// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_torrent_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ForegroundTransferPolicyStatus)
final foregroundTransferPolicyStatusProvider =
    ForegroundTransferPolicyStatusProvider._();

final class ForegroundTransferPolicyStatusProvider
    extends
        $NotifierProvider<
          ForegroundTransferPolicyStatus,
          TransferPolicySnapshot
        > {
  ForegroundTransferPolicyStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundTransferPolicyStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundTransferPolicyStatusHash();

  @$internal
  @override
  ForegroundTransferPolicyStatus create() => ForegroundTransferPolicyStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransferPolicySnapshot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransferPolicySnapshot>(value),
    );
  }
}

String _$foregroundTransferPolicyStatusHash() =>
    r'6195288008d3da9567cb77fcb2515cb7b21b4cc8';

abstract class _$ForegroundTransferPolicyStatus
    extends $Notifier<TransferPolicySnapshot> {
  TransferPolicySnapshot build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TransferPolicySnapshot, TransferPolicySnapshot>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TransferPolicySnapshot, TransferPolicySnapshot>,
              TransferPolicySnapshot,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ForegroundTorrentManager)
final foregroundTorrentManagerProvider = ForegroundTorrentManagerProvider._();

final class ForegroundTorrentManagerProvider
    extends $NotifierProvider<ForegroundTorrentManager, TorrentManagerState> {
  ForegroundTorrentManagerProvider._()
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
    r'227cb7e24feb34d4b4f449b409832f9ed0c551b9';

abstract class _$ForegroundTorrentManager
    extends $Notifier<TorrentManagerState> {
  TorrentManagerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TorrentManagerState, TorrentManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TorrentManagerState, TorrentManagerState>,
              TorrentManagerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(foregroundTorrentForShow)
final foregroundTorrentForShowProvider = ForegroundTorrentForShowFamily._();

final class ForegroundTorrentForShowProvider
    extends
        $FunctionalProvider<
          TorrentDownloadState,
          TorrentDownloadState,
          TorrentDownloadState
        >
    with $Provider<TorrentDownloadState> {
  ForegroundTorrentForShowProvider._({
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
  ForegroundTorrentForShowFamily._()
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
