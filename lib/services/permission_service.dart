// lib/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  /// Request storage permissions needed for torrent downloads
  static Future<bool> requestStoragePermissions() async {
    try {
      // For Android 11+ (API 30+), we need different permissions
      if (Platform.isAndroid) {
        return await _requestAndroidStoragePermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSStoragePermissions();
      }

      return true; // For other platforms, assume permissions are granted
    } catch (e) {
      print('❌ Error requesting storage permissions: $e');
      return false;
    }
  }

  static Future<bool> _requestAndroidStoragePermissions() async {
    Map<Permission, PermissionStatus> permissions = {};

    // Get Android SDK version to determine which permissions to request
    if (await _isAndroid11OrHigher()) {
      // Android 11+ (API 30+) - Use scoped storage permissions
      permissions = await [Permission.manageExternalStorage].request();
    } else {
      // Android 10 and below - Use legacy storage permissions
      permissions =
          await [Permission.storage, Permission.notification].request();
    }

    // Check if all permissions are granted
    bool allGranted = permissions.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );

    if (!allGranted) {
      print('🔒 Storage permissions not fully granted:');
      permissions.forEach((permission, status) {
        print('  ${permission.toString()}: ${status.toString()}');
      });
    }

    return allGranted;
  }

  static Future<bool> _requestIOSStoragePermissions() async {
    // iOS handles file access differently - mainly through document picker
    // Request photo library access if needed for downloads to photo library
    final permissions =
        await [Permission.storage, Permission.notification].request();

    return permissions.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );
  }

  static Future<bool> _isAndroid11OrHigher() async {
    // This is a simplified check - in a real app you might want to use
    // device_info_plus to get the exact API level
    try {
      await Permission.manageExternalStorage.status;
      // If the permission exists, we're on Android 11+
      return true;
    } catch (e) {
      // If the permission doesn't exist, we're on Android 10 or below
      return false;
    }
  }

  /// Check current storage permission status
  static Future<bool> hasStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        if (await _isAndroid11OrHigher()) {
          final storage = await Permission.storage.status;
          final manageExternal = await Permission.manageExternalStorage.status;
          return storage.isGranted &&
              (manageExternal.isGranted || manageExternal.isLimited);
        } else {
          final storage = await Permission.storage.status;
          return storage.isGranted;
        }
      } else if (Platform.isIOS) {
        final storage = await Permission.storage.status;
        return storage.isGranted || storage.isLimited;
      }

      return true; // For other platforms
    } catch (e) {
      print('❌ Error checking storage permissions: $e');
      return false;
    }
  }

  /// Show permission rationale dialog
  static Future<bool> shouldShowPermissionRationale() async {
    if (Platform.isAndroid) {
      return await Permission.storage.shouldShowRequestRationale ||
          await Permission.manageExternalStorage.shouldShowRequestRationale;
    }
    return false;
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
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
      return false;
    }
  }
}
