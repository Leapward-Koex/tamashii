// lib/pages/settings_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/services/transfer_policy.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({this.platform, super.key});

  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoGen = ref.watch(autoGenerateFoldersProvider);
    final basePath = ref.watch(downloadBasePathProvider);
    final mapping = ref.watch(seriesFolderMappingProvider);
    final modelCatalog = ref.watch(onDeviceModelCatalogProvider);
    final autoGenValue = autoGen.asData?.value;
    final isAndroid =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    final allowMeteredDownloads = isAndroid
        ? ref.watch(allowMeteredDownloadsProvider)
        : null;
    final allowMobileData = isAndroid
        ? ref.watch(allowMobileDataProvider)
        : null;
    final transferPolicy = isAndroid
        ? ref.watch(foregroundTransferPolicyStatusProvider)
        : null;

    return ListView(
      children: <Widget>[
        // Base download folder
        basePath.when(
          data: (path) => ListTile(
            title: const Text('Download Base Folder'),
            subtitle: Text(path.isEmpty ? 'Not set' : path),
            trailing: const Icon(Icons.folder_open),
            onTap: () async {
              final selected = await FilePicker.platform.getDirectoryPath();
              if (selected != null) {
                await ref
                    .read(downloadBasePathProvider.notifier)
                    .setBasePath(selected);
              }
            },
          ),
          loading: () => const ListTile(
            title: Text('Download Base Folder'),
            subtitle: Text('Loading...'),
          ),
          error: (e, _) => ListTile(
            title: const Text('Download Base Folder'),
            subtitle: Text('Error: $e'),
          ),
        ),
        const Divider(),

        if (isAndroid) ...[
          allowMobileData!.when(
            data: (allowed) => SwitchListTile(
              key: const ValueKey<String>('allowMobileDataSwitch'),
              title: const Text('Allow downloads over mobile data'),
              subtitle: const Text(
                'When off, cellular transfers wait, including through VPNs. '
                'On metered cellular, both data settings must be on. A VPN '
                'with an unknown underlying network also waits.',
              ),
              value: allowed,
              onChanged: (value) async {
                await ref
                    .read(allowMobileDataProvider.notifier)
                    .setAllowed(value);

                try {
                  await ref
                      .read(foregroundTorrentManagerProvider.notifier)
                      .setAllowMobileData(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'The setting was saved and will be applied when '
                          'downloads restart. Live update failed: $error',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            loading: () => const ListTile(
              title: Text('Allow downloads over mobile data'),
              subtitle: Text('Loading...'),
            ),
            error: (error, _) => ListTile(
              title: const Text('Allow downloads over mobile data'),
              subtitle: Text('Error: $error'),
            ),
          ),
          allowMeteredDownloads!.when(
            data: (allowed) => SwitchListTile(
              key: const ValueKey<String>('allowMeteredDownloadsSwitch'),
              title: const Text('Allow downloads over metered networks'),
              subtitle: const Text(
                'Controls Android\'s network-cost policy separately from the '
                'mobile-data setting. Offline transfers always wait.',
              ),
              value: allowed,
              onChanged: (value) async {
                await ref
                    .read(allowMeteredDownloadsProvider.notifier)
                    .setAllowed(value);

                try {
                  await ref
                      .read(foregroundTorrentManagerProvider.notifier)
                      .setAllowMeteredDownloads(value);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'The setting was saved and will be applied when '
                          'downloads restart. Live update failed: $error',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            loading: () => const ListTile(
              title: Text('Allow downloads over metered networks'),
              subtitle: Text('Loading...'),
            ),
            error: (error, _) => ListTile(
              title: const Text('Allow downloads over metered networks'),
              subtitle: Text('Error: $error'),
            ),
          ),
          ListTile(
            key: const ValueKey<String>('transferPolicyStatus'),
            leading: Icon(
              transferPolicy!.suspended
                  ? Icons.pause_circle_outline
                  : Icons.cloud_done_outlined,
            ),
            title: const Text('Torrent transfer policy'),
            subtitle: Text(transferPolicyStatusText(transferPolicy)),
          ),
          const Divider(),
        ],

        // Auto-generate toggle
        autoGen.when(
          data: (value) => SwitchListTile(
            title: const Text('Auto-generate Series Folders'),
            value: value,
            onChanged: (bool newVal) async {
              await ref
                  .read(autoGenerateFoldersProvider.notifier)
                  .setAutoGenerate(newVal);
            },
          ),
          loading: () => const ListTile(
            title: Text('Auto-generate Series Folders'),
            subtitle: Text('Loading...'),
          ),
          error: (e, _) => ListTile(
            title: const Text('Auto-generate Series Folders'),
            subtitle: Text('Error: $e'),
          ),
        ),
        const Divider(),

        if (autoGenValue == true) ...[
          modelCatalog.when(
            data: (catalog) => ListTile(
              title: const Text('On-device AI'),
              subtitle: Text(
                catalog.availableModels.isEmpty
                    ? 'Unavailable. Folder generation will fall back to plain series names.'
                    : 'Detected model: ${catalog.activeModel ?? catalog.availableModels.first}',
              ),
            ),
            loading: () => const ListTile(
              title: Text('On-device AI'),
              subtitle: Text('Checking model availability...'),
            ),
            error: (error, _) => ListTile(
              title: const Text('On-device AI'),
              subtitle: Text('Error: $error'),
            ),
          ),
          const Divider(),
        ],

        // Custom folder per series
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Series Folder Overrides',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        mapping.when(
          data: (map) => Column(
            children: map.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                subtitle: Text(entry.value),
                onTap: () async {
                  // Open folder in system file explorer
                  try {
                    await OpenFile.open(entry.value);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open folder: $e')),
                      );
                    }
                  }
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Series Folder'),
                            content: Text(
                              'This will delete the folder and all files for "${entry.key}". Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await Directory(entry.value)
                                .delete(recursive: true);
                          } catch (_) {}
                          await ref
                              .read(seriesFolderMappingProvider.notifier)
                              .removeFolder(entry.key);
                          await ref
                              .read(downloadedTorrentsProvider.notifier)
                              .removeByShow(entry.key);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final selected = await FilePicker.platform
                            .getDirectoryPath();
                        if (selected != null) {
                          await ref
                              .read(seriesFolderMappingProvider.notifier)
                              .setFolder(entry.key, selected);
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }
}
