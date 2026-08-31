import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_download_config.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

const int _testTimeoutMinutes = int.fromEnvironment(
  'TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES',
  defaultValue: 5,
);
const bool _keepTestDataOnFailure = bool.fromEnvironment(
  'TAMASHII_KEEP_NETWORK_POLICY_TEST_DATA',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android foreground manager gates queued and manually paused torrents',
    (WidgetTester _) async {
      expect(Platform.isAndroid, isTrue, reason: 'This test is Android-only.');
      expect(
        networkPolicyTestHookEnabled,
        isTrue,
        reason:
            'Run with '
            '--dart-define=TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK=true.',
      );
      expect(
        useTestTorrent,
        isTrue,
        reason:
            'Run with --dart-define=TAMASHII_USE_TEST_TORRENT=true so this '
            'test can never download production media.',
      );

      final preferences = SharedPreferencesAsync();
      await preferences.setBool(allowMeteredDownloadsPreferenceKey, false);
      await preferences.setBool(allowMobileDataPreferenceKey, false);

      final testDirectory = await Directory.systemTemp.createTemp(
        'tamashii-network-policy-',
      );
      final torrentKey =
          'network-policy-${DateTime.now().microsecondsSinceEpoch}';
      // The runner retains this path on request after a failed test.
      // ignore: avoid_print
      print('TAMASHII_NETWORK_POLICY_TEST_DIRECTORY=${testDirectory.path}');

      final container = ProviderContainer();
      final manager = container.read(foregroundTorrentManagerProvider.notifier);
      var serviceStarted = false;
      var torrentStarted = false;
      var testPassed = false;

      try {
        serviceStarted = true;
        await manager.startNetworkPolicyTestService();
        await manager.setAllowMeteredDownloads(false);
        await manager.setAllowMobileData(false);
        await manager.setTestNetworkStatus(_unmeteredWifi);

        expect(container.read(foregroundTransferPolicyStatusProvider), (
          allowMeteredDownloads: false,
          allowMobileData: false,
          networkCost: NetworkCost.unmetered,
          networkTransport: NetworkTransport.wifi,
          isVpn: false,
          reason: TransferSuspensionReason.none,
          suspended: false,
        ));
        expect(await manager.queryTestTransfersSuspended(), isFalse);

        // A cellular-backed VPN is still mobile data, even if Android reports
        // its cost as unmetered. Suspend first, then start: the native manager
        // must return an active ID while leaving the torrent queued in the
        // paused session.
        await manager.setTestNetworkStatus(_unmeteredCellularVpn);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.mobileData,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.startDownload(
          torrentKey,
          testTorrentMagnetUri,
          testDirectory.path,
        );
        final queuedTorrent = await _waitForActiveTorrent(
          container,
          torrentKey,
        );
        torrentStarted = true;
        expect(queuedTorrent.torrentId, greaterThan(0));

        final queuedState = await manager.queryTestTorrentState(torrentKey);
        expect(
          queuedState,
          isNot(anyOf(TorrentState.error, TorrentState.stopped)),
        );

        final piecesBefore = queuedTorrent.stats?.verifiedPieces ?? 0;
        final progressBefore = queuedTorrent.stats?.progress ?? 0;
        await Future<void>.delayed(const Duration(seconds: 3));
        final stableTorrent = _torrentState(container, torrentKey);
        expect(stableTorrent.stats?.verifiedPieces ?? 0, piecesBefore);
        expect(stableTorrent.stats?.progress ?? 0, progressBefore);

        // An individual pause remains authoritative when the session-wide gate
        // is subsequently opened.
        await manager.pauseDownload(torrentKey);
        expect(
          await manager.queryTestTorrentState(torrentKey),
          TorrentState.paused,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.setAllowMobileData(true);
        expect(await manager.queryTestTransfersSuspended(), isFalse);
        expect(
          await manager.queryTestTorrentState(torrentKey),
          TorrentState.paused,
          reason: 'Global resume must not resume a manually paused torrent.',
        );

        // Revoking the mobile-data permission suspends this cellular VPN
        // again. Moving the same VPN to known unmetered Wi-Fi then opens the
        // global gate without touching the torrent's individual pause state.
        await manager.setAllowMobileData(false);
        expect(await manager.queryTestTransfersSuspended(), isTrue);
        await manager.setTestNetworkStatus(_unmeteredWifiVpn);
        expect(await manager.queryTestTransfersSuspended(), isFalse);
        expect(
          await manager.queryTestTorrentState(torrentKey),
          TorrentState.paused,
          reason: 'VPN over Wi-Fi must not resume a manually paused torrent.',
        );

        // Metering remains an independent policy. Metered Wi-Fi is blocked
        // when its setting is off, even though the connection is not cellular.
        await manager.setTestNetworkStatus(_meteredWifiVpn);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.metered,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.setAllowMeteredDownloads(true);
        expect(await manager.queryTestTransfersSuspended(), isFalse);
        expect(
          await manager.queryTestTorrentState(torrentKey),
          TorrentState.paused,
          reason: 'Opening the metered gate must preserve manual pause.',
        );

        await manager.setAllowMeteredDownloads(false);
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        // If Android cannot identify a VPN's underlying transport, the
        // default-deny mobile-data policy is conservative. The explicit mobile
        // opt-in opens it; ordinary non-VPN unknown networks still fail open.
        await manager.setTestNetworkStatus(_unknownVpn);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.vpnTransportUnknown,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.setAllowMobileData(true);
        expect(await manager.queryTestTransfersSuspended(), isFalse);
        expect(
          await manager.queryTestTorrentState(torrentKey),
          TorrentState.paused,
        );

        await manager.setAllowMobileData(false);
        expect(await manager.queryTestTransfersSuspended(), isTrue);
        await manager.setTestNetworkStatus(_unknownNonVpn);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.none,
        );
        expect(await manager.queryTestTransfersSuspended(), isFalse);

        // Offline always wins, including when both paid-network permissions
        // are enabled.
        await manager.setAllowMeteredDownloads(true);
        await manager.setAllowMobileData(true);
        await manager.setTestNetworkStatus(_offline);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.offline,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.resumeDownload(torrentKey);
        final resumedState = await _waitForTorrentState(
          manager,
          torrentKey,
          (state) => state != TorrentState.paused,
        );
        expect(
          resumedState,
          isNot(anyOf(TorrentState.error, TorrentState.stopped)),
          reason: 'Per-torrent resume remains valid while globally suspended.',
        );

        await manager.removeDownload(torrentKey);
        await _waitForTorrentRemoved(container, torrentKey);
        torrentStarted = false;

        // Recreate the foreground task/native manager with deliberately
        // different persisted values. This proves both independent settings
        // are reread rather than inherited from the destroyed native manager.
        await preferences.setBool(allowMeteredDownloadsPreferenceKey, true);
        await preferences.setBool(allowMobileDataPreferenceKey, false);
        await manager.stopNetworkPolicyTestService();
        serviceStarted = false;

        serviceStarted = true;
        await manager.startNetworkPolicyTestService();
        final recreatedPolicy = container.read(
          foregroundTransferPolicyStatusProvider,
        );
        expect(recreatedPolicy.allowMeteredDownloads, isTrue);
        expect(recreatedPolicy.allowMobileData, isFalse);
        expect(await manager.queryTestTransfersSuspended(), isFalse);

        await manager.setTestNetworkStatus(_meteredWifi);
        expect(await manager.queryTestTransfersSuspended(), isFalse);

        await manager.setTestNetworkStatus(_unmeteredCellularVpn);
        expect(
          container.read(foregroundTransferPolicyStatusProvider).reason,
          TransferSuspensionReason.mobileData,
        );
        expect(await manager.queryTestTransfersSuspended(), isTrue);

        await manager.stopNetworkPolicyTestService();
        serviceStarted = false;
        await preferences.setBool(allowMeteredDownloadsPreferenceKey, false);
        await preferences.setBool(allowMobileDataPreferenceKey, false);
        await testDirectory.delete(recursive: true);
        testPassed = true;
      } finally {
        final preserveFailure = !testPassed && _keepTestDataOnFailure;
        try {
          await preferences.setBool(allowMeteredDownloadsPreferenceKey, false);
          await preferences.setBool(allowMobileDataPreferenceKey, false);
        } on Object catch (error) {
          // ignore: avoid_print
          print('Best-effort policy-preference cleanup failed: $error');
        }
        if (torrentStarted && !preserveFailure) {
          try {
            await manager.removeDownload(torrentKey);
            await Future<void>.delayed(const Duration(milliseconds: 500));
          } on Object catch (error) {
            // ignore: avoid_print
            print('Best-effort torrent cleanup failed: $error');
          }
        }
        if (serviceStarted) {
          try {
            await manager.stopNetworkPolicyTestService();
          } on Object catch (error) {
            // ignore: avoid_print
            print('Best-effort service cleanup failed: $error');
          }
        }
        container.dispose();

        if (!preserveFailure && await testDirectory.exists()) {
          await testDirectory.delete(recursive: true);
        } else if (preserveFailure) {
          // ignore: avoid_print
          print(
            'TAMASHII_NETWORK_POLICY_TEST_DATA_PRESERVED='
            '${testDirectory.path}',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: _testTimeoutMinutes)),
  );
}

const NetworkStatus _unmeteredWifi = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.wifi,
  isVpn: false,
);

