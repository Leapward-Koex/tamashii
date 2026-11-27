import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/release_download_button.dart';
import 'package:tamashii/widgets/schedule_show_actions_sheet.dart';
import 'package:tamashii/widgets/show_image.dart';

/// A page displaying a weekly schedule for bookmarked series.
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, this.onAdd, this.today});

  final VoidCallback? onAdd;
  final DateTime? today;

  static Key showTileKey(String showName) =>
      ValueKey<String>('schedule-show-tile-$showName');

  static Key showActionsKey(String showName) =>
      ValueKey<String>('schedule-show-actions-$showName');

  static Key weekdayKey(int weekday) => ValueKey('schedule-weekday-$weekday');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _ScheduleContent(
      today: today ?? DateTime.now(),
      onAdd: onAdd,
      expanded:
          PaperLantern.supportsTwoPanes(context, constraints.maxWidth) &&
          constraints.maxHeight >= 300,
    ),
  );
}

class _ScheduleContent extends HookConsumerWidget {
  const _ScheduleContent({
    required this.today,
    required this.onAdd,
    required this.expanded,
  });

  final DateTime today;
  final VoidCallback? onAdd;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedAsync = ref.watch(bookmarkedSeriesProvider);
    final controller = usePageController(initialPage: today.weekday - 1);
    final selected = useState(today.weekday - 1);
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
    final latestByShow = <String, ShowInfo>{};
    if (expanded && bookmarked.any((show) => show.showsOnHomePage)) {
      for (final release in [
        ...?ref.watch(cachedEpisodesProvider).value,
        ...?ref.watch(latestShowsProvider).value,
      ]) {
        final previous = latestByShow[release.show];
        if (previous == null ||
            !release.releaseDate.isBefore(previous.releaseDate)) {
          latestByShow[release.show] = release;
        }
      }
    }
    final entries = {
      for (final show in bookmarked)
        show.showName: ref
            .watch(
              cachedShowCatalogMatchProvider(
                ShowCatalogTarget.fromSchedule(show),
              ),
            )
            ?.entry,
    };
    String titleOf(BookmarkedShowInfo show) =>
        entries[show.showName]?.displayTitle ?? show.showName;

    final schedule = <int, List<BookmarkedShowInfo>>{
      for (var i = 1; i <= 7; i++) i: <BookmarkedShowInfo>[],
    };
    for (final show in bookmarked) {
      final weekday = show.releaseDayOfWeek;
      schedule[weekday]?.add(show);
    }
    for (final shows in schedule.values) {
      shows.sort((a, b) => titleOf(a).compareTo(titleOf(b)));
    }

