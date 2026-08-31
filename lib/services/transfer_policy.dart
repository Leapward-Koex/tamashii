import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_config.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

/// SharedPreferences keys used by both the UI and foreground-service engines.
const String allowMeteredDownloadsPreferenceKey = 'allow_metered_downloads';
const String allowMobileDataPreferenceKey = 'allow_mobile_data';

/// Enables the terminal-driven network-policy integration-test protocol.
///
/// Production builds do not set this define, and every test-only command also
/// rejects calls when it is false.
const bool networkPolicyTestHookEnabled = bool.fromEnvironment(
  'TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK',
);

enum TransferSuspensionReason {
  none,
  offline,
  mobileData,
  vpnTransportUnknown,
  metered,
}

typedef TransferPolicySnapshot = ({
  bool allowMeteredDownloads,
  bool allowMobileData,
  NetworkCost networkCost,
  NetworkTransport networkTransport,
  bool isVpn,
  TransferSuspensionReason reason,
  bool suspended,
});

const TransferPolicySnapshot initialTransferPolicySnapshot = (
  allowMeteredDownloads: false,
  allowMobileData: false,
  networkCost: NetworkCost.unknown,
  networkTransport: NetworkTransport.unknown,
  isVpn: false,
  reason: TransferSuspensionReason.none,
  suspended: false,
);

/// Evaluates Tamashii's app-level network policy without changing torrents.
///
/// Cost and transport are deliberately independent: a VPN may be backed by a
/// cellular or Wi-Fi transport, and may itself be metered or unmetered.
TransferPolicySnapshot evaluateTransferPolicy({
  required NetworkStatus networkStatus,
  required bool allowMeteredDownloads,
  required bool allowMobileData,
}) {
  final reason = switch (networkStatus) {
    NetworkStatus(cost: NetworkCost.offline) ||
    NetworkStatus(
      transport: NetworkTransport.offline,
    ) => TransferSuspensionReason.offline,
    NetworkStatus(transport: NetworkTransport.cellular) when !allowMobileData =>
      TransferSuspensionReason.mobileData,
    NetworkStatus(isVpn: true, transport: NetworkTransport.unknown)
        when !allowMobileData =>
      TransferSuspensionReason.vpnTransportUnknown,
    NetworkStatus(cost: NetworkCost.metered) when !allowMeteredDownloads =>
      TransferSuspensionReason.metered,
    _ => TransferSuspensionReason.none,
  };

  return (
    allowMeteredDownloads: allowMeteredDownloads,
    allowMobileData: allowMobileData,
    networkCost: networkStatus.cost,
    networkTransport: networkStatus.transport,
    isVpn: networkStatus.isVpn,
    reason: reason,
    suspended: reason != TransferSuspensionReason.none,
  );
}

String transferPolicyStatusText(TransferPolicySnapshot snapshot) {
  return switch (snapshot.reason) {
    TransferSuspensionReason.offline => 'Waiting for network',
    TransferSuspensionReason.mobileData => 'Waiting for Wi-Fi',
    TransferSuspensionReason.vpnTransportUnknown =>
      'Waiting for Wi-Fi (VPN transport unknown)',
    TransferSuspensionReason.metered => 'Waiting for an unmetered connection',
    TransferSuspensionReason.none
        when snapshot.networkTransport == NetworkTransport.cellular =>
      'Downloading over mobile data',
    TransferSuspensionReason.none
        when snapshot.isVpn &&
            snapshot.networkTransport == NetworkTransport.unknown =>
      'VPN transport unknown; mobile data allowed',
    TransferSuspensionReason.none
        when snapshot.networkCost == NetworkCost.metered =>
      'Downloading over a metered connection',
    TransferSuspensionReason.none
        when snapshot.networkCost == NetworkCost.unknown =>
      'Network cost unknown; downloads allowed',
    TransferSuspensionReason.none => 'Downloads allowed',
  };
}

Map<String, Object> serializeTransferPolicy(TransferPolicySnapshot snapshot) {
  return <String, Object>{
    'allowMeteredDownloads': snapshot.allowMeteredDownloads,
    'allowMobileData': snapshot.allowMobileData,
    'networkCost': snapshot.networkCost.name,
    'networkTransport': snapshot.networkTransport.name,
    'isVpn': snapshot.isVpn,
    'reason': snapshot.reason.name,
    'suspended': snapshot.suspended,
    'statusText': transferPolicyStatusText(snapshot),
  };
}

