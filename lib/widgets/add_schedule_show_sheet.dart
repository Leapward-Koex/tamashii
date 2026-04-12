import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/jikan_models.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/jikan_api_providers.dart';
import 'package:tamashii/widgets/show_image.dart';

class AddScheduleShowSheet extends HookConsumerWidget {
  const AddScheduleShowSheet({super.key});

  static const Key dayDropdownKey = ValueKey<String>('add-schedule-show-day-dropdown');
  static const Key searchFieldKey = ValueKey<String>('add-schedule-show-search-field');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final selectedDay = useState<int>(DateTime.now().weekday);
    final pendingQuery = useState<String>('');
    final submittedQuery = useState<String>('');
    final debounceTimerRef = useRef<Timer?>(null);

    void runSearch([String? rawQuery]) {
      debounceTimerRef.value?.cancel();
      final trimmedQuery = (rawQuery ?? queryController.text).trim();
      pendingQuery.value = trimmedQuery;
      submittedQuery.value = trimmedQuery;
    }

    useEffect(() {
      void listener() {
        final trimmedQuery = queryController.text.trim();
        pendingQuery.value = trimmedQuery;
        debounceTimerRef.value?.cancel();
        if (trimmedQuery.isEmpty) {
          submittedQuery.value = '';
          return;
        }

        debounceTimerRef.value = Timer(const Duration(seconds: 2), () {
          runSearch(trimmedQuery);
        });
      }

      queryController.addListener(listener);
      return () {
        queryController.removeListener(listener);
        debounceTimerRef.value?.cancel();
      };
    }, [queryController]);

    final searchResultsAsync = ref.watch(searchJikanShowsProvider(submittedQuery.value));
    final watchingShows = ref.watch(bookmarkedSeriesProvider).value ?? const <BookmarkedShowInfo>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add show', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Pick a day, search, and add a show to your watching schedule.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: dayDropdownKey,
                value: selectedDay.value,
                decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                items: List<DropdownMenuItem<int>>.generate(7, (index) {
                  final weekday = index + 1;
                  return DropdownMenuItem<int>(value: weekday, child: Text(_weekdayName(weekday)));
                }),
                onChanged: (value) {
                  if (value != null) {
                    selectedDay.value = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: searchFieldKey,
                controller: queryController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: runSearch,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'Type a show title',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _SearchResults(
                  pendingQuery: pendingQuery.value,
                  submittedQuery: submittedQuery.value,
                  resultsAsync: searchResultsAsync,
                  selectedDay: selectedDay.value,
                  watchingShows: watchingShows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.pendingQuery,
    required this.submittedQuery,
    required this.resultsAsync,
    required this.selectedDay,
    required this.watchingShows,
  });

  final String pendingQuery;
  final String submittedQuery;
  final AsyncValue<List<JikanAnimeSearchResult>> resultsAsync;
  final int selectedDay;
  final List<BookmarkedShowInfo> watchingShows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (submittedQuery.isEmpty) {
      return _SearchPlaceholder(icon: Icons.travel_explore, label: 'Search for a show to add it to ${_weekdayName(selectedDay)}.');
    }

    if (pendingQuery.isNotEmpty && pendingQuery != submittedQuery) {
      return _SearchPlaceholder(icon: Icons.hourglass_bottom, label: 'Search for a show to add it to ${_weekdayName(selectedDay)}.');
    }

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        return _SearchPlaceholder(icon: Icons.error_outline, label: error.toString());
      },
      data: (results) {
        if (results.isEmpty) {
          return const _SearchPlaceholder(icon: Icons.search_off, label: 'No matching shows found.');
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = results[index];
            final showName = result.displayTitle;
            final alreadyWatching = watchingShows.any((show) => show.showName == showName);

            return ListTile(
              key: ValueKey<String>('jikan-search-result-${result.malId}'),
              enabled: !alreadyWatching,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ShowImage(imageUrl: result.imageUrl, width: 44, height: 60),
              ),
              title: Text(showName),
              subtitle: Text(_searchSubtitle(result, alreadyWatching)),
              trailing: Icon(alreadyWatching ? Icons.check_circle : Icons.add_circle_outline),
              onTap:
                  alreadyWatching
                      ? null
                      : () async {
                        final added = await ref
                            .read(bookmarkedSeriesProvider.notifier)
                            .add(
                              BookmarkedShowInfo(
                                imageUrl: result.imageUrl,
                                releaseDayOfWeek: selectedDay,
                                showName: showName,
                                jikanId: result.malId,
                                source: BookmarkedShowSource.manual,
                              ),
                            );

                        if (!context.mounted || !added) {
                          return;
                        }

                        Navigator.of(context).pop(showName);
                      },
            );
          },
        );
      },
    );
  }

  String _searchSubtitle(JikanAnimeSearchResult result, bool alreadyWatching) {
    if (alreadyWatching) {
      return 'Already in your watching list';
    }

    final details = <String>[
      if (result.type != null && result.type!.trim().isNotEmpty) result.type!.trim(),
      if (result.episodes != null) '${result.episodes} eps',
    ];

    if (details.isEmpty) {
      return 'Add to ${_weekdayName(selectedDay)}';
    }

    return '${details.join(' • ')} • ${_weekdayName(selectedDay)}';
  }
}

class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _weekdayName(int weekday) {
  final monday = DateTime.utc(2024, 1, 1);
  return DateFormat('EEEE').format(monday.add(Duration(days: weekday - 1)));
}