    void openInfo(BookmarkedShowInfo show, {bool openMatchPicker = false}) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ShowInfoPage.schedule(
            show,
            latestRelease: show.showsOnHomePage
                ? latestByShow[show.showName]
                : null,
            openMatchPicker: openMatchPicker,
          ),
        ),
      );
    }

    Future<void> openActions(BookmarkedShowInfo show) async {
      final action = await showModalBottomSheet<ScheduleShowAction>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            ScheduleShowActionsSheet(show: show, title: titleOf(show)),
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
              content: Text('Removed "${titleOf(show)}" from watching list.'),
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
                'Moved "${titleOf(show)}" to ${_weekdayName(releaseDayOfWeek)}.',
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

    void selectDay(int index) => controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    final nextDay = Iterable.generate(
      7,
      (offset) => (today.weekday + offset) % 7 + 1,
    ).where((day) => schedule[day]!.isNotEmpty).firstOrNull;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScheduleHeading(range: range, onAdd: onAdd),
        if (nextDay != null)
          TextButton(
            onPressed: () => selectDay(nextDay - 1),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Up next · ${_weekdayName(nextDay)}'),
                      Text(
                        _showCount(schedule[nextDay]!.length),
                        style: PaperLantern.folio,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
      ],
    );

    final dayPages = PageView.builder(
      controller: controller,
      onPageChanged: (index) => selected.value = index,
      itemCount: days.length,
      itemBuilder: (context, index) {
        final dayName = _weekdayName(index + 1);
        final shows = schedule[index + 1]!;
        return CustomScrollView(
          key: PageStorageKey('weekly-listing-$index'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  title: titleOf(shows[i]),
                  poster: entries[shows[i].showName]?.posterUrl,
                  expanded: expanded,
                  latest: shows[i].showsOnHomePage
                      ? latestByShow[shows[i].showName]
                      : null,
                  onOpen: () => openInfo(shows[i]),
                  onOptions: () => openActions(shows[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: expanded ? 1160 : 760),
        child: Column(
          children: [
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: heading,
              ),
              const Divider(),
            ],
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expanded) ...[
                    Flexible(
                      flex: 3,
                      fit: FlexFit.tight,
                      child: _WeekdayRail(
                        days: days,
                        today: today.weekday - 1,
                        selected: selected.value,
                        select: selectDay,
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: PaperLantern.rule,
                    ),
                  ],
                  Expanded(
                    key: const ValueKey('schedule-day-pages'),
                    flex: 7,
                    child: NestedScrollView(
                      headerSliverBuilder: (context, _) => [
                        if (!expanded)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  heading,
                                  const SizedBox(height: 12),
                                  _WeekStrip(
                                    days: days,
                                    selected: selected.value,
                                    today: today.weekday - 1,
                                    select: selectDay,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      body: dayPages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _showCount(int count) => count == 1 ? '1 show' : '$count shows';

class _ScheduleHeading extends StatelessWidget {
  const _ScheduleHeading({required this.range, required this.onAdd});
  final String range;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        range.toUpperCase(),
        style: PaperLantern.folio.copyWith(color: PaperLantern.red),
      ),
      SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Schedule', style: Theme.of(context).textTheme.headlineLarge),
            if (onAdd != null)
              OutlinedButton.icon(
                key: const ValueKey<String>('schedule-add-show-fab'),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add show'),
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    ],
  );
}

class _WeekdayRail extends HookWidget {
  const _WeekdayRail({
    required this.days,
    required this.today,
    required this.selected,
    required this.select,
  });
  final List<DateTime> days;
  final int today;
  final int selected;
  final ValueChanged<int> select;

  @override
  Widget build(BuildContext context) {
    final dayKeys = useMemoized(() => List.generate(7, (_) => GlobalKey()));
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dayKeys[selected].currentContext?.findRenderObject()?.showOnScreen();
      });
      return null;
    }, [selected, MediaQuery.sizeOf(context)]);
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final (index, day) in days.indexed)
            Semantics(
              key: SchedulePage.weekdayKey(day.weekday),
              button: true,
              selected: selected == index,
              label:
                  '${DateFormat.yMMMMEEEEd().format(day)}${index == today ? ', today' : ''}',
              onTap: () => select(index),
              excludeSemantics: true,
              child: Material(
                key: dayKeys[index],
                color: index == selected
                    ? PaperLantern.wash
                    : PaperLantern.paper,
                child: InkWell(
                  onTap: () => select(index),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: index == selected
                              ? PaperLantern.red
                              : Colors.transparent,
                          width: 3,
                        ),
                        bottom: const BorderSide(color: PaperLantern.rule),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat.EEEE().format(day),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: index == selected
                                      ? PaperLantern.red
                                      : PaperLantern.ink,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          index == today ? 'Today' : DateFormat.d().format(day),
                          style: PaperLantern.folio.copyWith(
                            color: index == today
                                ? PaperLantern.red
                                : PaperLantern.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
                  key: SchedulePage.weekdayKey(day.weekday),
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
  const _Listing({
    required this.show,
    required this.title,
    this.poster,
    required this.expanded,
    this.latest,
    required this.onOpen,
    required this.onOptions,
  });
  final BookmarkedShowInfo show;
  final String title;
  final String? poster;
  final bool expanded;
  final ShowInfo? latest;
  final VoidCallback onOpen;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = expanded ? 112.0 : 42.0;
    final height = expanded ? 108.0 : 56.0;
    final cover = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: PaperLantern.wash,
        child: poster == null && show.imageUrl.trim().isEmpty
            ? const Icon(
                Icons.bookmark_border,
                color: PaperLantern.muted,
                size: 20,
              )
            : ShowImage(
                imageUrl: poster ?? show.imageUrl,
                fallbackImageUrl: poster == null ? null : show.imageUrl,
                width: width,
                height: height,
              ),
      ),
    );
    final options = IconButton(
      key: SchedulePage.showActionsKey(show.showName),
      tooltip: 'Schedule options for $title',
      icon: const Icon(Icons.more_horiz),
      onPressed: onOptions,
    );
    final key = SchedulePage.showTileKey(show.showName);
    final status = show.isManualEntry ? 'Manual entry' : 'Watching';
    final release = latest;
    final metadata = release == null
        ? status
        : 'Latest · ${formatEpisodeLabel(release.episode)}';
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaperLantern.rule)),
      ),
      child: expanded
          ? InkWell(
              key: key,
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    cover,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(metadata, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (release != null && release.bestDownload != null)
                          ReleaseDownloadButton(
                            show: release,
                            displayTitle: title,
                          ),
                        options,
                      ],
                    ),
                  ],
                ),
              ),
            )
          : ListTile(
              key: key,
              onTap: onOpen,
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: cover,
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: PaperLantern.serif,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(status, style: theme.textTheme.bodySmall),
              trailing: options,
            ),
    );
  }
}

String _weekdayName(int weekday, {String pattern = 'EEEE'}) {
  final monday = DateTime.utc(2024);
  return DateFormat(pattern).format(monday.add(Duration(days: weekday - 1)));
}
