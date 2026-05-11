import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';

enum ScheduleShowActionType { remove, changeDay }

class ScheduleShowAction {
  const ScheduleShowAction._({required this.type, this.releaseDayOfWeek});

  static const ScheduleShowAction remove = ScheduleShowAction._(
    type: ScheduleShowActionType.remove,
  );

  factory ScheduleShowAction.changeDay(int releaseDayOfWeek) {
    return ScheduleShowAction._(
      type: ScheduleShowActionType.changeDay,
      releaseDayOfWeek: releaseDayOfWeek,
    );
  }

  final ScheduleShowActionType type;
  final int? releaseDayOfWeek;
}

class ScheduleShowActionsSheet extends StatelessWidget {
  const ScheduleShowActionsSheet({super.key, required this.show});

  static const Key removeButtonKey = ValueKey<String>(
    'schedule-show-remove-button',
  );
  static const Key changeDayButtonKey = ValueKey<String>(
    'schedule-show-change-day-button',
  );

  static Key dayButtonKey(int weekday) =>
      ValueKey<String>('schedule-show-day-button-$weekday');

  final BookmarkedShowInfo show;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ExpansionTile(
                  key: changeDayButtonKey,
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('Change schedule day'),
                  children: List<Widget>.generate(7, (index) {
                    final weekday = index + 1;
                    final isCurrentDay = weekday == show.releaseDayOfWeek;

                    return ListTile(
                      key: dayButtonKey(weekday),
                      enabled: !isCurrentDay,
                      contentPadding: const EdgeInsets.only(left: 56),
                      title: Text(_weekdayName(weekday)),
                      trailing: isCurrentDay ? const Icon(Icons.check) : null,
                      onTap:
                          isCurrentDay
                              ? null
                              : () {
                                Navigator.of(
                                  context,
                                ).pop(ScheduleShowAction.changeDay(weekday));
                              },
                    );
                  }),
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
        ),
      ),
    );
  }
}

String _weekdayName(int weekday) {
  final monday = DateTime.utc(2024, 1, 1);
  return DateFormat('EEEE').format(monday.add(Duration(days: weekday - 1)));
}
