import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/download_queue_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/add_schedule_show_sheet.dart';
import 'package:tamashii/widgets/release_reader_index.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';
import 'package:tamashii/widgets/transfer_policy_banner.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const scrollViewKey = PageStorageKey<String>('home-scroll-view');
  static const Key searchBarShellKey = ValueKey<String>(
    'home-search-bar-shell',
  );
  static const Key scheduleAddFabKey = ValueKey<String>(
    'schedule-add-show-fab',
  );
  static const Key downloadsButtonKey = ValueKey<String>(
    'home-downloads-button',
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final usableWidth =
          constraints.maxWidth - MediaQuery.paddingOf(context).horizontal;
      return _HomeContent(
        wide: PaperLantern.supportsTwoPanes(
          context,
          math.min(1200, usableWidth),
        ),
      );
    },
  );
}

class _HomeContent extends HookConsumerWidget {
  const _HomeContent({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = useState(DateUtils.dateOnly(DateTime.now()));
    useEffect(() {
      final date = today.value;
      final midnight = DateTime(date.year, date.month, date.day + 1);
      final timer = Timer(
        midnight.difference(DateTime.now()),
        () => today.value = DateUtils.dateOnly(DateTime.now()),
      );
      return timer.cancel;
    }, [today.value]);
    final searchController = useTextEditingController();
    final searching = useState(false);
    final debouncedQuery = useState('');
    useEffect(() {
      Timer? debounce;
      void updateSearch() {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 500), () {
          debouncedQuery.value = searchController.text;
        });
      }

      searchController.addListener(updateSearch);
      return () {
        debounce?.cancel();
        searchController.removeListener(updateSearch);
      };
    }, [searchController]);

    final selected = useState(0);
    final visited = useRef(<int>{0});
    final filter = ref.watch(showFilterProvider).value ?? ShowFilter.all;
    final releases = ref.watch(filteredShowsProvider(debouncedQuery.value));
    final shows = releases.value ?? const <ShowInfo>[];
    final selectedRelease = useState<ShowInfo?>(null);
    final compactFeedAnchor = useRef<String?>(null);
    final selection = selectedRelease.value;
    final anchor = selection == null
        ? null
        : shows
              .where((show) => show.torrentKey == selection.torrentKey)
              .firstOrNull;
    final indexRelease = anchor ?? shows.firstOrNull;
    final detail = wide ? indexRelease : anchor ?? selection;
    final compactDetail = !wide && detail != null && selected.value == 0;

