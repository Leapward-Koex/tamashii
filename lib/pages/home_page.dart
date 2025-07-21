import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/providers/filter_provider.dart';
import 'package:tamashii/widgets/show_card.dart';
import '../models/show_models.dart';

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
    final AsyncValue<List<ShowInfo>> itemsValue = ref.watch(filteredShowsProvider(currentQuery));

    Future<void> refresh() async {
      return await ref.refresh(filteredShowsProvider(currentQuery).future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tamashii'),
        actions: [
          // Filter toggle button
          IconButton(
            icon: Icon(currentFilter.icon),
            tooltip: currentFilter.displayName,
            onPressed: () async {
              await ref.read(showFilterNotifierProvider.notifier).toggleFilter();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(labelText: 'Search', suffixIcon: Icon(Icons.search)),
                ),
                const SizedBox(height: 8),
                // Filter status indicator
                if (currentFilter == ShowFilter.saved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark, size: 16, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Showing Saved Series Only',
                          style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: itemsValue.when(
              data: (List<ShowInfo> shows) {
                if (shows.isEmpty && currentFilter == ShowFilter.saved) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
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
        ],
      ),
    );
  }
}
