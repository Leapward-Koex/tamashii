import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests Android's all-files access used by arbitrary download folders.
  ///
  /// iOS and desktop platforms rely on their native file picker/sandbox model
  /// and do not expose Android's storage permission.
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } catch (error) {
      debugPrint('Error requesting all-files access: $error');
      return false;
    }
  }

  /// Checks Android all-files access without prompting.
  static Future<bool> hasStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      return (await Permission.manageExternalStorage.status).isGranted;
    } catch (error) {
      debugPrint('Error checking all-files access: $error');
      return false;
    }
  }

  /// Returns an actionable error when [path] cannot hold a download.
  ///
  /// The probe is removed immediately. A missing selected directory is created
  /// because libtorrent also expects its save root to exist before a start.
  static Future<String?> validateDownloadDirectory(String path) async {
    if (path.trim().isEmpty) {
      return 'Choose a download folder before starting the torrent.';
    }

    final directory = Directory(path);
    File? probe;
    try {
      await directory.create(recursive: true);
      probe = File(
        '${directory.path}${Platform.pathSeparator}'
        '.tamashii-write-test-${DateTime.now().microsecondsSinceEpoch}',
      );
      await probe.writeAsBytes(const <int>[0], flush: true);
      return null;
    } on FileSystemException {
      return 'Tamashii cannot write to "$path". Choose another folder or '
          'grant all-files access in Android Settings.';
    } finally {
      if (probe != null && await probe.exists()) {
        try {
          await probe.delete();
        } on FileSystemException {
          // A failed cleanup does not change whether the directory is writable.
        }
      }
    }
  }

  /// Show permission rationale dialog
  static Future<bool> shouldShowPermissionRationale() async {
    return Platform.isAndroid &&
        await Permission.manageExternalStorage.shouldShowRequestRationale;
  }

  /// Open app settings for manual permission grant
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Request notification permission specifically
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (error) {
      debugPrint('Error requesting notification permission: $error');
      return false;
    }
  }
}
