import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:simple_torrent/simple_torrent.dart';

import 'package:tamashii/config/torrent_config.dart';
import 'package:tamashii/pages/home_page.dart';
import 'package:tamashii/providers/api_cache_sync_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/services/notification_service.dart';
import 'package:tamashii/services/widget_catalog.dart';
import 'package:tamashii/widgets/widget_download_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android torrents belong to the foreground service's Flutter engine, which
  // initializes its own native manager before accepting download commands.
  if (!Platform.isAndroid) {
    try {
      await SimpleTorrent.init(config: tamashiiTorrentConfig);
      debugPrint('SimpleTorrent initialized successfully');
    } on SimpleTorrentException catch (error) {
      debugPrint(
        'SimpleTorrent initialization failed (${error.code.name}): '
        '${error.message}',
      );
    } catch (error) {
      debugPrint('SimpleTorrent initialization failed: $error');
    }
    // Android posts completion notifications from the download service's
    // engine, which initializes the plugin even when the UI is closed.
    try {
      await NotificationService.initialize();
    } catch (error) {
      debugPrint('Failed to initialize notification service: $error');
    }
  }

  runApp(const ProviderScope(child: TamashiiApp()));
}

class TamashiiApp extends ConsumerWidget {
  const TamashiiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) {
      ref.listen(widgetCatalogProvider, (_, catalog) {
        catalog.whenData((value) => unawaited(publishWidgetCatalog(value)));
      });
    }
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
      home: Platform.isAndroid
          ? const WidgetDownloadSetup(child: HomePage())
          : const HomePage(),
    );
  }
}
