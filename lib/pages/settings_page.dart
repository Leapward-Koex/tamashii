// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tamashii/providers/settings_provider.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoGen = ref.watch(autoGenerateFoldersProvider);
    final basePath = ref.watch(downloadBasePathProvider);
    final mapping = ref.watch(seriesFolderMappingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
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
                      await ref.read(downloadBasePathProvider.notifier).setBasePath(selected);
                    }
                  },
                ),
            loading: () => const ListTile(title: Text('Download Base Folder'), subtitle: Text('Loading...')),
            error: (e, _) => ListTile(title: const Text('Download Base Folder'), subtitle: Text('Error: $e')),
          ),
          const Divider(),

          // Auto-generate toggle
          autoGen.when(
            data:
                (value) => SwitchListTile(
                  title: const Text('Auto-generate Series Folders'),
                  value: value,
                  onChanged: (bool newVal) async {
                    await ref.read(autoGenerateFoldersProvider.notifier).setAutoGenerate(newVal);
                  },
                ),
            loading: () => const ListTile(title: Text('Auto-generate Series Folders'), subtitle: Text('Loading...')),
            error: (e, _) => ListTile(title: const Text('Auto-generate Series Folders'), subtitle: Text('Error: $e')),
          ),
          const Divider(),

          // Custom folder per series
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Series Folder Overrides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          mapping.when(
            data:
                (map) => Column(
                  children:
                      map.entries.map((entry) {
                        return ListTile(
                          title: Text(entry.key),
                          subtitle: Text(entry.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final selected = await FilePicker.platform.getDirectoryPath();
                              if (selected != null) {
                                await ref.read(seriesFolderMappingProvider.notifier).setFolder(entry.key, selected);
                              }
                            },
                          ),
                        );
                      }).toList(),
                ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
