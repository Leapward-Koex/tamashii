import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show ProviderListenable;
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/services/permission_service.dart';
import 'package:tamashii/widgets/release_download_button.dart';

/// Handles launcher widget taps that open a series or require download setup.
class WidgetDownloadSetup extends ConsumerStatefulWidget {
  const WidgetDownloadSetup({super.key, required this.child});

  final Widget child;
  static const channel = MethodChannel('tamashii/widget_setup');

  @override
  ConsumerState<WidgetDownloadSetup> createState() =>
      _WidgetDownloadSetupState();
}

class _WidgetDownloadSetupState extends ConsumerState<WidgetDownloadSetup> {
  bool _handlingSetup = false;
  bool _setupPending = false;
  MaterialPageRoute<void>? _widgetRoute;
  int _launchRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetDownloadSetup.channel.setMethodCallHandler((call) async {
      if (call.method == 'setupAvailable') unawaited(_takeSetup());
      if (call.method == 'seriesAvailable') await _takeSeries();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeSetup();
      _takeSeries();
    });
  }

  @override
  void dispose() {
    WidgetDownloadSetup.channel.setMethodCallHandler(null);
    super.dispose();
  }

  // Home may not yet be listening to auto-disposed settings on a cold launch.
  Future<T> _read<T>(ProviderListenable<Future<T>> provider) {
    final subscription = ref.listenManual(provider, (_, _) {});
    return subscription.read().whenComplete(subscription.close);
  }

  Future<void> _takeSeries() async {
    if (!mounted) return;
    try {
      final title = await WidgetDownloadSetup.channel.invokeMethod<String>(
        'takeSeriesTitle',
      );
      if (mounted && title != null) await _openSeries(title, ++_launchRequest);
    } on MissingPluginException {
      // The widget bridge is only installed in an Android activity.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the series: $error')),
        );
      }
    }
  }

  Future<void> _openSeries(
    String title,
    int request, {
    ({String key, String magnet})? initialDownload,
  }) async {
    final watching = await _read(bookmarkedSeriesProvider.future);
    if (!mounted || request != _launchRequest) return;
    final show = watching.where((item) => item.showName == title).firstOrNull;
    if (show == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This series is no longer on your schedule.'),
        ),
      );
      return;
    }
    final setupDone = initialDownload == null ? null : Completer<void>();
    final closed = _openWidgetPage(
      ShowInfoPage.schedule(
        show,
        onSelectDownloadFolder: initialDownload == null
            ? null
            : (context, pageRef, target) => setUpWidgetDownload(
                context,
                pageRef,
                target: target,
                torrentKey: initialDownload.key,
                magnet: initialDownload.magnet,
              ).whenComplete(setupDone!.complete),
      ),
      RouteSettings(name: '/widget/series', arguments: title),
      reopen: initialDownload != null,
    );
    // A later Download tap can be consumed once the picker finishes or the
    // user leaves this page. Two pickers must not compete for the same route.
    if (setupDone != null) await Future.any([closed, setupDone.future]);
  }

  Future<void> _openWidgetPage(
    Widget page,
    RouteSettings settings, {
    bool reopen = false,
  }) {
    final previous = _widgetRoute;
    final replace =
        previous?.isCurrent == true && previous?.settings.name == settings.name;
    if (replace &&
        previous!.settings.arguments == settings.arguments &&
        !reopen) {
      return previous.popped;
    }
    final route = MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
    final navigator = Navigator.of(context);
    _widgetRoute = route;
    final closed = replace
        ? navigator.pushReplacement<void, void>(route)
        : navigator.push<void>(route);
    return closed.then((_) {
      if (identical(_widgetRoute, route)) _widgetRoute = null;
    });
  }

  Future<void> _takeSetup() async {
    if (!mounted) return;
    if (_handlingSetup) {
      _setupPending = true;
      return;
    }
    _handlingSetup = true;
    try {
      final setup = await WidgetDownloadSetup.channel
          .invokeMapMethod<String, String>('takeDownloadSetup');
      if (!mounted || setup == null) return;
      final request = ++_launchRequest;
      final title = setup['title']!;
      final download = (key: setup['torrentKey']!, magnet: setup['magnet']!);
      final folders = await _read(seriesFolderMappingProvider.future);
      if (!mounted || request != _launchRequest) return;
      final path = folders[title];
      if (path != null && path.trim().isNotEmpty) {
        if (!await _requestMappedFolderPermissions(title) ||
            !mounted ||
            request != _launchRequest) {
          return;
        }
        final error = await PermissionService.validateDownloadDirectory(path);
        if (!mounted || request != _launchRequest) return;
        if (error == null) {
          await ref
              .read(foregroundTorrentManagerProvider.notifier)
              .startDownload(download.key, download.magnet, path);
          await WidgetDownloadSetup.channel.invokeMethod<void>('redraw');
          return;
        }
      }
      final basePath = await _read(downloadBasePathProvider.future);
      if (!mounted || request != _launchRequest) return;
      if (basePath.trim().isEmpty) {
        _openWidgetPage(
          Scaffold(
            appBar: AppBar(title: const Text('Choose a base folder')),
            body: const SafeArea(top: false, child: SettingsPage()),
          ),
          const RouteSettings(name: '/widget/settings'),
        );
      } else {
        await _openSeries(title, request, initialDownload: download);
      }
    } on MissingPluginException {
      // The widget bridge is only installed in an Android activity.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up widget downloads: $error')),
        );
      }
    } finally {
      _handlingSetup = false;
      if (_setupPending && mounted) {
        _setupPending = false;
        await _takeSetup();
      }
    }
  }

  Future<bool> _requestMappedFolderPermissions(String title) async {
    final displayTitle =
        ref
            .read(
              cachedShowCatalogMatchProvider(ShowCatalogTarget(title: title)),
            )
            ?.entry
            ?.displayTitle ??
        title;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Set up downloads for $displayTitle'),
        content: const Text(
          'Allow download notifications and folder access to download this episode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return false;
    if (await PermissionService.requestStoragePermissions() &&
        await PermissionService.requestNotificationPermission()) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grant folder access and notifications to download from the widget.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: PermissionService.openSettings,
          ),
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
