import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android posts individual and batch alerts on a separate tag', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    await NotificationService.showDownloadCompletion(
      torrentKey: 'Episode 1',
      displayName: 'Show - Episode 1',
      completedCount: 1,
    );
    await NotificationService.showDownloadCompletion(
      torrentKey: 'Episode 2',
      displayName: 'Show - Episode 2',
      completedCount: 2,
    );

    expect(calls.map((call) => call.method), ['initialize', 'show', 'show']);
    expect(calls[1].arguments['id'], 'Episode 1'.hashCode);
    expect(calls[1].arguments['title'], 'Download complete');
    expect(calls[1].arguments['body'], 'Show - Episode 1');
    expect(calls[2].arguments['id'], 'Episode 2'.hashCode);
    expect(calls[2].arguments['title'], 'Downloads complete');
    expect(calls[2].arguments['body'], 'All 2 downloads finished.');
    expect(
      calls[2].arguments['platformSpecifics']['tag'],
      'torrent_completion',
    );
    expect(calls[2].arguments['platformSpecifics']['icon'], 'ic_download_done');
  });
}