TransferPolicySnapshot deserializeTransferPolicy(Map<String, dynamic> data) {
  final networkCostName = data['networkCost'];
  final networkTransportName = data['networkTransport'];
  final allowMeteredDownloads = data['allowMeteredDownloads'];
  final allowMobileData = data['allowMobileData'];
  final isVpn = data['isVpn'];

  final networkCost = NetworkCost.values.where(
    (value) => value.name == networkCostName,
  );
  final networkTransport = NetworkTransport.values.where(
    (value) => value.name == networkTransportName,
  );

  if (allowMeteredDownloads is! bool ||
      allowMobileData is! bool ||
      isVpn is! bool ||
      networkCost.length != 1 ||
      networkTransport.length != 1) {
    throw const FormatException('Invalid transfer-policy status message.');
  }

  return evaluateTransferPolicy(
    networkStatus: NetworkStatus(
      cost: networkCost.single,
      transport: networkTransport.single,
      isVpn: isVpn,
    ),
    allowMeteredDownloads: allowMeteredDownloads,
    allowMobileData: allowMobileData,
  );
}

abstract interface class TorrentTransferRuntime {
  Future<void> initialize();

  Future<void> setTransfersSuspended(bool suspended);
}

final class SimpleTorrentTransferRuntime implements TorrentTransferRuntime {
  const SimpleTorrentTransferRuntime();

  @override
  Future<void> initialize() =>
      SimpleTorrent.init(config: tamashiiTorrentConfig);

  @override
  Future<void> setTransfersSuspended(bool suspended) =>
      SimpleTorrent.setTransfersSuspended(suspended);
}

abstract interface class NetworkStatusSource {
  Future<NetworkStatus> current();

  Stream<NetworkStatus> get changes;
}

final class PluginNetworkStatusSource implements NetworkStatusSource {
  const PluginNetworkStatusSource();

  @override
  Future<NetworkStatus> current() => currentNetworkStatus();

  @override
  Stream<NetworkStatus> get changes => onNetworkStatusChanged;
}

/// In-memory source instantiated only by the compile-time integration hook.
final class MutableNetworkStatusSource implements NetworkStatusSource {
  MutableNetworkStatusSource({
    NetworkStatus initial = const NetworkStatus(
      cost: NetworkCost.unmetered,
      transport: NetworkTransport.wifi,
      isVpn: false,
    ),
  }) : _current = initial;

  NetworkStatus _current;
  final StreamController<NetworkStatus> _changes =
      StreamController<NetworkStatus>.broadcast(sync: true);

  @override
  Stream<NetworkStatus> get changes => _changes.stream;

  @override
  Future<NetworkStatus> current() async => _current;

