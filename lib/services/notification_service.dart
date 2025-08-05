// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

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

    await _notifications.initialize(initializationSettings);
    _initialized = true;
  }

  static Future<void> showTorrentCompletionNotification({
    required String torrentName,
    required String message,
  }) async {
    await initialize();

    // Use a unique ID based on the torrent name
    final int notificationId = torrentName.hashCode;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'torrent_completion',
          'Torrent Completions',
          channelDescription:
              'Notifications when individual torrents complete downloading',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
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

    await _notifications.show(
      notificationId,
      'Download Complete',
      message,
      notificationDetails,
    );
  }
}
