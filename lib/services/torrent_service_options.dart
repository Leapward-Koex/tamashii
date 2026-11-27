import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:tamashii/services/torrent_foreground_task.dart';

const torrentServiceId = 256;
const torrentServiceTitle = 'Tamashii - Starting Downloads';
const torrentServiceText = 'Initializing torrent downloads...';
const torrentServiceButtons = [
  NotificationButton(id: 'pause_all', text: 'Pause All'),
  NotificationButton(id: 'resume_all', text: 'Resume All'),
];
final torrentNotificationOptions = AndroidNotificationOptions(
  channelId: 'tamashii_torrent_service',
  channelName: 'Tamashii Torrent Service',
  channelDescription: 'Manages torrent downloads in the background',
  onlyAlertOnce: true,
);
final torrentTaskOptions = ForegroundTaskOptions(
  eventAction: ForegroundTaskEventAction.repeat(5000),
  allowWifiLock: true,
);

/// flutter_foreground_task's Android start arguments, persisted while Flutter
/// is available so a launcher tap can start the same callback on a cold app.
Map<String, dynamic> torrentWidgetStartOptions() => {
  ...torrentNotificationOptions.toJson(),
  ...torrentTaskOptions.toJson(),
  'serviceId': torrentServiceId,
  'notificationContentTitle': torrentServiceTitle,
  'notificationContentText': torrentServiceText,
  'buttons': torrentServiceButtons.map((button) => button.toJson()).toList(),
  'callbackHandle': PluginUtilities.getCallbackHandle(startTorrentCallback)!
      .toRawHandle(),
};
