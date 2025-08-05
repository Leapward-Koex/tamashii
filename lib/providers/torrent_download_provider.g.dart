// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_download_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$torrentForShowHash() => r'a52b771af4ba67a95a1c7d63f01a827259c77c44';

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

/// See also [torrentForShow].
@ProviderFor(torrentForShow)
const torrentForShowProvider = TorrentForShowFamily();

/// See also [torrentForShow].
class TorrentForShowFamily extends Family<TorrentDownloadState> {
  /// See also [torrentForShow].
  const TorrentForShowFamily();

  /// See also [torrentForShow].
  TorrentForShowProvider call(String showId) {
    return TorrentForShowProvider(showId);
  }

  @override
  TorrentForShowProvider getProviderOverride(
    covariant TorrentForShowProvider provider,
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
  String? get name => r'torrentForShowProvider';
}

/// See also [torrentForShow].
class TorrentForShowProvider extends AutoDisposeProvider<TorrentDownloadState> {
  /// See also [torrentForShow].
  TorrentForShowProvider(String showId)
    : this._internal(
        (ref) => torrentForShow(ref as TorrentForShowRef, showId),
        from: torrentForShowProvider,
        name: r'torrentForShowProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$torrentForShowHash,
        dependencies: TorrentForShowFamily._dependencies,
        allTransitiveDependencies:
            TorrentForShowFamily._allTransitiveDependencies,
        showId: showId,
      );

  TorrentForShowProvider._internal(
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
  Override overrideWith(
    TorrentDownloadState Function(TorrentForShowRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TorrentForShowProvider._internal(
        (ref) => create(ref as TorrentForShowRef),
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
  AutoDisposeProviderElement<TorrentDownloadState> createElement() {
    return _TorrentForShowProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TorrentForShowProvider && other.showId == showId;
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
mixin TorrentForShowRef on AutoDisposeProviderRef<TorrentDownloadState> {
  /// The parameter `showId` of this provider.
  String get showId;
}

class _TorrentForShowProviderElement
    extends AutoDisposeProviderElement<TorrentDownloadState>
    with TorrentForShowRef {
  _TorrentForShowProviderElement(super.provider);

  @override
  String get showId => (origin as TorrentForShowProvider).showId;
}

String _$torrentManagerHash() => r'02e26b8f12b98563e225056f3a13a98ea6d4e91f';

/// See also [TorrentManager].
@ProviderFor(TorrentManager)
final torrentManagerProvider =
    NotifierProvider<TorrentManager, TorrentManagerState>.internal(
      TorrentManager.new,
      name: r'torrentManagerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$torrentManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TorrentManager = Notifier<TorrentManagerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
