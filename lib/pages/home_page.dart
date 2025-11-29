import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/pages/schedule_page.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/widgets/show_card.dart';
import 'package:tamashii/models/show_models.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextEditingController searchController = useTextEditingController();
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

    final String currentQuery = debouncedQuery.value;

    // Watch the current filter
    final filterAsync = ref.watch(showFilterNotifierProvider);
    final currentFilter = filterAsync.value ?? ShowFilter.all;

    // Use filtered shows instead of raw shows
    final AsyncValue<List<ShowInfo>> itemsValue = ref.watch(
      filteredShowsProvider(currentQuery),
    );

    Future<void> refresh() async {
      return await ref.refresh(latestShowsProvider.future);
    }

    // Navigation state for pages
    final selectedIndex = useState<int>(0);
    final pages = <Widget>[
      // Home content
      Stack(
        children: [
          // Scrollable content behind search bar
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final List<ShowInfo> shows =
                    itemsValue.valueOrNull ?? const <ShowInfo>[];

                // First load: show spinner when we have no data yet and loading
                if (shows.isEmpty && itemsValue.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Empty states (only when not loading and no data to show)
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
                  // Generic empty (e.g., no search results)
                  return const Center(child: Text('No series found'));
                }

                // Show existing items while loading or on error; user still can pull-to-refresh
                return RefreshIndicator(
                  key: refreshKey,
                  onRefresh: refresh,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      // Allow pull-to-refresh with mouse/trackpad on desktop
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView.builder(
                      // Allow pull even when list doesn't overflow
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 80),
                      itemCount: shows.length,
                      itemBuilder: (context, index) {
                        final show = shows[index];
                        return ShowCard(show: show);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Frosted glass search bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).canvasColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      height: 48,
                      alignment: Alignment.center,
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                        ),
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for shows...',
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Schedule page
      const SchedulePage(),
      // Settings page
      const SettingsPage(),
    ];
    const titles = ['Tamashii', 'Schedule', 'Settings'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex.value]),
        elevation: 0,
        actions:
            selectedIndex.value == 0
                ? [
                  // Filter toggle button
                  IconButton(
                    icon: Icon(currentFilter.icon),
                    tooltip: currentFilter.displayName,
                    onPressed: () async {
                      await ref
                          .read(showFilterNotifierProvider.notifier)
                          .toggleFilter();
                    },
                  ),
                  // Manual refresh button (desktop-friendly)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      // Shows the indicator and invokes onRefresh
                      refreshKey.currentState?.show();
                    },
                  ),
                ]
                : null,
      ),
      body: IndexedStack(index: selectedIndex.value, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex.value,
        onTap: (i) => selectedIndex.value = i,
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
