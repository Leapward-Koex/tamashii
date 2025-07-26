import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:simple_torrent/simple_torrent.dart';

import 'pages/home_page.dart';
import 'providers/api_cache_sync_provider.dart';
import 'providers/foreground_torrent_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize simple_torrent with optimal configuration for anime downloading
  try {
    await SimpleTorrent.init(
      config: const TorrentConfig(
        maxTorrents: 10, // Allow up to 10 concurrent downloads
        maxDownloadRate: 0, // No download limit by default
        maxUploadRate: 1024, // 1 MB/s upload limit to be a good citizen
        enableDHT: true, // Enable DHT for better peer discovery
        userAgent: 'Tamashii/1.0', // Custom user agent
      ),
    );
    debugPrint('✅ SimpleTorrent initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize SimpleTorrent: $e');
    // Continue anyway, as the app might still work
  }

  runApp(const ProviderScope(child: TamashiiApp()));
}

class TamashiiApp extends ConsumerWidget {
  const TamashiiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the cache sync service
    final cacheSync = ref.watch(apiCacheSyncProvider);
    cacheSync.initialize();

    // Initialize the foreground torrent service (lazy initialization)
    ref.read(foregroundTorrentManagerProvider);

    return MaterialApp(title: 'Tamashii', theme: ThemeData(), home: const HomePage());
  }
}
