import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/services/permission_service.dart';

/// The launcher can start a configured download directly. Android's folder
/// picker and runtime permission prompts need a visible activity.
class WidgetDownloadSetup extends ConsumerStatefulWidget {
  const WidgetDownloadSetup({super.key, required this.child});

  final Widget child;
  static const channel = MethodChannel('tamashii/widget_setup');

  @override
  ConsumerState<WidgetDownloadSetup> createState() =>
      _WidgetDownloadSetupState();
}

class _WidgetDownloadSetupState extends ConsumerState<WidgetDownloadSetup> {
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetDownloadSetup.channel.setMethodCallHandler((call) async {
      if (call.method == 'setupAvailable') await _takeSetup();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeSetup());
  }

  @override
  void dispose() {
    WidgetDownloadSetup.channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _takeSetup() async {
    if (_handling || !mounted) return;
    _handling = true;
    try {
      final title = await WidgetDownloadSetup.channel.invokeMethod<String>(
        'takeSetupTitle',
      );
      if (!mounted || title == null) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text('Set up downloads for $title'),
          content: const Text(
            'Allow download notifications and folder access. The widget will then be able to save episodes from your home screen.',
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
      if (proceed != true || !mounted) return;
      if (!await PermissionService.requestStoragePermissions() ||
          !await PermissionService.requestNotificationPermission()) {
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
        return;
      }
      if (!mounted) return;
      final folders = await ref.read(seriesFolderMappingProvider.future);
      final currentPath = folders[title];
      if (currentPath == null ||
          await PermissionService.validateDownloadDirectory(currentPath) !=
              null) {
        final path = await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose a download folder for $title',
        );
        if (!mounted || path == null) return;
        final error = await PermissionService.validateDownloadDirectory(path);
        if (error != null) throw StateError(error);
        if (!mounted) return;
        await ref
            .read(seriesFolderMappingProvider.notifier)
            .setFolder(title, path);
      }
      await WidgetDownloadSetup.channel.invokeMethod<void>('redraw');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title is set up for widget downloads.')),
        );
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
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
