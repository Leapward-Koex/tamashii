import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/permission_service.dart';

void main() {
  test('rejects an empty download directory', () async {
    final result = await PermissionService.validateDownloadDirectory('  ');

    expect(result, contains('Choose a download folder'));
  });

  test('creates and validates a writable download directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'tamashii-permission-test-',
    );
    final downloadDirectory = Directory(
      '${root.path}${Platform.pathSeparator}downloads',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final result = await PermissionService.validateDownloadDirectory(
      downloadDirectory.path,
    );

    expect(result, isNull);
    expect(await downloadDirectory.exists(), isTrue);
    expect(
      await downloadDirectory
          .list()
          .where((entry) => entry.path.contains('.tamashii-write-test-'))
          .isEmpty,
      isTrue,
    );
  });
}
