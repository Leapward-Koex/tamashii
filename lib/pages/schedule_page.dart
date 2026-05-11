import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/widgets/schedule_show_actions_sheet.dart';
import 'package:tamashii/widgets/show_image.dart';

/// A page displaying a weekly schedule for bookmarked series.
class SchedulePage extends HookConsumerWidget {
  const SchedulePage({super.key});

  static Key showTileKey(String showName) =>
      ValueKey<String>('schedule-show-tile-$showName');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedAsync = ref.watch(bookmarkedSeriesProvider);
    if (bookmarkedAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookmarkedAsync.hasError) {
      return const Center(child: Text('Unable to load your schedule.'));
    }

    final bookmarked = bookmarkedAsync.value ?? <BookmarkedShowInfo>[];

    final initialPage = useMemoized(() => DateTime.now().weekday - 1);
    final controller = usePageController(
      viewportFraction: 0.9,
      initialPage: initialPage,
    );
    final selectedIndex = useState(initialPage);

    if (bookmarked.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No scheduled shows'),
            SizedBox(height: 8),
            Text(
              'Use the add button or bookmark a series to build your schedule.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final schedule = <int, List<BookmarkedShowInfo>>{
      for (var i = 1; i <= 7; i++) i: <BookmarkedShowInfo>[],
    };
    for (final show in bookmarked) {
      final weekday = show.releaseDayOfWeek;
      schedule[weekday]?.add(show);
    }
    for (final shows in schedule.values) {
      shows.sort((a, b) => a.showName.compareTo(b.showName));
    }

    Future<void> openActions(BookmarkedShowInfo show) async {
      final action = await showModalBottomSheet<ScheduleShowAction>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ScheduleShowActionsSheet(show: show),
      );

      if (action == null) {
        return;
      }

      switch (action.type) {
        case ScheduleShowActionType.remove:
          final removed = await ref
              .read(bookmarkedSeriesProvider.notifier)
              .remove(show.showName);

          if (!context.mounted || !removed) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${show.showName}" from watching list.'),
            ),
          );
          return;
        case ScheduleShowActionType.changeDay:
          final releaseDayOfWeek = action.releaseDayOfWeek;
          if (releaseDayOfWeek == null) {
            return;
          }

          final updated = await ref
              .read(bookmarkedSeriesProvider.notifier)
              .updateReleaseDay(show.showName, releaseDayOfWeek);

          if (!context.mounted || !updated) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Moved "${show.showName}" to ${_weekdayName(releaseDayOfWeek)}.',
              ),
            ),
          );
          return;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayIndex = index + 1;
              final isToday = dayIndex == DateTime.now().weekday;
              final isSelected = index == selectedIndex.value;
              final dayName = _weekdayName(dayIndex, pattern: 'E');

              return InkWell(
                onTap: () {
                  selectedIndex.value = index;
                  controller.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(context).primaryColor
                            : (isToday
                                ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1)
                                : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        isToday && !isSelected
                            ? Border.all(color: Theme.of(context).primaryColor)
                            : null,
                  ),
                  child: Text(
                    dayName,
                    style: TextStyle(
                      fontWeight:
                          (isSelected || isToday)
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : (isToday
                                  ? Theme.of(context).primaryColor
                                  : null),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PageView.builder(
            controller: controller,
            onPageChanged: (index) => selectedIndex.value = index,
            itemCount: 7,
            itemBuilder: (context, index) {
              final dayIndex = index + 1;
              final dayName = _weekdayName(dayIndex);
              final dayShows = schedule[dayIndex]!;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          dayShows.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No shows scheduled for $dayName',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: dayShows.length,
                                itemBuilder: (context, i) {
                                  final show = dayShows[i];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: ListTile(
                                      key: showTileKey(show.showName),
                                      onTap: () => openActions(show),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                      title: Text(
                                        show.showName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle:
                                          show.isManualEntry
                                              ? const Text('Manual entry')
                                              : null,
                                      trailing: const Icon(Icons.more_horiz),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: ShowImage(
                                          imageUrl: show.imageUrl,
                                          width: 60,
                                          height: 80,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _weekdayName(int weekday, {String pattern = 'EEEE'}) {
  final monday = DateTime.utc(2024, 1, 1);
  return DateFormat(pattern).format(monday.add(Duration(days: weekday - 1)));
}