  void set(NetworkStatus value) {
    if (_current == value) {
      return;
    }
    _current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

typedef AllowMeteredDownloadsReader = Future<bool> Function();
typedef AllowMobileDataReader = Future<bool> Function();
typedef TransferPolicyListener = void Function(TransferPolicySnapshot snapshot);
typedef TransferPolicyErrorListener = void Function(
  Object error,
  StackTrace stackTrace,
);
typedef TransferPolicyRefreshCancellation = void Function();
typedef TransferPolicyPeriodicRefreshScheduler =
    TransferPolicyRefreshCancellation Function(
      Duration interval,
      Future<void> Function() refresh,
    );

/// Maps app resume events to an injected policy refresh callback.
final class TransferPolicyLifecycleObserver with WidgetsBindingObserver {
  factory TransferPolicyLifecycleObserver({required VoidCallback onResume}) =>
      TransferPolicyLifecycleObserver._(onResume);

  TransferPolicyLifecycleObserver._(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }
}

Future<bool> readAllowMeteredDownloadsPreference() async {
  final preferences = SharedPreferencesAsync();
  return await preferences.getBool(allowMeteredDownloadsPreferenceKey) ?? false;
}

Future<bool> readAllowMobileDataPreference() async {
  final preferences = SharedPreferencesAsync();
  return await preferences.getBool(allowMobileDataPreferenceKey) ?? false;
}

TransferPolicyRefreshCancellation _scheduleTransferPolicyPeriodicRefresh(
  Duration interval,
  Future<void> Function() refresh,
) {
  final timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  return timer.cancel;
}

/// Keeps a UI-side transfer-policy snapshot current without starting a torrent.
///
/// The initial query, route events, explicit refreshes, and periodic refreshes
/// all share one queue. This prevents an older, delayed query from overwriting a
/// newer result. Preference values are reread with every update so a page can
/// also use [refresh] after changing a setting or when the app resumes.
final class TransferPolicyStatusMonitor {
  factory TransferPolicyStatusMonitor({
    required NetworkStatusSource networkStatusSource,
    required AllowMeteredDownloadsReader readAllowMeteredDownloads,
    required AllowMobileDataReader readAllowMobileData,
    TransferPolicyListener? onChanged,
    TransferPolicyErrorListener? onError,
    Duration refreshInterval = const Duration(seconds: 30),
    TransferPolicyPeriodicRefreshScheduler schedulePeriodicRefresh =
        _scheduleTransferPolicyPeriodicRefresh,
  }) => TransferPolicyStatusMonitor._(
    networkStatusSource,
    readAllowMeteredDownloads,
    readAllowMobileData,
    onChanged,
    onError,
    refreshInterval,
    schedulePeriodicRefresh,
  );

  TransferPolicyStatusMonitor._(
    this._networkStatusSource,
    this._readAllowMeteredDownloads,
    this._readAllowMobileData,
    this._onChanged,
    this._onError,
    this._refreshInterval,
    this._schedulePeriodicRefresh,
  );

  final NetworkStatusSource _networkStatusSource;
  final AllowMeteredDownloadsReader _readAllowMeteredDownloads;
  final AllowMobileDataReader _readAllowMobileData;
  final TransferPolicyListener? _onChanged;
  final TransferPolicyErrorListener? _onError;
  final Duration _refreshInterval;
  final TransferPolicyPeriodicRefreshScheduler _schedulePeriodicRefresh;

  TransferPolicySnapshot _snapshot = initialTransferPolicySnapshot;
  Future<void> _pending = Future<void>.value();
  Future<void>? _initialization;
  StreamSubscription<NetworkStatus>? _networkSubscription;
  TransferPolicyRefreshCancellation? _cancelPeriodicRefresh;
  bool _hasSnapshot = false;
  bool _disposed = false;

  TransferPolicySnapshot get snapshot => _snapshot;

  /// Starts monitoring and immediately queries the current network route.
  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.error(
        StateError('TransferPolicyStatusMonitor has been disposed.'),
      );
    }

    return _initialization ??= _enqueueAndReport(() async {
      if (_disposed) {
        return;
      }

      // Subscribe before querying so a route event received during a delayed
      // current-value query is queued behind it and remains authoritative.
      _networkSubscription = _networkStatusSource.changes.listen(
        _handleNetworkStatus,
        onError: _handleNetworkError,
        onDone: _handleNetworkDone,
      );
      _cancelPeriodicRefresh = _schedulePeriodicRefresh(
        _refreshInterval,
        _refreshAutomatically,
      );
      await _refreshFromCurrent();
    });
  }

  /// Re-queries network and preference state, for example after app resume.
  Future<void> refresh() {
    if (_disposed) {
      return Future<void>.error(
        StateError('TransferPolicyStatusMonitor has been disposed.'),
      );
    }
    return _enqueueAndReport(_refreshFromCurrent);
  }

  void _handleNetworkStatus(NetworkStatus networkStatus) {
    if (_disposed) {
      return;
    }
    unawaited(
      _enqueueAndReport(() => _refreshFromNetworkStatus(networkStatus)),
    );
  }

  void _handleNetworkError(Object error, StackTrace stackTrace) {
    _enqueueFailure(error, stackTrace);
  }

  void _handleNetworkDone() {
    _enqueueFailure(
      StateError('The network-status stream closed.'),
      StackTrace.current,
    );
  }

