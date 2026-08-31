import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('test/network_cost/methods');
  const eventChannel = EventChannel('test/network_cost/status_events');
  const client = MethodChannelNetworkCostClient(
    methodChannel: methodChannel,
    eventChannel: eventChannel,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  test('currentNetworkStatus decodes all policy-relevant snapshots', () async {
    const expectedStatuses = <NetworkStatus>[
      NetworkStatus(
        cost: NetworkCost.offline,
        transport: NetworkTransport.offline,
        isVpn: false,
      ),
      NetworkStatus(
        cost: NetworkCost.metered,
        transport: NetworkTransport.cellular,
        isVpn: false,
      ),
      NetworkStatus(
        cost: NetworkCost.unmetered,
        transport: NetworkTransport.wifi,
        isVpn: true,
      ),
      NetworkStatus(
        cost: NetworkCost.unknown,
        transport: NetworkTransport.other,
        isVpn: false,
      ),
      NetworkStatus(
        cost: NetworkCost.unknown,
        transport: NetworkTransport.unknown,
        isVpn: true,
      ),
    ];

    for (final expected in expectedStatuses) {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'currentNetworkStatus');
        expect(call.arguments, isNull);
        return _wireStatus(expected);
      });

      expect(await client.currentNetworkStatus(), expected);
      expect(
        expected.usesCellular,
        expected.transport == NetworkTransport.cellular,
      );
    }
  });

  test('legacy cost query projects the typed status', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, 'currentNetworkStatus');
      return _wireStatus(
        const NetworkStatus(
          cost: NetworkCost.metered,
          transport: NetworkTransport.cellular,
          isVpn: true,
        ),
      );
    });

    expect(await client.currentNetworkCost(), NetworkCost.metered);
  });

  test('currentNetworkStatus rejects malformed platform responses', () async {
    final invalidValues = <Object?>[
      null,
      true,
      1,
      'cellular',
      <String, Object?>{},
      <String, Object?>{'cost': 'invalid', 'transport': 'wifi', 'isVpn': false},
      <String, Object?>{
        'cost': 'metered',
        'transport': 'invalid',
        'isVpn': false,
      },
      <String, Object?>{'cost': 'metered', 'transport': 'cellular', 'isVpn': 1},
    ];

    for (final invalid in invalidValues) {
      messenger.setMockMethodCallHandler(methodChannel, (_) async => invalid);

      await expectLater(
        client.currentNetworkStatus(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
  });

  test('status stream decodes and removes duplicate snapshots', () async {
    const wifi = NetworkStatus(
      cost: NetworkCost.unmetered,
      transport: NetworkTransport.wifi,
      isVpn: true,
    );
    const cellular = NetworkStatus(
      cost: NetworkCost.metered,
      transport: NetworkTransport.cellular,
      isVpn: true,
    );
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(_wireStatus(wifi));
          events.success(_wireStatus(wifi));
          events.success(_wireStatus(cellular));
          events.endOfStream();
        },
      ),
    );

    expect(await client.onNetworkStatusChanged.toList(), const <NetworkStatus>[
      wifi,
      cellular,
    ]);
  });

  test('legacy cost stream de-duplicates cost-only projection', () async {
    const wifi = NetworkStatus(
      cost: NetworkCost.unmetered,
      transport: NetworkTransport.wifi,
      isVpn: false,
    );
    const vpnWifi = NetworkStatus(
      cost: NetworkCost.unmetered,
      transport: NetworkTransport.wifi,
      isVpn: true,
    );
    const cellular = NetworkStatus(
      cost: NetworkCost.metered,
      transport: NetworkTransport.cellular,
      isVpn: true,
    );
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(_wireStatus(wifi));
          events.success(_wireStatus(vpnWifi));
          events.success(_wireStatus(cellular));
          events.endOfStream();
        },
      ),
    );

    expect(await client.onNetworkCostChanged.toList(), const <NetworkCost>[
      NetworkCost.unmetered,
      NetworkCost.metered,
    ]);
  });

  test('retains the injectable legacy and typed contracts', () async {
    final costClient = _FakeNetworkCostClient();
    final statusClient = _FakeNetworkStatusClient();

    expect(await costClient.currentNetworkCost(), NetworkCost.unknown);
    expect(await costClient.onNetworkCostChanged.toList(), const <NetworkCost>[
      NetworkCost.metered,
      NetworkCost.unmetered,
    ]);
    expect(
      await statusClient.currentNetworkStatus(),
      const NetworkStatus(
        cost: NetworkCost.unknown,
        transport: NetworkTransport.unknown,
        isVpn: true,
      ),
    );
  });
}

Map<String, Object> _wireStatus(NetworkStatus status) => <String, Object>{
  'cost': status.cost.name,
  'transport': status.transport.name,
  'isVpn': status.isVpn,
};

final class _FakeNetworkCostClient implements NetworkCostClient {
  @override
  Future<NetworkCost> currentNetworkCost() async => NetworkCost.unknown;

  @override
  Stream<NetworkCost> get onNetworkCostChanged => Stream.fromIterable(
    const <NetworkCost>[NetworkCost.metered, NetworkCost.unmetered],
  );
}

final class _FakeNetworkStatusClient implements NetworkStatusClient {
  @override
  Future<NetworkStatus> currentNetworkStatus() async => const NetworkStatus(
    cost: NetworkCost.unknown,
    transport: NetworkTransport.unknown,
    isVpn: true,
  );

  @override
  Stream<NetworkStatus> get onNetworkStatusChanged => const Stream.empty();
}
