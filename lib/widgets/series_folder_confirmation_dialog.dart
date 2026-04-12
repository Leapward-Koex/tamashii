import 'package:flutter/material.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';

Future<String?> showSeriesFolderConfirmationDialog({
  required BuildContext context,
  required String showTitle,
  required String basePath,
  required SeriesFolderResolutionPlan plan,
}) async {
  final seriesController = TextEditingController(text: plan.seriesFolderName);
  final seasonController = TextEditingController(
    text: plan.seasonFolderName ?? '',
  );

  String resolvedSeriesName() {
    final trimmed = seriesController.text.trim();
    if (plan.existingSeriesFolders.contains(trimmed)) {
      return trimmed;
    }
    return sanitizeFolderSegment(trimmed);
  }

  String previewPath() {
    final seriesName = resolvedSeriesName();
    final seasonFolder = normalizeUserSeasonFolder(seasonController.text);
    return buildPath(
      basePath: basePath,
      seriesFolderName: seriesName,
      seasonFolderName: seasonFolder,
    );
  }

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Confirm Series Folder'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(showTitle),
                      const SizedBox(height: 12),
                      if (plan.modelUsed != null)
                        Text(
                          'Model: ${plan.modelUsed}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (plan.reason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          plan.reason!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: seriesController,
                        decoration: const InputDecoration(
                          labelText: 'Series Folder Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: seasonController,
                        decoration: const InputDecoration(
                          labelText: 'Season Folder Name',
                          hintText: 'Leave blank to skip the season folder',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Suggested Path',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(previewPath()),
                      const SizedBox(height: 12),
                      Text(
                        'Fallback Path',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(plan.fallbackPath),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed:
                        () =>
                            Navigator.of(dialogContext).pop(plan.fallbackPath),
                    child: const Text('Use Fallback'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final seriesName = resolvedSeriesName();
                      final seasonFolder = normalizeUserSeasonFolder(
                        seasonController.text,
                      );
                      Navigator.of(dialogContext).pop(
                        buildPath(
                          basePath: basePath,
                          seriesFolderName: seriesName,
                          seasonFolderName: seasonFolder,
                        ),
                      );
                    },
                    child: const Text('Use This Folder'),
                  ),
                ],
              ),
        ),
  );

  seriesController.dispose();
  seasonController.dispose();
  return result;
}