const NetworkStatus _unmeteredCellularVpn = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.cellular,
  isVpn: true,
);

const NetworkStatus _unmeteredWifiVpn = NetworkStatus(
  cost: NetworkCost.unmetered,
  transport: NetworkTransport.wifi,
  isVpn: true,
);

const NetworkStatus _meteredWifiVpn = NetworkStatus(
  cost: NetworkCost.metered,
  transport: NetworkTransport.wifi,
  isVpn: true,
);

const NetworkStatus _meteredWifi = NetworkStatus(
  cost: NetworkCost.metered,
  transport: NetworkTransport.wifi,
  isVpn: false,
);

const NetworkStatus _unknownVpn = NetworkStatus(
  cost: NetworkCost.unknown,
  transport: NetworkTransport.unknown,
  isVpn: true,
);

const NetworkStatus _unknownNonVpn = NetworkStatus(
  cost: NetworkCost.unknown,
  transport: NetworkTransport.unknown,
  isVpn: false,
);

const NetworkStatus _offline = NetworkStatus(
  cost: NetworkCost.offline,
  transport: NetworkTransport.offline,
  isVpn: false,
);

TorrentDownloadState _torrentState(
  ProviderContainer container,
  String torrentKey,
) {
  return container
          .read(foregroundTorrentManagerProvider)
          .torrents[torrentKey] ??
      const TorrentDownloadState();
}

Future<TorrentDownloadState> _waitForActiveTorrent(
  ProviderContainer container,
  String torrentKey,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 30)) {
    final torrent = _torrentState(container, torrentKey);
    final error = torrent.errorMessage;
    if (error != null) {
      throw TestFailure('Torrent start failed: $error');
    }
    if (torrent.torrentId case final int id when id > 0) {
      return torrent;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out waiting for the queued torrent to start.');
}

Future<void> _waitForTorrentRemoved(
  ProviderContainer container,
  String torrentKey,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 20)) {
    final torrent = _torrentState(container, torrentKey);
    if (torrent.torrentId == null) {
      return;
    }
    if (torrent.errorMessage case final String error) {
      throw TestFailure('Torrent removal failed: $error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out waiting for the queued torrent to be removed.');
}

Future<TorrentState> _waitForTorrentState(
  ForegroundTorrentManager manager,
  String torrentKey,
  bool Function(TorrentState state) predicate,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 20)) {
    final state = await manager.queryTestTorrentState(torrentKey);
    if (predicate(state)) {
      return state;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out waiting for torrent state to change.');
}
