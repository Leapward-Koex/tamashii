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
      return await ref.refresh(filteredShowsProvider(currentQuery).future);
    }

    // Navigation state for pages
    final selectedIndex = useState<int>(0);
    final pages = <Widget>[
      // Home content
      Stack(
        children: [
          // Scrollable content behind search bar
          Positioned.fill(
            child: itemsValue.when(
              data: (List<ShowInfo> shows) {
                if (shows.isEmpty && currentFilter == ShowFilter.saved) {
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
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 80),
                    itemCount: shows.length,
                    itemBuilder: (context, index) {
                      final show = shows[index];
                      return ShowCard(show: show);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
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
                      color: Theme.of(context).canvasColor.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 48,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search',
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
