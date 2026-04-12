import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';

enum ScheduleShowAction { remove }

class ScheduleShowActionsSheet extends StatelessWidget {
  const ScheduleShowActionsSheet({super.key, required this.show});

  static const Key removeButtonKey = ValueKey<String>(
    'schedule-show-remove-button',
  );

  final BookmarkedShowInfo show;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Wrap(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(show.showName, style: theme.textTheme.titleLarge),
              subtitle: Text(
                '${_weekdayName(show.releaseDayOfWeek)} • ${show.isManualEntry ? 'Manual entry' : 'Watching list'}',
              ),
            ),
            ListTile(
              key: removeButtonKey,
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Remove from watching list',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop(ScheduleShowAction.remove);
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayName(int weekday) {
  final monday = DateTime.utc(2024, 1, 1);
  return DateFormat('EEEE').format(monday.add(Duration(days: weekday - 1)));
}
