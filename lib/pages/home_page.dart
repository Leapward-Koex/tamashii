import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/download_queue_page.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/providers/download_queue_provider.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
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
    const double searchBarMaxHeight = 60;
    const double searchBarMinHeight = 44;
    const double searchBarOuterPadding = 16;
    const double homeListTopInset =
        searchBarMaxHeight + (searchBarOuterPadding * 2) + 12;
    const double refreshIndicatorDisplacement = homeListTopInset + 24;

    final TextEditingController searchController = useTextEditingController();
    final searchBarProgress = useValueNotifier(0.0);
    final posterParallax = useValueNotifier(0.0);
    late final ScrollController scrollController;
    void updateScrollEffects() {
      final offset = scrollController.hasClients
          ? scrollController.offset
          : 0.0;
      searchBarProgress.value = (offset / 140).clamp(0.0, 1.0);
      posterParallax.value = math.min(offset * 0.18, 28.0);
    }

    void restoreScrollEffects(ScrollPosition _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          updateScrollEffects();
        }
      });
    }

    scrollController = useScrollController(
      onAttach: restoreScrollEffects,
      onDetach: restoreScrollEffects,
    );
    final debounceTimerRef = useRef<Timer?>(null);
    final debouncedQuery = useState<String>('');

    final refreshKey = useMemoized<GlobalKey<RefreshIndicatorState>>(
      () => GlobalKey<RefreshIndicatorState>(),
    );

    useEffect(() {
      void listener() {
        if (debounceTimerRef.value != null) {
          debounceTimerRef.value!.cancel();
        }
        debounceTimerRef.value = Timer(const Duration(milliseconds: 500), () {
          debouncedQuery.value = searchController.text;
        });
      }

      searchController.addListener(listener);
      return () {
        searchController.removeListener(listener);
        if (debounceTimerRef.value != null) {
          debounceTimerRef.value!.cancel();
        }
      };
    }, [searchController]);

    useEffect(() {
      scrollController.addListener(updateScrollEffects);
      return () => scrollController.removeListener(updateScrollEffects);
    }, [scrollController, searchBarProgress, posterParallax]);

    final String currentQuery = debouncedQuery.value;

    // Watch the current filter
    final filterAsync = ref.watch(showFilterProvider);
    final currentFilter = filterAsync.value ?? ShowFilter.all;

    // Use filtered shows instead of raw shows
    final AsyncValue<List<ShowInfo>> itemsValue = ref.watch(
      filteredShowsProvider(currentQuery),
    );

    Future<void> refresh() async {
      return await ref.refresh(latestShowsProvider.future);
    }

    final selectedIndex = useState<int>(0);
    final visitedTabs = useRef(<int>{0});
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final transferPolicy = isAndroid
        ? ref.watch(foregroundTransferPolicyStatusProvider)
        : null;
    final activeDownloadCount = selectedIndex.value == 0
        ? ref.watch(activeDownloadCountProvider)
        : 0;
    final theme = Theme.of(context);
    final pages = <Widget>[
      Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: 0.24),
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.84),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final List<ShowInfo> shows =
                    itemsValue.value ?? const <ShowInfo>[];

                if (shows.isEmpty && itemsValue.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (shows.isEmpty) {
                  if (currentFilter == ShowFilter.saved) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('No saved series found'),
                          SizedBox(height: 8),
                          Text(
                            'Bookmark some series to see them here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(child: Text('No series found'));
                }

                return RefreshIndicator(
                  key: refreshKey,
                  onRefresh: refresh,
                  edgeOffset: homeListTopInset,
                  displacement: refreshIndicatorDisplacement,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: CustomScrollView(
                      key: scrollViewKey,
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        const SliverToBoxAdapter(
                          child: SizedBox(height: homeListTopInset),
                        ),
                        SliverToBoxAdapter(
                          child: ShowCard(
                            show: shows.first,
                            featured: true,
                            posterParallax: posterParallax,
                          ),
                        ),
                        if (shows.length > 1)
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final show = shows[index + 1];
                              return ShowCard(
                                show: show,
                                revealIndex: index + 1,
                              );
                            }, childCount: shows.length - 1),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: searchBarProgress,
              child: TextField(
                controller: searchController,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for shows...',
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              builder: (context, progress, child) {
                final searchBarHeight = lerpDouble(
                  searchBarMaxHeight,
                  searchBarMinHeight,
                  progress,
                )!;
                final horizontalPadding = lerpDouble(
                  searchBarOuterPadding,
                  10,
                  progress,
                )!;
                final verticalPadding = lerpDouble(
                  searchBarOuterPadding,
                  8,
                  progress,
                )!;
                final blur = lerpDouble(18, 8, progress)!;
                final radius = lerpDouble(24, 18, progress)!;
                final background = theme.colorScheme.surface.withValues(
                  alpha: isAndroid
                      ? lerpDouble(0.92, 0.98, progress)!
                      : lerpDouble(0.58, 0.88, progress)!,
                );
                final searchShell = Container(
                  key: searchBarShellKey,
                  height: searchBarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Color.lerp(
                        Colors.white.withValues(alpha: 0.18),
                        theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.34,
                        ),
                        progress,
                      )!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: child,
                );
                return SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: isAndroid
                          ? searchShell
                          : BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: blur,
                                sigmaY: blur,
                              ),
                              child: searchShell,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      const SchedulePage(),
      const SettingsPage(),
    ];
    const titles = ['Tamashii', 'Schedule', 'Settings'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex.value]),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: selectedIndex.value == 0
            ? [
                IconButton(
                  key: downloadsButtonKey,
                  icon: Badge(
                    isLabelVisible: activeDownloadCount > 0,
                    label: Text('$activeDownloadCount'),
                    child: const Icon(Icons.download_outlined),
                  ),
                  tooltip: 'Downloads',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const DownloadQueuePage(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(currentFilter.icon),
                  tooltip: currentFilter.displayName,
                  onPressed: () async {
                    await ref.read(showFilterProvider.notifier).toggleFilter();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    refreshKey.currentState?.show();
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          TransferPolicyBanner(snapshot: transferPolicy),
          Expanded(
            child: IndexedStack(
              index: selectedIndex.value,
              children: [
                for (final (index, page) in pages.indexed)
                  TickerMode(
                    enabled: index == selectedIndex.value,
                    child: visitedTabs.value.contains(index)
                        ? page
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: selectedIndex.value == 1
          ? FloatingActionButton(
              key: scheduleAddFabKey,
              onPressed: () async {
                final addedShowName = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AddScheduleShowSheet(),
                );

                if (!context.mounted || addedShowName == null) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added "$addedShowName" to your watching list.',
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex.value,
        onTap: (i) {
          visitedTabs.value.add(i);
          selectedIndex.value = i;
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
