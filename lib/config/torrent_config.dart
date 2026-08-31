import 'package:simple_torrent/simple_torrent.dart';

/// The native torrent settings shared by Tamashii's UI and background engines.
const TorrentConfig tamashiiTorrentConfig = TorrentConfig(
  maxTorrents: 30,
  uploadRateLimit: 1024 * 1024,
  userAgent: 'Tamashii/2.0',
);

/// Produces a user-facing message while preserving v2's typed error code.
String describeTorrentError(Object error) {
  if (error is SimpleTorrentException) {
    return '${error.code.wireName}: ${error.message}';
  }
  return error.toString();
}
