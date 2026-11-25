// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the same normalized transfer report used by the foreground
/// notification to the downloads UI.
///
/// This intentionally only adapts UI manager state. Classification, totals,
/// progress, rate, ETA, and formatting rules all live in
/// [DownloadTransferMetrics], so the page cannot drift from the notification.

@ProviderFor(downloadQueue)
final downloadQueueProvider = DownloadQueueProvider._();

/// Exposes the same normalized transfer report used by the foreground
/// notification to the downloads UI.
///
/// This intentionally only adapts UI manager state. Classification, totals,
/// progress, rate, ETA, and formatting rules all live in
/// [DownloadTransferMetrics], so the page cannot drift from the notification.

final class DownloadQueueProvider
    extends
        $FunctionalProvider<
          DownloadTransferReport,
          DownloadTransferReport,
          DownloadTransferReport
        >
    with $Provider<DownloadTransferReport> {
  /// Exposes the same normalized transfer report used by the foreground
  /// notification to the downloads UI.
  ///
  /// This intentionally only adapts UI manager state. Classification, totals,
  /// progress, rate, ETA, and formatting rules all live in
  /// [DownloadTransferMetrics], so the page cannot drift from the notification.
  DownloadQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueHash();

  @$internal
  @override
  $ProviderElement<DownloadTransferReport> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadTransferReport create(Ref ref) {
    return downloadQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadTransferReport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadTransferReport>(value),
    );
  }
}

String _$downloadQueueHash() => r'e8e8e85ed8c3adf03dfc63a5f90ff93c603ed96a';

/// The Home badge needs only lifecycle state, even when transfer rates change.

@ProviderFor(activeDownloadCount)
final activeDownloadCountProvider = ActiveDownloadCountProvider._();

/// The Home badge needs only lifecycle state, even when transfer rates change.

final class ActiveDownloadCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// The Home badge needs only lifecycle state, even when transfer rates change.
  ActiveDownloadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeDownloadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeDownloadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return activeDownloadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$activeDownloadCountHash() =>
    r'ad06253635a649a7ad05e2e35b0837c5c13b2c77';

@ProviderFor(downloadQueueControls)
final downloadQueueControlsProvider = DownloadQueueControlsProvider._();

final class DownloadQueueControlsProvider
    extends
        $FunctionalProvider<
          DownloadQueueControls,
          DownloadQueueControls,
          DownloadQueueControls
        >
    with $Provider<DownloadQueueControls> {
  DownloadQueueControlsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueControlsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueControlsHash();

  @$internal
  @override
  $ProviderElement<DownloadQueueControls> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadQueueControls create(Ref ref) {
    return downloadQueueControls(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadQueueControls value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadQueueControls>(value),
    );
  }
}

String _$downloadQueueControlsHash() =>
    r'b1398dc0e7b78a84cb8620d345306672357a38b4';
