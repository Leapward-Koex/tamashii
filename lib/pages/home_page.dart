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
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/add_schedule_show_sheet.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/widgets/transfer_policy_banner.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  static const Key scrollViewKey = ValueKey<String>('home-scroll-view');
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
          if (searching.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                key: searchBarShellKey,
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
          if (filter == ShowFilter.saved)
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
            child: _ReleaseFeed(
              releases: releases,
              filter: filter,
              refreshKey: refreshKey,
              onRefresh: refresh,
            ),
          ),
        ],
      ),
      SchedulePage(today: today.value, onAdd: addToSchedule),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
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
                                      style: TextStyle(color: PaperLantern.red),
                                    ),
                                  ],
                                ),
                                style: Theme.of(context).textTheme.headlineLarge
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
                        key: downloadsButtonKey,
                        tooltip: 'Downloads',
                        icon: Badge(
                          isLabelVisible: activeDownloads > 0,
                          label: Text('$activeDownloads'),
                          child: const Icon(Icons.download_outlined),
                        ),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const DownloadQueuePage(),
                          ),
                        ),
                      ),
                      if (selected.value == 0)
                        PopupMenuButton<String>(
                          tooltip: 'Release options',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) {
                            if (action == 'filter') {
                              ref
                                  .read(showFilterProvider.notifier)
                                  .toggleFilter();
                            } else {
                              refreshKey.currentState?.show();
                            }
                          },
                          itemBuilder: (_) => [
                            CheckedPopupMenuItem(
                              value: 'filter',
                              checked: filter == ShowFilter.saved,
                              child: const Text('Watching only'),
                            ),
                            const PopupMenuItem(
                              value: 'refresh',
                              child: Text('Refresh releases'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _EditionLine(today.value),
                TransferPolicyBanner(snapshot: policy),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
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
    required this.releases,
    required this.filter,
    required this.refreshKey,
    required this.onRefresh,
  });
  final AsyncValue<List<ShowInfo>> releases;
  final ShowFilter filter;
  final GlobalKey<RefreshIndicatorState> refreshKey;
  final RefreshCallback onRefresh;

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
                SliverList.builder(
                  itemCount: shows.length - 1,
                  itemBuilder: (context, index) =>
                      ShowCard(show: shows[index + 1], revealIndex: index + 1),
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
