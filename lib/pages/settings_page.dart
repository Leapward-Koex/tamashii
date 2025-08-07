// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:tamashii/providers/settings_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoGen = ref.watch(autoGenerateFoldersProvider);
    final basePath = ref.watch(downloadBasePathProvider);
    final mapping = ref.watch(seriesFolderMappingProvider);

    return ListView(
      children: <Widget>[
        // Base download folder
        basePath.when(
          data:
              (path) => ListTile(
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
          loading:
              () => const ListTile(
                title: Text('Download Base Folder'),
                subtitle: Text('Loading...'),
              ),
          error:
              (e, _) => ListTile(
                title: const Text('Download Base Folder'),
                subtitle: Text('Error: $e'),
              ),
        ),
        const Divider(),

        // Auto-generate toggle
        autoGen.when(
          data:
              (value) => SwitchListTile(
                title: const Text('Auto-generate Series Folders'),
                value: value,
                onChanged: (bool newVal) async {
                  await ref
                      .read(autoGenerateFoldersProvider.notifier)
                      .setAutoGenerate(newVal);
                },
              ),
          loading:
              () => const ListTile(
                title: Text('Auto-generate Series Folders'),
                subtitle: Text('Loading...'),
              ),
          error:
              (e, _) => ListTile(
                title: const Text('Auto-generate Series Folders'),
                subtitle: Text('Error: $e'),
              ),
        ),
        const Divider(),

        // Custom folder per series
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Series Folder Overrides',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        mapping.when(
          data:
              (map) => Column(
                children:
                    map.entries.map((entry) {
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
                                SnackBar(
                                  content: Text('Could not open folder: $e'),
                                ),
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
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: const Text(
                                          'Delete Series Folder',
                                        ),
                                        content: Text(
                                          'This will delete the folder and all files for "${entry.key}". Continue?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true) {
                                  try {
                                    await Directory(
                                      entry.value,
                                    ).delete(recursive: true);
                                  } catch (_) {}
                                  await ref
                                      .read(
                                        seriesFolderMappingProvider.notifier,
                                      )
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
                                final selected =
                                    await FilePicker.platform
                                        .getDirectoryPath();
                                if (selected != null) {
                                  await ref
                                      .read(
                                        seriesFolderMappingProvider.notifier,
                                      )
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
