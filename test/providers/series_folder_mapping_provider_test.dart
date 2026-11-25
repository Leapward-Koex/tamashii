import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/providers/settings_provider.dart';

const _mappingKey = 'series_folder_mapping';

final class _FolderPreferences extends InMemorySharedPreferencesAsync {
  _FolderPreferences() : super.withData({_mappingKey: '{"Existing":"/old"}'});

  final firstReadStarted = Completer<void>();
  final releaseRead = Completer<void>();
  final firstWriteStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  int writes = 0;

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    if (!firstReadStarted.isCompleted) {
      firstReadStarted.complete();
    }
    await releaseRead.future;
    return super.getString(key, options);
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    writes++;
    if (writes == 1) {
      firstWriteStarted.complete();
      await releaseWrite.future;
    }
    return super.setString(key, value, options);
  }
}

Future<Object?> _readStoredFolders() async {
  return jsonDecode((await SharedPreferencesAsync().getString(_mappingKey))!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an unobserved cold folder save waits and preserves stored paths',
    () async {
      final preferences = _FolderPreferences()..releaseWrite.complete();
      SharedPreferencesAsyncPlatform.instance = preferences;
      final container = ProviderContainer.test();

      final save = container
          .read(seriesFolderMappingProvider.notifier)
          .setFolder('New', '/new');
      await preferences.firstReadStarted.future;
      await container.pump();
      expect(preferences.writes, 0);

      preferences.releaseRead.complete();
      await save;
      expect(await _readStoredFolders(), {'Existing': '/old', 'New': '/new'});

      await container.pump();
      expect(
        container.allProviders().map((item) => item.provider),
        isNot(contains(seriesFolderMappingProvider)),
      );
    },
  );

  test('concurrent folder saves and removals persist in order', () async {
    final preferences = _FolderPreferences()..releaseRead.complete();
    SharedPreferencesAsyncPlatform.instance = preferences;
    final container = ProviderContainer.test();
    final saveFirst = container
        .read(seriesFolderMappingProvider.notifier)
        .setFolder('First', '/first');
    await preferences.firstWriteStarted.future;

    final mapping = container.read(seriesFolderMappingProvider.notifier);
    final remove = mapping.removeFolder('Existing');
    final saveSecond = mapping.setFolder('Second', '/second');
    final skip = mapping.removeFolder('Absent');
    await container.pump();
    expect(preferences.writes, 1);

    preferences.releaseWrite.complete();
    await Future.wait([saveFirst, remove, saveSecond, skip]);
    expect(preferences.writes, 3);
    expect(await _readStoredFolders(), {
      'First': '/first',
      'Second': '/second',
    });
  });
}
