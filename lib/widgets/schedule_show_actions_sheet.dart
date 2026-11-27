import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/theme/paper_lantern.dart';

enum ScheduleShowActionType { remove, changeDay, match }

class ScheduleShowAction {
  const ScheduleShowAction._({required this.type, this.releaseDayOfWeek});

  static const ScheduleShowAction remove = ScheduleShowAction._(
    type: ScheduleShowActionType.remove,
  );
  static const ScheduleShowAction match = ScheduleShowAction._(
    type: ScheduleShowActionType.match,
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
  const ScheduleShowActionsSheet({super.key, required this.show, this.title});

  static const Key removeButtonKey = ValueKey<String>(
    'schedule-show-remove-button',
  );
  static const Key changeDayButtonKey = ValueKey<String>(
    'schedule-show-change-day-button',
  );
  static const Key matchButtonKey = ValueKey<String>(
    'schedule-show-match-button',
  );

  static Key dayButtonKey(int weekday) =>
      ValueKey<String>('schedule-show-day-button-$weekday');

  final BookmarkedShowInfo show;
  final String? title;

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
                PaperSectionHeading(title ?? show.showName),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${_weekdayName(show.releaseDayOfWeek)} · ${show.isManualEntry ? 'Manual entry' : 'Watching list'}',
                      style: PaperLantern.folio,
                    ),
                  ),
                ),
                if (show.isManualEntry)
                  ListTile(
                    key: matchButtonKey,
                    leading: const Icon(Icons.link),
                    title: const Text('Edit catalog match'),
                    onTap: () {
                      Navigator.of(context).pop(ScheduleShowAction.match);
                    },
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
                      onTap: isCurrentDay
                          ? null
                          : () {
                              Navigator.of(context)
                                  .pop(ScheduleShowAction.changeDay(weekday));
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
  final monday = DateTime.utc(2024);
  return DateFormat('EEEE').format(monday.add(Duration(days: weekday - 1)));
}
