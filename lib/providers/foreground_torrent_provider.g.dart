// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foreground_torrent_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$foregroundTorrentForShowHash() =>
    r'3bd548cd6a6582a7825ec236214cf971d840fc1c';

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

/// See also [foregroundTorrentForShow].
@ProviderFor(foregroundTorrentForShow)
const foregroundTorrentForShowProvider = ForegroundTorrentForShowFamily();

/// See also [foregroundTorrentForShow].
class ForegroundTorrentForShowFamily extends Family<TorrentDownloadState> {
  /// See also [foregroundTorrentForShow].
  const ForegroundTorrentForShowFamily();

  /// See also [foregroundTorrentForShow].
  ForegroundTorrentForShowProvider call(String showId) {
    return ForegroundTorrentForShowProvider(showId);
  }

  @override
  ForegroundTorrentForShowProvider getProviderOverride(
    covariant ForegroundTorrentForShowProvider provider,
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
  String? get name => r'foregroundTorrentForShowProvider';
}

/// See also [foregroundTorrentForShow].
class ForegroundTorrentForShowProvider
    extends AutoDisposeProvider<TorrentDownloadState> {
  /// See also [foregroundTorrentForShow].
  ForegroundTorrentForShowProvider(String showId)
    : this._internal(
        (ref) => foregroundTorrentForShow(
          ref as ForegroundTorrentForShowRef,
          showId,
        ),
        from: foregroundTorrentForShowProvider,
        name: r'foregroundTorrentForShowProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$foregroundTorrentForShowHash,
        dependencies: ForegroundTorrentForShowFamily._dependencies,
        allTransitiveDependencies:
            ForegroundTorrentForShowFamily._allTransitiveDependencies,
        showId: showId,
      );

  ForegroundTorrentForShowProvider._internal(
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
    TorrentDownloadState Function(ForegroundTorrentForShowRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ForegroundTorrentForShowProvider._internal(
        (ref) => create(ref as ForegroundTorrentForShowRef),
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
    return _ForegroundTorrentForShowProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ForegroundTorrentForShowProvider && other.showId == showId;
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
mixin ForegroundTorrentForShowRef
    on AutoDisposeProviderRef<TorrentDownloadState> {
  /// The parameter `showId` of this provider.
  String get showId;
}

class _ForegroundTorrentForShowProviderElement
    extends AutoDisposeProviderElement<TorrentDownloadState>
    with ForegroundTorrentForShowRef {
  _ForegroundTorrentForShowProviderElement(super.provider);

  @override
  String get showId => (origin as ForegroundTorrentForShowProvider).showId;
}

String _$foregroundTorrentManagerHash() =>
    r'345e2f87d5f2f32a880e49a71e69973b9d724f5b';

/// See also [ForegroundTorrentManager].
@ProviderFor(ForegroundTorrentManager)
final foregroundTorrentManagerProvider =
    NotifierProvider<ForegroundTorrentManager, TorrentManagerState>.internal(
      ForegroundTorrentManager.new,
      name: r'foregroundTorrentManagerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$foregroundTorrentManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ForegroundTorrentManager = Notifier<TorrentManagerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
