import 'dart:convert';
import 'dart:io';

const _androidAbis = <String>['arm64-v8a', 'armeabi-v7a', 'x86_64'];

void main() {
  final configFile = File('.dart_tool/package_config.json').absolute;
  if (!configFile.existsSync()) {
    stderr.writeln('Run `flutter pub get` before verifying native artifacts.');
    exitCode = 1;
    return;
  }

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  final packages = <String, Directory>{};
  for (final rawPackage in config['packages']! as List<Object?>) {
    final package = rawPackage! as Map<String, Object?>;
    final name = package['name']! as String;
    final rootUri = Uri.parse(package['rootUri']! as String);
    packages[name] = Directory.fromUri(configFile.uri.resolveUri(rootUri));
  }

  const requiredPackages = <String>{
    'simple_torrent',
    'simple_torrent_android',
    'simple_torrent_ios',
    'simple_torrent_macos',
    'simple_torrent_platform_interface',
    'simple_torrent_windows',
  };
  final missingPackages = requiredPackages.difference(packages.keys.toSet());
  if (missingPackages.isNotEmpty) {
    throw StateError(
      'Missing federated simple_torrent packages: '
      '${missingPackages.toList()..sort()}',
    );
  }

  final androidRoot = packages['simple_torrent_android']!;
  for (final abi in _androidAbis) {
    _verifyBinary(
      File.fromUri(
        androidRoot.uri.resolve(
          'android/src/main/jniLibs/$abi/libsimple_torrent_native.so',
        ),
      ),
      const <int>[0x7f, 0x45, 0x4c, 0x46],
      'ELF',
    );
  }

  final windowsRoot = packages['simple_torrent_windows']!;
  _verifyBinary(
    File.fromUri(
      windowsRoot.uri.resolve('windows/lib/x64/simple_torrent_native.dll'),
    ),
    const <int>[0x4d, 0x5a],
    'PE',
  );
  _verifyBinary(
    File.fromUri(
      windowsRoot.uri.resolve('windows/lib/x64/simple_torrent_native.lib'),
    ),
    ascii.encode('!<arch>\n'),
    'COFF archive',
  );
}

void _verifyBinary(File file, List<int> magic, String format) {
  if (!file.existsSync()) {
    throw StateError('Missing native artifact: ${file.path}');
  }

  final length = file.lengthSync();
  final reader = file.openSync();
  late final List<int> prefix;
  try {
    prefix = reader.readSync(128);
  } finally {
    reader.closeSync();
  }

  if (utf8
      .decode(prefix, allowMalformed: true)
      .startsWith('version https://git-lfs.github.com/spec/v1')) {
    throw StateError(
      '${file.path} is a Git LFS pointer. Run `git lfs install` before '
      'resolving dependencies.',
    );
  }
  if (prefix.length < magic.length || !_startsWith(prefix, magic)) {
    throw StateError('${file.path} is not a valid $format binary.');
  }

  stdout.writeln('${file.path}: $format, $length bytes');
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}
