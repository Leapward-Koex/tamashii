import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/pages/settings_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/widgets/show_card.dart';
import '../models/show_models.dart';
import '../providers.dart';

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
    final AsyncValue<List<ShowInfo>> itemsValue =
        currentQuery.isEmpty ? ref.watch(latestShowsProvider) : ref.watch(searchShowsProvider(currentQuery));

    Future<void> refresh() async {
      if (currentQuery.isEmpty) {
        await ref.refresh(latestShowsProvider.future);
      } else {
        await ref.refresh(searchShowsProvider(currentQuery).future);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tamashii'),
        actions: [
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
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(labelText: 'Search', suffixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: itemsValue.when(
              data: (List<ShowInfo> shows) {
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
