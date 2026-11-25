// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const _androidIcon = 'ic_download_done';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_androidIcon);

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'Tamashii',
          appUserModelId: 'com.leapwardkoex.tamashii',
          // Search online for GUID generators to make your own
          guid: '949ba289-6ae5-4e94-8f8a-b17a9472997c',
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          windows: initializationSettingsWindows,
        );

    await _notifications.initialize(settings: initializationSettings);
    _initialized = true;
  }

  static Future<void> showDownloadCompletion({
    required String torrentKey,
    required String displayName,
    required int completedCount,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'torrent_completion',
          'Torrent Completions',
          channelDescription: 'Notifications for finished downloads',
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidIcon,
          tag: 'torrent_completion',
        );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    final isBatch = completedCount > 1;
    await _notifications.show(
      id: torrentKey.hashCode,
      title: isBatch ? 'Downloads complete' : 'Download complete',
      body: isBatch ? 'All $completedCount downloads finished.' : displayName,
      notificationDetails: notificationDetails,
    );
  }
}
