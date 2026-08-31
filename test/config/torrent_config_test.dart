import 'package:flutter_test/flutter_test.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/config/torrent_config.dart';

void main() {
  test('shared torrent config retains the intended v2 upload limit', () {
    expect(tamashiiTorrentConfig.maxTorrents, 30);
    expect(tamashiiTorrentConfig.uploadRateLimit, 1024 * 1024);
    expect(tamashiiTorrentConfig.userAgent, 'Tamashii/2.0');
  });

  test('typed v2 errors retain their stable wire code', () {
    const error = SimpleTorrentException(
      SimpleTorrentErrorCode.invalidMagnet,
      'The magnet URI is invalid.',
    );

    expect(
      describeTorrentError(error),
      'invalid_magnet: The magnet URI is invalid.',
    );
    expect(describeTorrentError(StateError('failed')), contains('failed'));
  });
}
