// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_download_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$torrentDownloadHash() => r'5c5e1f3a2f1d4fa4face8bc531fcaa0f64109d72';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$TorrentDownload
    extends BuildlessNotifier<TorrentDownloadState> {
  late final String showId;

  TorrentDownloadState build(String showId);
}

/// See also [TorrentDownload].
@ProviderFor(TorrentDownload)
const torrentDownloadProvider = TorrentDownloadFamily();

/// See also [TorrentDownload].
class TorrentDownloadFamily extends Family<TorrentDownloadState> {
  /// See also [TorrentDownload].
  const TorrentDownloadFamily();

  /// See also [TorrentDownload].
  TorrentDownloadProvider call(String showId) {
    return TorrentDownloadProvider(showId);
  }

  @override
  TorrentDownloadProvider getProviderOverride(
    covariant TorrentDownloadProvider provider,
  ) {
    return call(provider.showId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'torrentDownloadProvider';
}

/// See also [TorrentDownload].
class TorrentDownloadProvider
    extends NotifierProviderImpl<TorrentDownload, TorrentDownloadState> {
  /// See also [TorrentDownload].
  TorrentDownloadProvider(String showId)
    : this._internal(
        () => TorrentDownload()..showId = showId,
        from: torrentDownloadProvider,
        name: r'torrentDownloadProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$torrentDownloadHash,
        dependencies: TorrentDownloadFamily._dependencies,
        allTransitiveDependencies:
            TorrentDownloadFamily._allTransitiveDependencies,
        showId: showId,
      );

  TorrentDownloadProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.showId,
  }) : super.internal();

  final String showId;

  @override
  TorrentDownloadState runNotifierBuild(covariant TorrentDownload notifier) {
    return notifier.build(showId);
  }

  @override
  Override overrideWith(TorrentDownload Function() create) {
    return ProviderOverride(
      origin: this,
      override: TorrentDownloadProvider._internal(
        () => create()..showId = showId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        showId: showId,
      ),
    );
  }

  @override
  NotifierProviderElement<TorrentDownload, TorrentDownloadState>
  createElement() {
    return _TorrentDownloadProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TorrentDownloadProvider && other.showId == showId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, showId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TorrentDownloadRef on NotifierProviderRef<TorrentDownloadState> {
  /// The parameter `showId` of this provider.
  String get showId;
}

class _TorrentDownloadProviderElement
    extends NotifierProviderElement<TorrentDownload, TorrentDownloadState>
    with TorrentDownloadRef {
  _TorrentDownloadProviderElement(super.provider);

  @override
  String get showId => (origin as TorrentDownloadProvider).showId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
