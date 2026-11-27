import 'package:material_ui/material_ui.dart';
import 'package:tamashii/services/series_folder_resolution_service.dart';
import 'package:tamashii/theme/paper_lantern.dart';

Future<String?> showSeriesFolderConfirmationDialog({
  required BuildContext context,
  required String showTitle,
  required String basePath,
  required SeriesFolderResolutionPlan plan,
}) {
  var seriesInput = plan.seriesFolderName;
  var seasonInput = plan.seasonFolderName ?? '';

  String resolvedSeriesName() {
    final trimmed = seriesInput.trim();
    if (plan.existingSeriesFolders.contains(trimmed)) {
      return trimmed;
    }
    return sanitizeFolderSegment(trimmed);
  }

  String previewPath() {
    final seriesName = resolvedSeriesName();
    final seasonFolder = normalizeUserSeasonFolder(seasonInput);
    return buildPath(
      basePath: basePath,
      seriesFolderName: seriesName,
      seasonFolderName: seasonFolder,
    );
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Confirm Series Folder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(showTitle, style: Theme.of(context).textTheme.titleMedium),
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
              TextFormField(
                initialValue: plan.seriesFolderName,
                decoration: const InputDecoration(
                  labelText: 'Series Folder Name',
                ),
                onChanged: (value) => setState(() => seriesInput = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: plan.seasonFolderName,
                decoration: const InputDecoration(
                  labelText: 'Season Folder Name',
                  hintText: 'Leave blank to skip the season folder',
                ),
                onChanged: (value) => setState(() => seasonInput = value),
              ),
              const Divider(height: 28),
              const Text('Suggested Path', style: PaperLantern.folio),
              const SizedBox(height: 4),
              SelectableText(previewPath()),
              const SizedBox(height: 12),
              const Text('Fallback Path', style: PaperLantern.folio),
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
            onPressed: () => Navigator.of(dialogContext).pop(plan.fallbackPath),
            child: const Text('Use Fallback'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(previewPath()),
            child: const Text('Use This Folder'),
          ),
        ],
      ),
    ),
  );
}
