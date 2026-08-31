# Tamashii

Tamashii tracks anime schedules and downloads episodes through the federated
`simple_torrent` 2.0 Flutter plugin.

## Toolchain

The repository is pinned to Flutter 3.47.2 (Dart 3.13.2) through FVM:

```powershell
fvm install
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
fvm flutter test
```

The Android build currently stays on the latest mutually compatible legacy
toolchain (AGP 8.11.1, Gradle 8.14, and Kotlin 2.2.20). Flutter 3.47 reports
these versions as approaching end of support, but `simple_torrent` 2.0 still
applies the external Kotlin Android plugin and therefore cannot yet use AGP 9's
built-in Kotlin mode. Upgrade these together after the pinned plugin commit is
migrated; the current Gradle distribution is checksum-verified.

The supported build targets are Android and Windows. iOS 15 and macOS 12 project
files are retained for source validation, but require the Apple
`simple_torrent` XCFrameworks before they can be built. Linux and web are not
supported by `simple_torrent` 2.0.

`simple_torrent` and its five implementation/interface packages are pinned to
one Git commit in `pubspec.yaml`. Git LFS must be installed before dependency
resolution so the bundled DLL and SO files are materialized:

```powershell
git lfs install
fvm flutter pub get
fvm dart run tool/verify_simple_torrent_artifacts.dart
```

## Safe development builds

Production episode torrents can be several GB. Every local agent or developer
launch/build, including release-mode verification, must use the safe torrent
override:

```powershell
fvm flutter run --dart-define=TAMASHII_USE_TEST_TORRENT=true
fvm flutter build apk --debug --dart-define=TAMASHII_USE_TEST_TORRENT=true
fvm flutter build windows --release --dart-define=TAMASHII_USE_TEST_TORRENT=true
```

The override replaces requested magnets at the torrent-engine boundary with the
small Big Buck Bunny test torrent. Omit it only for an intentional production
test or distribution build. Unit tests do not need the define.

## Mobile data, metered networks, and Android storage

On Android, both **Allow downloads over mobile data** and **Allow downloads over
metered networks** are disabled by default. Mobile transport and metered cost
are evaluated independently: cellular is blocked even when Android reports it
as unmetered, while metered Wi-Fi remains covered by the metered-network
setting.

VPNs do not bypass the mobile-data rule. A VPN backed by cellular is blocked; a
VPN backed by Wi-Fi is allowed subject to the metered setting. When Android
cannot reveal a VPN's underlying transport, Tamashii suspends transfers until a
known non-cellular route appears or the user explicitly allows mobile data.
Offline networks always suspend. Changing either setting applies immediately,
while manual per-torrent pause state remains independent.
During an Android default-route handoff, Tamashii closes the global transfer
gate until fresh capabilities arrive. A detector or native-gate failure also
fails closed; if a stricter live setting cannot be applied, the foreground
engine is stopped without deleting partial files.

The foreground policy can be exercised without GUI automation. The runner
chooses an Android device (preferring x86_64), enables only the safe torrent and
test-only network override, writes logs plus a JSON result under
`build/test-network-policy/`, and returns a nonzero exit code on failure:

```powershell
.\tool\test-network-policy.ps1 -BuildMode debug
.\tool\test-network-policy.ps1 -BuildMode release -DeviceId emulator-5554
```

```bash
bash tool/test-network-policy.sh debug
bash tool/test-network-policy.sh release --device emulator-5554
```

Release mode builds an actual Release APK, then executes the device test in
Profile because a Flutter Release app has no VM service for the integration
driver. Add `-KeepOnFailure` or `--keep-on-failure` to retain the isolated test
directory for diagnostics.

Tamashii supports arbitrary user-selected Android download folders and therefore
requests `MANAGE_EXTERNAL_STORAGE`. This permission is restricted by Google Play
policy: a store release must justify all-files access as a core app capability,
or the storage design must be migrated to the Storage Access Framework before
publication. Notification access is requested separately when the foreground
download service needs it.

## CI and releases

Pull requests and pushes run formatting, generated-source checks, analysis,
tests, native artifact validation, and Android/Windows Debug and Release smoke
builds. All smoke builds use the safe torrent define. The separate Android
publish workflow creates the signed production APK and intentionally omits that
define.
