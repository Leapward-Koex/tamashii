import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:simple_torrent/simple_torrent.dart';

import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/providers/api_cache_sync_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/services/notification_service.dart';
import 'package:tamashii/services/permission_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize simple_torrent with optimal configuration for anime downloading
  try {
    await SimpleTorrent.init(
      config: const TorrentConfig(
        maxTorrents: 30, // Allow up to 30 concurrent downloads
        maxUploadRate: 1024, // 1 MB/s upload limit to be a good citizen
        userAgent: 'Tamashii/1.0', // Custom user agent
      ),
    );
    debugPrint('✅ SimpleTorrent initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize SimpleTorrent: $e');
    // Continue anyway, as the app might still work
  }

  // Initialize notification service for torrent completion notifications
  try {
    await NotificationService.initialize();
    debugPrint('✅ Notification service initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize notification service: $e');
  }

  // Request notification permission on app start
  try {
    final notificationGranted =
        await PermissionService.requestNotificationPermission();
    debugPrint(
      '📱 Notification permission: ${notificationGranted ? 'granted' : 'denied'}',
    );
  } catch (e) {
    debugPrint('❌ Failed to request notification permission: $e');
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

    return MaterialApp(
      title: 'Tamashii',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4D7CFE),
          surface: const Color(0xFFF5F5F2),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F2),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}