    // Display the first available result in the expanded reader. Remember it
    // so folding the device continues on the same series, even on first open.
    useEffect(() {
      if (wide &&
          selected.value == 0 &&
          anchor == null &&
          !releases.isLoading &&
          !releases.hasError &&
          (selection != null || indexRelease != null)) {
        var active = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (active && identical(selectedRelease.value, selection)) {
            compactFeedAnchor.value = null;
            selectedRelease.value = indexRelease;
          }
        });
        return () => active = false;
      }
      return null;
    }, [wide, selected.value, releases, selection]);

    void openRelease(ShowInfo show) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (wide && show.torrentKey != anchor?.torrentKey) {
        compactFeedAnchor.value = show.torrentKey;
      }
      selectedRelease.value = show;
    }

    void backToFeed() => selectedRelease.value = null;

    final policy = defaultTargetPlatform == TargetPlatform.android
        ? ref.watch(foregroundTransferPolicyStatusProvider)
        : null;
    final activeDownloads = ref.watch(activeDownloadCountProvider);
    final refreshKey = useMemoized(GlobalKey<RefreshIndicatorState>.new);
    Future<void> refresh() async {
      final query = debouncedQuery.value;
      final request = query.isEmpty
          ? ref.refresh(latestShowsProvider.future)
          : ref.refresh(searchShowsProvider(query).future);
      // The feed observes this provider and renders any request error itself.
      await request.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    }

    void select(int index) {
      FocusManager.instance.primaryFocus?.unfocus();
      visited.value.add(index);
      selected.value = index;
    }

    Future<void> addToSchedule() async {
      final name = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const AddScheduleShowSheet(),
      );
      if (!context.mounted || name == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "$name" to your watching list.')),
      );
    }

    final pages = [
      Column(
        children: [
          if (searching.value && !compactDetail)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                key: HomePage.searchBarShellKey,
                autofocus: true,
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search for shows...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Close search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      searchController.clear();
                      debouncedQuery.value = '';
                      searching.value = false;
                    },
                  ),
                ),
              ),
            ),
          if (filter == ShowFilter.saved && !compactDetail)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(showFilterProvider.notifier)
                      .setFilter(ShowFilter.all),
                  icon: const Icon(Icons.bookmark_remove_outlined, size: 16),
                  label: const Text('Watching only · Clear'),
                ),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compactDetail)
                  Expanded(
                    flex: 4,
                    child: wide && indexRelease != null
                        ? RefreshIndicator(
                            key: refreshKey,
                            onRefresh: refresh,
                            child: ReleaseReaderIndex(
                              key: ValueKey((debouncedQuery.value, filter)),
                              releases: shows,
                              selectedRelease: indexRelease,
                              onSelected: openRelease,
                            ),
                          )
                        : _ReleaseFeed(
                            key: PageStorageKey(compactFeedAnchor.value),
                            anchorKey: compactFeedAnchor.value,
                            releases: releases,
                            filter: filter,
                            refreshKey: refreshKey,
                            onRefresh: refresh,
                            onOpen: openRelease,
                          ),
                  ),
                if (wide && detail != null)
                  const VerticalDivider(width: 1, color: PaperLantern.rule),
                if (detail != null && (wide || compactDetail))
                  Expanded(
                    key: const ValueKey('release-detail-pane'),
                    flex: 6,
                    child: StaggeredReveal(
                      key: ValueKey((detail.show, detail.page)),
                      index: 0,
                      duration: const Duration(milliseconds: 260),
                      offset: const Offset(0, 0.035),
                      child: wide
                          ? ShowInfoPage.reader(detail)
                          : ShowInfoPage.series(detail, onBack: backToFeed),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      SchedulePage(today: today.value, onAdd: addToSchedule),
      const SettingsPage(),
    ];

    final content = Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                if (!compactDetail) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 8, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Semantics(
                                header: true,
                                label: 'Tamashii',
                                excludeSemantics: true,
                                child: Text.rich(
                                  const TextSpan(
                                    text: 'Tamashii',
                                    children: [
                                      TextSpan(
                                        text: '.',
                                        style: TextStyle(
                                          color: PaperLantern.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontFamily: PaperLantern.serif,
                                        color: PaperLantern.ink,
                                        fontSize: 38,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -2.2,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Search shows',
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            select(0);
                            searching.value = true;
                          },
                        ),
                        IconButton(
                          key: HomePage.downloadsButtonKey,
                          tooltip: 'Downloads',
                          icon: Badge(
                            isLabelVisible: activeDownloads > 0,
                            label: Text('$activeDownloads'),
                            child: const Icon(Icons.download_outlined),
                          ),
                          onPressed: () {
                            final known = {
                              for (final release in [
                                ...?ref.read(cachedEpisodesProvider).value,
                                if (ref.read(latestShowsProvider.exists))
                                  ...?ref.read(latestShowsProvider).value,
                                ...?releases.value,
                              ])
                                release.torrentKey: release,
                            };
                            Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DownloadQueuePage(releasesByKey: known),
                              ),
                            );
                          },
                        ),
                        if (selected.value == 0)
                          MenuAnchor(
                            animated: true,
                            builder: (context, menu, _) => IconButton(
                              tooltip: 'Release options',
                              icon: const Icon(Icons.more_vert),
                              onPressed: () =>
                                  menu.isOpen ? menu.close() : menu.open(),
                            ),
                            menuChildren: [
                              CheckboxMenuButton(
                                value: filter == ShowFilter.saved,
                                onChanged: (_) => ref
                                    .read(showFilterProvider.notifier)
                                    .toggleFilter(),
                                child: const Text('Watching only'),
                              ),
                              MenuItemButton(
                                onPressed: () =>
                                    refreshKey.currentState?.show(),
                                leadingIcon: const Icon(
                                  Icons.refresh,
                                  size: Checkbox.width,
                                ),
                                child: const Text('Refresh releases'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  _EditionLine(today.value),
                  TransferPolicyBanner(snapshot: policy),
                ],
                Expanded(
                  child: IndexedStack(
                    index: selected.value,
                    children: [
                      for (final (index, page) in pages.indexed)
                        TickerMode(
                          enabled: index == selected.value,
                          child: visited.value.contains(index)
                              ? page
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: compactDetail
          ? null
          : SafeArea(
              top: false,
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: PaperLantern.rule)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FractionallySizedBox(
                          alignment: [
                            Alignment.centerLeft,
                            Alignment.center,
                            Alignment.centerRight,
                          ][selected.value],
                          widthFactor: 1 / 3,
                          child: const SizedBox(
                            height: 2,
                            child: ColoredBox(color: PaperLantern.red),
                          ),
                        ),
                        BottomNavigationBar(
                          currentIndex: selected.value,
                          onTap: select,
                          type: BottomNavigationBarType.fixed,
                          selectedFontSize: 12,
                          unselectedFontSize: 12,
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home_outlined),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.calendar_today_outlined),
                              label: 'Schedule',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.tune),
                              label: 'Settings',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
    return PopScope(
      canPop: !compactDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && compactDetail) backToFeed();
      },
      child: content,
    );
  }
}

class _EditionLine extends StatelessWidget {
  const _EditionLine(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: PaperLantern.ink, width: 2),
          bottom: BorderSide(color: PaperLantern.ink),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(
            '${DateFormat.EEEE().format(date)} edition'.toUpperCase(),
            style: PaperLantern.folio,
          ),
          Text(
            DateFormat('d MMMM yyyy').format(date).toUpperCase(),
            style: PaperLantern.folio,
          ),
        ],
      ),
    );
  }
}

