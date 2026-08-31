const bool useTestTorrent = bool.fromEnvironment('TAMASHII_USE_TEST_TORRENT');

const String testTorrentMagnetUri =
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

/// Returns the magnet URI that the torrent engine must receive.
///
/// Development builds should set `TAMASHII_USE_TEST_TORRENT=true` so every
/// download uses the small Big Buck Bunny torrent instead of production media.
String resolveTorrentMagnetUri(
  String requestedMagnetUri, {
  bool? testTorrentEnabled,
}) {
  return (testTorrentEnabled ?? useTestTorrent)
      ? testTorrentMagnetUri
      : requestedMagnetUri;
}
