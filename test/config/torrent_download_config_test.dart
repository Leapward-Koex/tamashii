import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/config/torrent_download_config.dart';

const expectedTestTorrentMagnetUri =
    'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c'
    '&dn=Big+Buck+Bunny'
    '&tr=udp%3A%2F%2Fexplodie.org%3A6969'
    '&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969'
    '&tr=udp%3A%2F%2Ftracker.empire-js.us%3A1337'
    '&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969'
    '&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337'
    '&tr=wss%3A%2F%2Ftracker.btorrent.xyz'
    '&tr=wss%3A%2F%2Ftracker.fastcast.nz'
    '&tr=wss%3A%2F%2Ftracker.openwebtorrent.com'
    '&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F'
    '&xs=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2Fbig-buck-bunny.torrent';

void main() {
  group('resolveTorrentMagnetUri', () {
    test(
      'preserves the requested magnet when the test override is disabled',
      () {
        const requestedMagnet = 'magnet:?xt=urn:btih:production-torrent';

        final resolved = resolveTorrentMagnetUri(
          requestedMagnet,
          testTorrentEnabled: false,
        );

        expect(resolved, requestedMagnet);
      },
    );

    test(
      'replaces every requested magnet when the test override is enabled',
      () {
        expect(testTorrentMagnetUri, expectedTestTorrentMagnetUri);

        const requestedMagnets = <String>[
          'magnet:?xt=urn:btih:first-production-torrent',
          'magnet:?xt=urn:btih:second-production-torrent',
        ];

        for (final requestedMagnet in requestedMagnets) {
          expect(
            resolveTorrentMagnetUri(requestedMagnet, testTorrentEnabled: true),
            testTorrentMagnetUri,
          );
        }
      },
    );

    test('uses the compile-time setting by default', () {
      const requestedMagnet = 'magnet:?xt=urn:btih:production-torrent';

      expect(
        resolveTorrentMagnetUri(requestedMagnet),
        useTestTorrent ? testTorrentMagnetUri : requestedMagnet,
      );
    });
  });
}