class _ReleaseFeed extends HookWidget {
  const _ReleaseFeed({
    super.key,
    required this.anchorKey,
    required this.releases,
    required this.filter,
    required this.refreshKey,
    required this.onRefresh,
    required this.onOpen,
  });
  final AsyncValue<List<ShowInfo>> releases;
  final ShowFilter filter;
  final GlobalKey<RefreshIndicatorState> refreshKey;
  final RefreshCallback onRefresh;
  final ValueChanged<ShowInfo> onOpen;
  final String? anchorKey;

  @override
  Widget build(BuildContext context) {
    final parallax = useValueNotifier(0.0);
    final controller = useScrollController();
    useEffect(() {
      void update() {
        if (controller.hasClients) {
          parallax.value = math.min(math.max(0.0, controller.offset) * .18, 28);
        }
      }

      controller.addListener(update);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) update();
      });
      return () => controller.removeListener(update);
    }, [controller, parallax]);

    final shows = releases.value ?? const <ShowInfo>[];
    final isWatching = filter == ShowFilter.saved;
    final anchorIndex = anchorKey == null
        ? -1
        : shows.indexWhere((show) => show.torrentKey == anchorKey);
    // With a center sliver, a newly folded feed can open at the selected
    // release even when earlier cards have variable heights. Earlier rows
    // grow upwards and stay reachable in their original reading order.
    final center = anchorIndex > 0 ? ValueKey(anchorKey) : null;
    Widget row(int index) =>
        ShowCard(show: shows[index], onOpen: onOpen, revealIndex: index);
    return RefreshIndicator(
      key: refreshKey,
      onRefresh: onRefresh,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: CustomScrollView(
          key: HomePage.scrollViewKey,
          controller: controller,
          center: center,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (shows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: releases.isLoading
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isWatching
                                    ? Icons.bookmark_border
                                    : Icons.menu_book_outlined,
                                color: PaperLantern.muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                releases.hasError
                                    ? 'Couldn’t load releases'
                                    : isWatching
                                    ? 'No saved series found'
                                    : 'No series found',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              if (releases.hasError)
                                TextButton(
                                  onPressed: () =>
                                      refreshKey.currentState?.show(),
                                  child: const Text('Try again'),
                                ),
                              if (isWatching && !releases.hasError)
                                const Text(
                                  'Mark a series as watching to see it here.',
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: ShowCard(
                  show: shows.first,
                  onOpen: onOpen,
                  featured: true,
                  posterParallax: parallax,
                ),
              ),
              if (shows.length > 1) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: PaperSectionHeading(
                      'Release index',
                      trailing: Text(
                        (shows.length - 1).toString().padLeft(2, '0'),
                        style: PaperLantern.folio,
                      ),
                    ),
                  ),
                ),
                if (center != null && anchorIndex > 1)
                  SliverList.builder(
                    itemCount: anchorIndex - 1,
                    itemBuilder: (_, index) => row(anchorIndex - 1 - index),
                  ),
                SliverList.builder(
                  key: center,
                  itemCount: shows.length - (center == null ? 1 : anchorIndex),
                  itemBuilder: (_, index) =>
                      row((center == null ? 1 : anchorIndex) + index),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ],
        ),
      ),
    );
  }
}