  void _enqueueFailure(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }
    unawaited(
      _enqueue(() async {
        _reportFailure(error, stackTrace);
      }),
    );
  }

  Future<void> _refreshAutomatically() {
    if (_disposed) {
      return Future<void>.value();
    }
    return _enqueueAndReport(_refreshFromCurrent);
  }

  Future<void> _refreshFromCurrent() async {
    if (_disposed) {
      return;
    }
    final networkStatus = await _networkStatusSource.current();
    if (_disposed) {
      return;
    }
    await _refreshFromNetworkStatus(networkStatus);
  }

  Future<void> _refreshFromNetworkStatus(NetworkStatus networkStatus) async {
    if (_disposed) {
      return;
    }
    final allowMeteredDownloads = await _readAllowMeteredDownloads();
    if (_disposed) {
      return;
    }
    final allowMobileData = await _readAllowMobileData();
    if (_disposed) {
      return;
    }

    final next = evaluateTransferPolicy(
      networkStatus: networkStatus,
      allowMeteredDownloads: allowMeteredDownloads,
      allowMobileData: allowMobileData,
    );
    if (_hasSnapshot && next == _snapshot) {
      return;
    }

    _snapshot = next;
    _hasSnapshot = true;
    _onChanged?.call(next);
  }

  Future<void> _enqueueAndReport(Future<void> Function() operation) =>
      _enqueue(() async {
        try {
          await operation();
        } on Object catch (error, stackTrace) {
          _reportFailure(error, stackTrace);
        }
      });

  void _reportFailure(Object error, StackTrace stackTrace) {
    if (_disposed) {
      return;
    }

    final unavailable = evaluateTransferPolicy(
      networkStatus: _detectionUnavailableStatus,
      allowMeteredDownloads: _snapshot.allowMeteredDownloads,
      allowMobileData: _snapshot.allowMobileData,
    );
    if (!_hasSnapshot || unavailable != _snapshot) {
      _snapshot = unavailable;
      _hasSnapshot = true;
      _onChanged?.call(unavailable);
    }
    _onError?.call(error, stackTrace);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    final cancelPeriodicRefresh = _cancelPeriodicRefresh;
    _cancelPeriodicRefresh = null;
    cancelPeriodicRefresh?.call();

    final networkSubscription = _networkSubscription;
    _networkSubscription = null;
    await networkSubscription?.cancel();
    await _pending;
  }
}

/// Owns the process-local global transfer gate for one torrent engine.
///
/// Policy updates are serialized so a delayed network callback cannot reorder
/// itself with a setting change. Per-torrent pause and resume operations never
/// pass through this controller.
final class TransferPolicyController {
  factory TransferPolicyController({
    required TorrentTransferRuntime runtime,
    required NetworkStatusSource networkStatusSource,
    required AllowMeteredDownloadsReader readAllowMeteredDownloads,
    required AllowMobileDataReader readAllowMobileData,
    TransferPolicyListener? onChanged,
    TransferPolicyErrorListener? onError,
  }) {
    return TransferPolicyController._(
      runtime,
      networkStatusSource,
      readAllowMeteredDownloads,
      readAllowMobileData,
      onChanged,
      onError,
    );
  }

  TransferPolicyController._(
    this._runtime,
    this._networkStatusSource,
    this._readAllowMeteredDownloads,
    this._readAllowMobileData,
    this._onChanged,
    this._onError,
  );

  final TorrentTransferRuntime _runtime;
  final NetworkStatusSource _networkStatusSource;
  final AllowMeteredDownloadsReader _readAllowMeteredDownloads;
  final AllowMobileDataReader _readAllowMobileData;
  final TransferPolicyListener? _onChanged;
  final TransferPolicyErrorListener? _onError;

  TransferPolicySnapshot _snapshot = initialTransferPolicySnapshot;
  Future<void> _pending = Future<void>.value();
  Future<void>? _initialization;
  StreamSubscription<NetworkStatus>? _networkSubscription;
  bool _initialized = false;
  bool _disposed = false;

  TransferPolicySnapshot get snapshot => _snapshot;

  Future<void> initialize() => _initialization ??= _enqueue(() async {
    _ensureNotDisposed();
    await _runtime.initialize();

    final allowMeteredDownloads = await _readAllowMeteredDownloads();
    final allowMobileData = await _readAllowMobileData();

    // Subscribe before querying. If the network changes during the query, the
    // callback is queued behind this initialization and becomes authoritative.
    _networkSubscription = _networkStatusSource.changes.listen(
      (networkStatus) => unawaited(_applyNetworkStatus(networkStatus)),
      onError: (Object error, StackTrace stackTrace) =>
          unawaited(_failClosedAfterDetectionFailure(error, stackTrace)),
      onDone: () => unawaited(
        _failClosedAfterDetectionFailure(
          StateError('The Android network-status stream closed.'),
          StackTrace.current,
        ),
      ),
    );
    final networkStatus = await _networkStatusSource.current();

    _snapshot = evaluateTransferPolicy(
      networkStatus: networkStatus,
      allowMeteredDownloads: allowMeteredDownloads,
      allowMobileData: allowMobileData,
    );
    await _runtime.setTransfersSuspended(_snapshot.suspended);
    _initialized = true;
    _onChanged?.call(_snapshot);
  });

