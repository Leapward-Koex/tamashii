import 'package:flutter/services.dart';

const _methodsChannelName = 'com.leapwardkoex.tamashii/network_cost/methods';
const _statusEventsChannelName =
    'com.leapwardkoex.tamashii/network_cost/status_events';

/// How Android classifies the cost of the current default network.
enum NetworkCost { offline, metered, unmetered, unknown }

/// The physical transport carrying the current Android default network.
///
/// Android reports all transports used by a VPN, so a VPN over cellular is
/// represented by [cellular] with [NetworkStatus.isVpn] set to true. When the
/// VPN does not expose its underlay, the transport is [unknown].
enum NetworkTransport { offline, cellular, wifi, other, unknown }

/// Android's cost and transport classification of the default network.
final class NetworkStatus {
  const NetworkStatus({
    required this.cost,
    required this.transport,
    required this.isVpn,
  });

  final NetworkCost cost;
  final NetworkTransport transport;
  final bool isVpn;

  /// Whether the default route is carried by a cellular network, including a
  /// VPN whose cellular underlay is exposed by Android.
  bool get usesCellular => transport == NetworkTransport.cellular;

  @override
  bool operator ==(Object other) =>
      other is NetworkStatus &&
      cost == other.cost &&
      transport == other.transport &&
      isVpn == other.isVpn;

  @override
  int get hashCode => Object.hash(cost, transport, isVpn);

  @override
  String toString() =>
      'NetworkStatus(cost: $cost, transport: $transport, isVpn: $isVpn)';
}

/// Injectable interface used by the torrent transfer policy.
abstract interface class NetworkCostClient {
  Future<NetworkCost> currentNetworkCost();

  Stream<NetworkCost> get onNetworkCostChanged;
}

/// Injectable interface for consumers that need transport-aware policy.
abstract interface class NetworkStatusClient {
  Future<NetworkStatus> currentNetworkStatus();

  Stream<NetworkStatus> get onNetworkStatusChanged;
}

/// Android MethodChannel/EventChannel implementation.
final class MethodChannelNetworkCostClient
    implements NetworkCostClient, NetworkStatusClient {
  const MethodChannelNetworkCostClient({
    this.methodChannel = const MethodChannel(_methodsChannelName),
    this.eventChannel = const EventChannel(_statusEventsChannelName),
  });

  final MethodChannel methodChannel;
  final EventChannel eventChannel;

  @override
  Future<NetworkCost> currentNetworkCost() async =>
      (await currentNetworkStatus()).cost;

  @override
  Future<NetworkStatus> currentNetworkStatus() async {
    final value = await methodChannel.invokeMethod<Object?>(
      'currentNetworkStatus',
    );
    return _decodeNetworkStatus(value);
  }

  @override
  Stream<NetworkCost> get onNetworkCostChanged =>
      onNetworkStatusChanged.map((status) => status.cost).distinct();

  @override
  Stream<NetworkStatus> get onNetworkStatusChanged => eventChannel
      .receiveBroadcastStream()
      .map(_decodeNetworkStatus)
      .distinct();
}

const MethodChannelNetworkCostClient _defaultClient =
    MethodChannelNetworkCostClient();

/// Returns Android's current network-cost classification.
Future<NetworkCost> currentNetworkCost() => _defaultClient.currentNetworkCost();

/// Emits an initial classification and every subsequent distinct change.
Stream<NetworkCost> get onNetworkCostChanged =>
    _defaultClient.onNetworkCostChanged;

/// Returns Android's current cost-and-transport classification.
Future<NetworkStatus> currentNetworkStatus() =>
    _defaultClient.currentNetworkStatus();

/// Emits an initial status and every subsequent distinct change.
Stream<NetworkStatus> get onNetworkStatusChanged =>
    _defaultClient.onNetworkStatusChanged;

NetworkStatus _decodeNetworkStatus(Object? value) {
  if (value case final Map<Object?, Object?> map) {
    final cost = _tryDecodeEnum(NetworkCost.values, map['cost']);
    final transport = _tryDecodeEnum(NetworkTransport.values, map['transport']);
    final isVpn = map['isVpn'];
    if (cost != null && transport != null && isVpn is bool) {
      return NetworkStatus(cost: cost, transport: transport, isVpn: isVpn);
    }
  }

  throw PlatformException(
    code: 'invalid_response',
    message: 'Expected a valid Android network-status map, got $value.',
  );
}

T? _tryDecodeEnum<T extends Enum>(List<T> values, Object? value) {
  if (value case final String wireValue) {
    for (final item in values) {
      if (item.name == wireValue) {
        return item;
      }
    }
  }
  return null;
}
