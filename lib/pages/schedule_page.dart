import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/schedule_show_actions_sheet.dart';
import 'package:tamashii/widgets/show_image.dart';

/// A page displaying a weekly schedule for bookmarked series.
class SchedulePage extends HookConsumerWidget {
  const SchedulePage({super.key, this.onAdd, this.today});

  final VoidCallback? onAdd;
  final DateTime? today;

  static Key showTileKey(String showName) =>
      ValueKey<String>('schedule-show-tile-$showName');

  static Key showActionsKey(String showName) =>
      ValueKey<String>('schedule-show-actions-$showName');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedAsync = ref.watch(bookmarkedSeriesProvider);
    final today = this.today ?? DateTime.now();
    final controller = usePageController(initialPage: today.weekday - 1);
    final previousWeekday = useRef(today.weekday);
    useEffect(() {
      if (bookmarkedAsync.hasValue && previousWeekday.value != today.weekday) {
        final old = previousWeekday.value;
        previousWeekday.value = today.weekday;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted &&
              controller.hasClients &&
              controller.page?.round() == old - 1) {
            controller.jumpToPage(today.weekday - 1);
          }
        });
      }
      return null;
    }, [today.weekday, bookmarkedAsync.hasValue]);
    if (bookmarkedAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookmarkedAsync.hasError) {
      return const Center(child: Text('Unable to load your schedule.'));
    }

    final bookmarked = bookmarkedAsync.value ?? <BookmarkedShowInfo>[];

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

    void openInfo(BookmarkedShowInfo show, {bool openMatchPicker = false}) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ShowInfoPage.schedule(show, openMatchPicker: openMatchPicker),
        ),
      );
    }

    Future<void> openActions(BookmarkedShowInfo show) async {
      final action = await showModalBottomSheet<ScheduleShowAction>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ScheduleShowActionsSheet(show: show),
      );

      if (action == null || !context.mounted) {
        return;
      }

      switch (action.type) {
        case ScheduleShowActionType.match:
          openInfo(show, openMatchPicker: true);
          return;
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

    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1 + index,
      ),
    );
    final first = days.first;
    final last = days.last;
    final rangeStart = first.month == last.month
        ? DateFormat.d().format(first)
        : DateFormat('d MMM').format(first);
    final range = '$rangeStart–${DateFormat('d MMMM').format(last)}';

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: PageView.builder(
          controller: controller,
          itemCount: days.length,
          itemBuilder: (context, index) {
            final dayName = _weekdayName(index + 1);
            final shows = schedule[index + 1]!;
            final upcoming = [
              for (var offset = 1; offset < 7; offset++)
                (index + offset) % 7 + 1,
            ].where((day) => schedule[day]!.isNotEmpty).firstOrNull;
            final nextShows = upcoming == null
                ? const <BookmarkedShowInfo>[]
                : schedule[upcoming]!;
            return CustomScrollView(
              key: PageStorageKey('weekly-listing-$index'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          range.toUpperCase(),
                          style: PaperLantern.folio.copyWith(
                            color: PaperLantern.red,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                'Schedule',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                              if (onAdd != null)
                                OutlinedButton.icon(
                                  key: const ValueKey<String>(
                                    'schedule-add-show-fab',
                                  ),
                                  icon: const Icon(Icons.add, size: 17),
                                  label: const Text('Add show'),
                                  onPressed: onAdd,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _WeekStrip(
                          days: days,
                          selected: index,
                          today: today.weekday - 1,
                          select: (day) => controller.animateToPage(
                            day,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PaperSectionHeading(
                          dayName,
                          trailing: Text(
                            _showCount(shows.length),
                            style: PaperLantern.folio,
                          ),
                        ),
                        if (shows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              bookmarked.isEmpty
                                  ? 'No scheduled shows'
                                  : 'No shows scheduled for $dayName',
                            ),
                          ),
                        if (bookmarked.isEmpty)
                          const Text(
                            'Use Add show or mark a series as watching to build your schedule.',
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverList.builder(
                    itemCount: shows.length,
                    itemBuilder: (context, i) => _Listing(
                      show: shows[i],
                      onOpen: () => openInfo(shows[i]),
                      onOptions: () => openActions(shows[i]),
                    ),
                  ),
                ),
                if (upcoming != null) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: PaperSectionHeading(
                        'Next · ${_weekdayName(upcoming)}',
                        trailing: Text(
                          _showCount(nextShows.length),
                          style: PaperLantern.folio,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverList.builder(
                      itemCount: nextShows.length,
                      itemBuilder: (context, i) => _Listing(
                        show: nextShows[i],
                        onOpen: () => openInfo(nextShows[i]),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _showCount(int count) => count == 1 ? '1 show' : '$count shows';

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.today,
    required this.select,
  });
  final List<DateTime> days;
  final int selected;
  final int today;
  final ValueChanged<int> select;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Break the week into two lines when larger text needs the extra space.
        final labelSize = MediaQuery.textScalerOf(context).scale(12);
        final columns = constraints.maxWidth / 7 < labelSize * 2.75 ? 4 : 7;
        return Wrap(
          children: [
            for (final (index, day) in days.indexed)
              SizedBox(
                width: constraints.maxWidth / columns,
                child: Semantics(
                  button: true,
                  selected: index == selected,
                  label:
                      '${DateFormat.yMMMMEEEEd().format(day)}${index == today ? ', today' : ''}',
                  excludeSemantics: true,
                  onTap: () => select(index),
                  child: InkWell(
                    onTap: () => select(index),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == selected
                                ? PaperLantern.red
                                : PaperLantern.rule,
                            width: index == selected ? 3 : 1,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.E().format(day),
                            style: PaperLantern.folio.copyWith(
                              color: index == selected
                                  ? PaperLantern.red
                                  : PaperLantern.muted,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: index == selected
                                  ? PaperLantern.red
                                  : PaperLantern.ink,
                              fontWeight: index == today || index == selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Listing extends StatelessWidget {
  const _Listing({required this.show, required this.onOpen, this.onOptions});
  final BookmarkedShowInfo show;
  final VoidCallback onOpen;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaperLantern.rule)),
      ),
      child: ListTile(
        key: onOptions == null ? null : SchedulePage.showTileKey(show.showName),
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: SizedBox(
          width: 42,
          height: 56,
          child: ColoredBox(
            color: PaperLantern.wash,
            child: show.imageUrl.trim().isEmpty
                ? const Icon(
                    Icons.bookmark_border,
                    color: PaperLantern.muted,
                    size: 20,
                  )
                : ShowImage(imageUrl: show.imageUrl, width: 42, height: 56),
          ),
        ),
        title: Text(
          show.showName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: PaperLantern.serif,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          show.isManualEntry ? 'Manual entry' : 'Watching',
          style: theme.textTheme.bodySmall,
        ),
        trailing: onOptions == null
            ? const Icon(Icons.chevron_right, size: 20)
            : IconButton(
                key: SchedulePage.showActionsKey(show.showName),
                tooltip: 'Schedule options for ${show.showName}',
                icon: const Icon(Icons.more_horiz),
                onPressed: onOptions,
              ),
      ),
    );
  }
}

String _weekdayName(int weekday, {String pattern = 'EEEE'}) {
  final monday = DateTime.utc(2024);
  return DateFormat(pattern).format(monday.add(Duration(days: weekday - 1)));
}
