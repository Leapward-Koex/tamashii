import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:simple_torrent/simple_torrent.dart';

void main() {
  test(
    'bulk acknowledgements immediately apply paused state and clear errors',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final manager = container.read(foregroundTorrentManagerProvider.notifier);

      manager.handleServiceData({
        'type': 'bulk_torrent_states',
        'states': {
          'episode-1': {
            'torrentId': 7,
            'stats': _stats.toMap(),
            'metadata': _metadata.toMap(),
            'isPaused': false,
            'errorMessage': 'The prior pause command failed.',
          },
        },
      });
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.errorMessage,
        'The prior pause command failed.',
      );
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.stats
            ?.progress,
        0.5,
      );
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.metadata
            ?.name,
        'Episode 1',
      );

      manager.handleServiceData({
        'type': 'all_paused',
        'torrentKeys': ['episode-1'],
        'requestId': 99,
      });
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.isPaused,
        isFalse,
      );

      manager.handleServiceData({
        'type': 'all_paused',
        'torrentKeys': ['episode-1'],
      });
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.isPaused,
        isTrue,
      );
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.errorMessage,
        isNull,
      );

      manager.handleServiceData({
        'type': 'all_resumed',
        'torrentKeys': ['episode-1'],
      });
      expect(
        container
            .read(foregroundTorrentManagerProvider)
            .torrents['episode-1']
            ?.isPaused,
        isFalse,
      );
    },
  );

  test('ignores a bulk acknowledgement from a retired service instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final manager = container.read(foregroundTorrentManagerProvider.notifier);
    final policy = serializeTransferPolicy(initialTransferPolicySnapshot);

    manager.handleServiceData({
      'type': 'service_ready',
      'serviceInstanceId': 'service-1',
      ...policy,
    });
    manager.handleServiceData({
      'type': 'service_ready',
      'serviceInstanceId': 'service-2',
      ...policy,
    });
    manager.handleServiceData({
      'type': 'bulk_torrent_states',
      'serviceInstanceId': 'service-2',
      'states': {
        'episode-2': {'torrentId': 8, 'isPaused': false},
      },
    });

    manager.handleServiceData({
      'type': 'all_paused',
      'serviceInstanceId': 'service-1',
      'torrentKeys': ['episode-2'],
    });

    expect(
      container
          .read(foregroundTorrentManagerProvider)
          .torrents['episode-2']
          ?.isPaused,
      isFalse,
    );
  });
}

const TorrentStats _stats = TorrentStats(
  id: 7,
  downloadRate: 1024,
  uploadRate: 512,
  pieces: 1,
  piecesTotal: 2,
  progress: 0.5,
  seeds: 4,
  peers: 2,
  state: TorrentState.downloading,
);

const TorrentMetadata _metadata = TorrentMetadata(
  id: 7,
  name: 'Episode 1',
  totalBytes: 2048,
  pieceSize: 1024,
  pieceCount: 2,
  fileCount: 1,
  creationDate: 0,
  isPrivate: false,
);
