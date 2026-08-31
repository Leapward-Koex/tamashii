import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:simple_torrent/simple_torrent.dart';

/// Injectable boundary around the static simple_torrent facade.
///
/// Keeping the boundary small lets lifecycle behavior be tested without a
/// native plugin while production still uses the endorsed v2 implementation.
abstract interface class TorrentRuntime {
  Stream<TorrentMetadata> get metadataStream;

  Future<(int, Stream<TorrentStats>)> startAndWatch({
    required String magnet,
    required String path,
    String? displayName,
  });

  Future<void> pause(int id);
  Future<void> resume(int id);
  Future<void> cancel(int id);
  Future<void> finalise(int id);
  Future<void> pauseAll();
  Future<void> resumeAll();
}

class SimpleTorrentRuntime implements TorrentRuntime {
  const SimpleTorrentRuntime();

  @override
  Stream<TorrentMetadata> get metadataStream => SimpleTorrent.metadataStream;

  @override
  Future<(int, Stream<TorrentStats>)> startAndWatch({
    required String magnet,
    required String path,
    String? displayName,
  }) => SimpleTorrentHelpers.startAndWatch(
    magnet: magnet,
    path: path,
    displayName: displayName,
  );

  @override
  Future<void> pause(int id) => SimpleTorrent.pause(id);

  @override
  Future<void> resume(int id) => SimpleTorrent.resume(id);

  @override
  Future<void> cancel(int id) => SimpleTorrent.cancel(id);

  @override
  Future<void> finalise(int id) => SimpleTorrent.finalise(id);

  @override
  Future<void> pauseAll() => SimpleTorrentHelpers.pauseAll();

  @override
  Future<void> resumeAll() => SimpleTorrentHelpers.resumeAll();
}

final torrentRuntimeProvider = Provider<TorrentRuntime>(
  (ref) => const SimpleTorrentRuntime(),
);
