import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/widgets/widget_download_setup.dart';

class _DirectoryPicker extends FilePickerPlatform {
  final requests = <(String?, String?)>[];
  String? selection;
  Completer<String?>? openDialog;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requests.add((dialogTitle, initialDirectory));
    if (openDialog case final dialog?) return dialog.future;
    return selection;
  }
}

class _Downloads extends ForegroundTorrentManager {
  final starts = <(String, String, String)>[];

  @override
  TorrentManagerState build() => const TorrentManagerState();

  @override
  Future<void> startDownload(
    String torrentKey,
    String magnetUri,
    String downloadPath, {
    bool redownload = false,
  }) async {
    starts.add((torrentKey, magnetUri, downloadPath));
  }
}

const _show = BookmarkedShowInfo(
  showName: 'Night Ferry',
  imageUrl: '',
  releaseDayOfWeek: DateTime.friday,
);

const _setupRequest = {
  'title': 'Night Ferry',
  'torrentKey': 'Night Ferry-07',
  'magnet': 'magnet:?xt=selected-episode-07',
};

Future<void> _openWidgetHome(
  WidgetTester tester, {
  required _Downloads downloads,
  required String basePath,
  String? seriesFolder,
}) async {
  final values = <String, Object>{
    'bookmarked_series': [jsonEncode(_show.toJson())],
    'catalog_match.${ShowCatalogTarget.fromSchedule(_show).scopeKey}':
        jsonEncode(
          const TenraiAnimeSearchResult(
            malId: 4,
            title: 'The Night Ferry',
          ).toJson(),
        ),
    'download_base_path': basePath,
    'auto_generate_folders': false,
    if (seriesFolder != null)
      'series_folder_mapping': jsonEncode({_show.showName: seriesFolder}),
  };
  SharedPreferences.setMockInitialValues(values);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
  final container = ProviderContainer.test(
    overrides: [
      latestShowsProvider.overrideWith((ref) async => []),
      searchShowsProvider(_show.showName).overrideWith((ref) async => []),
      foregroundTorrentManagerProvider.overrideWith(() => downloads),
      torrentManagerProvider.overrideWithValue(const TorrentManagerState()),
    ],
  );
  // TamashiiApp mounts the launcher handler after loading its saved catalog.
  await container.read(catalogCacheReadyProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(WidgetDownloadSetup.channel, null),
  );

  testWidgets(
    'a cold widget download opens Settings when the base folder is missing',
    (tester) async {
      final downloads = _Downloads();
      var pending = true;
      messenger.setMockMethodCallHandler(WidgetDownloadSetup.channel, (
        call,
      ) async {
        if (call.method != 'takeDownloadSetup' || !pending) return null;
        pending = false;
        return _setupRequest;
      });
      await _openWidgetHome(tester, downloads: downloads, basePath: '');
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Download Base Folder'), findsOneWidget);
      expect(find.byType(ShowInfoPage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(downloads.starts, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets(
    'a warm widget download selects a series folder and starts the tapped episode',
    (tester) async {
      final previousPicker = FilePickerPlatform.instance;
      final picker = _DirectoryPicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previousPicker);
      final downloads = _Downloads();
      var pending = false;
      const channel = WidgetDownloadSetup.channel;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'takeDownloadSetup' || !pending) return null;
        pending = false;
        return _setupRequest;
      });

      final library = Directory.systemTemp.createTempSync('tamashii-widget-');
      addTearDown(() => library.deleteSync(recursive: true));
      final basePath = library.path;
      final selectedFolder = Directory.fromUri(library.uri.resolve('series/'))
          .path;
      await _openWidgetHome(tester, downloads: downloads, basePath: basePath);
      expect(find.text('Home'), findsOneWidget);
      expect(picker.requests, isEmpty);

      Future<void> tapDownload() async {
        pending = true;
        final response = messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(const MethodCall('setupAvailable')),
          null,
        );
        await tester.pumpAndSettle();
        await response;
      }

      await tapDownload();
      final page = find.byType(ShowInfoPage);
      expect(tester.widget<ShowInfoPage>(page).bookmark, _show);
      expect(find.text('The Night Ferry'), findsOneWidget);
      expect(picker.requests, [
        ('Select download folder for "The Night Ferry"', basePath),
      ]);
      final container = ProviderScope.containerOf(tester.element(page));
      expect(await container.read(seriesFolderMappingProvider.future), isEmpty);
      expect(downloads.starts, isEmpty);

      picker.selection = selectedFolder;
      await tapDownload();
      // Let the filesystem probe finish between Flutter's simulated frames.
      final elapsed = Stopwatch()..start();
      while (downloads.starts.isEmpty &&
          elapsed.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(picker.requests, hasLength(2));
      expect(await container.read(seriesFolderMappingProvider.future), {
        _show.showName: selectedFolder,
      });
      expect(downloads.starts, [
        (_setupRequest['torrentKey'], _setupRequest['magnet'], selectedFolder),
      ]);
      expect(tester.widget<ShowInfoPage>(page).bookmark, _show);
    },
  );

  testWidgets('a series with a folder can cancel permission setup', (
    tester,
  ) async {
    final downloads = _Downloads();
    messenger.setMockMethodCallHandler(WidgetDownloadSetup.channel, (
      call,
    ) async {
      return call.method == 'takeDownloadSetup' ? _setupRequest : null;
    });
    await _openWidgetHome(
      tester,
      downloads: downloads,
      basePath: '/library',
      seriesFolder: '/library/Night Ferry',
    );
    expect(find.text('Set up downloads for The Night Ferry'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(downloads.starts, isEmpty);
  });

  testWidgets('a second widget download waits for the open directory picker', (
    tester,
  ) async {
    final previousPicker = FilePickerPlatform.instance;
    final firstDialog = Completer<String?>();
    final picker = _DirectoryPicker()..openDialog = firstDialog;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previousPicker);
    final downloads = _Downloads();
    const channel = WidgetDownloadSetup.channel;
    Map<String, String>? pending = _setupRequest;
    final consumed = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takeDownloadSetup') return null;
      final next = pending;
      pending = null;
      if (next != null) consumed.add(next['torrentKey']!);
      return next;
    });

    await _openWidgetHome(tester, downloads: downloads, basePath: '/library');
    expect(picker.requests, hasLength(1));
    const secondKey = 'Night Ferry-08';
    pending = {
      'title': _show.showName,
      'torrentKey': secondKey,
      'magnet': 'magnet:?xt=episode-08',
    };
    final notice = messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('setupAvailable')),
      null,
    );
    await tester.pumpAndSettle();
    expect(consumed, [_setupRequest['torrentKey']]);
    expect(picker.requests, hasLength(1));

    final secondDialog = Completer<String?>();
    picker.openDialog = secondDialog;
    firstDialog.complete(null);
    await tester.pumpAndSettle();
    expect(consumed, [_setupRequest['torrentKey'], secondKey]);
    expect(picker.requests, [
      ('Select download folder for "The Night Ferry"', '/library'),
      ('Select download folder for "The Night Ferry"', '/library'),
    ]);
    secondDialog.complete(null);
    await tester.pumpAndSettle();
    await notice;
    expect(downloads.starts, isEmpty);
  });

  testWidgets('a normal launch takes the user directly to Home', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      WidgetDownloadSetup.channel,
      (_) async => null,
    );
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('cold and warm launcher taps open the selected series', (
    tester,
  ) async {
    const first = BookmarkedShowInfo(
      showName: 'Original title',
      imageUrl: '',
      releaseDayOfWeek: DateTime.friday,
    );
    const second = BookmarkedShowInfo(
      showName: 'Manual entry',
      source: BookmarkedShowSource.manual,
      imageUrl: '',
      releaseDayOfWeek: DateTime.sunday,
      malId: 43,
      catalogEntry: TenraiAnimeSearchResult(malId: 43, title: 'Manual title'),
    );
    SharedPreferences.setMockInitialValues({
      'catalog_match.${ShowCatalogTarget.fromSchedule(first).scopeKey}':
          jsonEncode(
            const TenraiAnimeSearchResult(
              malId: 42,
              title: 'Catalog title',
            ).toJson(),
          ),
      'bookmarked_series': [
        for (final show in [first, second]) jsonEncode(show.toJson()),
      ],
    });
    String? pending = first.showName;
    const channel = WidgetDownloadSetup.channel;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takeSeriesTitle') return null;
      final title = pending;
      pending = null;
      return title;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latestShowsProvider.overrideWith((ref) async => []),
          searchShowsProvider(first.showName).overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: WidgetDownloadSetup(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = find.byType(ShowInfoPage);
    expect(tester.widget<ShowInfoPage>(page).bookmark, first);
    expect(find.text('Catalog title'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    Future<void> tapWidgetRow(String title) async {
      pending = title;
      final response = messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('seriesAvailable')),
        null,
      );
      await tester.pumpAndSettle();
      await response;
    }

    await tapWidgetRow(second.showName);
    expect(tester.widget<ShowInfoPage>(page).bookmark, second);
    expect(find.text('Manual title'), findsOneWidget);
    await tapWidgetRow(second.showName);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(page, findsNothing);

    await tapWidgetRow('Removed series');
    expect(
      find.text('This series is no longer on your schedule.'),
      findsOneWidget,
    );
    expect(page, findsNothing);
  });
}