  Future<void> setAllowMeteredDownloads(bool allow) => _enqueue(() async {
    _ensureInitialized();
    if (_snapshot.allowMeteredDownloads == allow) {
      return;
    }

    await _apply(
      evaluateTransferPolicy(
        networkStatus: _networkStatusFromSnapshot(_snapshot),
        allowMeteredDownloads: allow,
        allowMobileData: _snapshot.allowMobileData,
      ),
    );
  });

  Future<void> setAllowMobileData(bool allow) => _enqueue(() async {
    _ensureInitialized();
    if (_snapshot.allowMobileData == allow) {
      return;
    }

    await _apply(
      evaluateTransferPolicy(
        networkStatus: _networkStatusFromSnapshot(_snapshot),
        allowMeteredDownloads: _snapshot.allowMeteredDownloads,
        allowMobileData: allow,
      ),
    );
  });

  /// Reasserts policy after a native manager is recreated in the same engine.
  Future<void> reapply() => _enqueue(() async {
    _ensureInitialized();
    await _runtime.setTransfersSuspended(_snapshot.suspended);
    _onChanged?.call(_snapshot);
  });

  /// Re-queries the route in case the platform emitted no change event.
  Future<void> refresh() async {
    try {
      await _enqueue(() async {
        _ensureInitialized();
        final allowMeteredDownloads = await _readAllowMeteredDownloads();
        final allowMobileData = await _readAllowMobileData();
        final networkStatus = await _networkStatusSource.current();
        final next = evaluateTransferPolicy(
          networkStatus: networkStatus,
          allowMeteredDownloads: allowMeteredDownloads,
          allowMobileData: allowMobileData,
        );
        if (_snapshot == next) {
          return;
        }

        await _apply(next);
      });
    } on Object catch (error, stackTrace) {
      await _failClosedAfterDetectionFailure(error, stackTrace);
    }
  }

  Future<void> refreshNetworkStatus() => refresh();

  Future<void> _setNetworkStatus(NetworkStatus networkStatus) =>
      _enqueue(() async {
        _ensureInitialized();
        if (_networkStatusFromSnapshot(_snapshot) == networkStatus) {
          return;
        }

        await _apply(
          evaluateTransferPolicy(
            networkStatus: networkStatus,
            allowMeteredDownloads: _snapshot.allowMeteredDownloads,
            allowMobileData: _snapshot.allowMobileData,
          ),
        );
      });

  Future<void> _applyNetworkStatus(NetworkStatus networkStatus) async {
    try {
      await _setNetworkStatus(networkStatus);
    } on Object catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  Future<void> _failClosedAfterDetectionFailure(
    Object sourceError,
    StackTrace sourceStackTrace,
  ) async {
    try {
      await _setNetworkStatus(_detectionUnavailableStatus);
    } on Object catch (error, stackTrace) {
      _onError?.call(
        StateError(
          'Unable to suspend transfers after network detection failed. '
          'Detection error: $sourceError; suspension error: $error',
        ),
        stackTrace,
      );
      return;
    }

    // The gate is safely closed. Retain the source failure in diagnostics
    // without treating it as an ordinary, fail-open unknown network.
    _onError?.call(sourceError, sourceStackTrace);
  }

  Future<void> _apply(TransferPolicySnapshot next) async {
    if (_snapshot.suspended != next.suspended) {
      await _runtime.setTransfersSuspended(next.suspended);
    }
    _snapshot = next;
    _onChanged?.call(next);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    if (_disposed) {
      return Future<void>.error(
        StateError('TransferPolicyController has been disposed.'),
      );
    }

    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _ensureInitialized() {
    _ensureNotDisposed();
    if (!_initialized) {
      throw StateError('TransferPolicyController is not initialized.');
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('TransferPolicyController has been disposed.');
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _networkSubscription?.cancel();
    await _pending;
  }
}

NetworkStatus _networkStatusFromSnapshot(TransferPolicySnapshot snapshot) {
  return NetworkStatus(
    cost: snapshot.networkCost,
    transport: snapshot.networkTransport,
    isVpn: snapshot.isVpn,
  );
}

const NetworkStatus _detectionUnavailableStatus = NetworkStatus(
  cost: NetworkCost.offline,
  transport: NetworkTransport.offline,
  isVpn: false,
);
