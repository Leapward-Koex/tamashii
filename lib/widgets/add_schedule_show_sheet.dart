import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/widgets/show_image.dart';

class AddScheduleShowSheet extends HookConsumerWidget {
  const AddScheduleShowSheet({super.key});

  static const Key dayDropdownKey = ValueKey<String>(
    'add-schedule-show-day-dropdown',
  );
  static const Key searchFieldKey = ValueKey<String>(
    'add-schedule-show-search-field',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final selectedDay = useState(DateTime.now().weekday);
    final pendingQuery = useState('');
    final submittedQuery = useState('');
    final debounceTimer = useRef<Timer?>(null);
    final isSaving = useState(false);
    final saveError = useState<String?>(null);

    void runSearch(String query) {
      debounceTimer.value?.cancel();
      submittedQuery.value = query.trim();
    }

    useEffect(() {
      void onQueryChanged() {
        final title = queryController.text.trim();
        if (title == pendingQuery.value) {
          return;
        }

        pendingQuery.value = title;
        saveError.value = null;
        debounceTimer.value?.cancel();
        if (title.isEmpty) {
          runSearch(title);
          return;
        }

        debounceTimer.value = Timer(
          const Duration(seconds: 2),
          () => runSearch(title),
        );
      }

      queryController.addListener(onQueryChanged);
      return () {
        queryController.removeListener(onQueryChanged);
        debounceTimer.value?.cancel();
      };
    }, [queryController]);

    final searchProvider = searchTenraiShowsProvider(submittedQuery.value);
    final searchResults = ref.watch(searchProvider);
    final bookmarks = ref.watch(bookmarkedSeriesProvider);
    final canSave = !isSaving.value && bookmarks.hasValue;

    Future<void> save(String title, {TenraiAnimeSearchResult? match}) async {
      if (isSaving.value) {
        return;
      }
      isSaving.value = true;
      saveError.value = null;
      try {
        final notifier = ref.read(bookmarkedSeriesProvider.notifier);
        final saved = await notifier.add(
          BookmarkedShowInfo(
            imageUrl: match?.imageUrl ?? '',
            releaseDayOfWeek: selectedDay.value,
            showName: title,
            malId: match?.malId,
            source: BookmarkedShowSource.manual,
          ),
        );

        if (!context.mounted) {
          return;
        }
        if (saved) {
          Navigator.of(context).pop(title);
          return;
        }

        saveError.value = 'This show is already on your schedule.';
      } catch (_) {
        if (context.mounted) {
          saveError.value = 'Unable to save your schedule. Please try again.';
        }
      } finally {
        if (context.mounted) {
          isSaving.value = false;
        }
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add show',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: dayDropdownKey,
                initialValue: selectedDay.value,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(7, (index) {
                  final weekday = index + 1;
                  return DropdownMenuItem<int>(
                    value: weekday,
                    child: Text(_weekdayName(weekday)),
                  );
                }),
                onChanged: isSaving.value
                    ? null
                    : (value) {
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
                enabled: !isSaving.value,
                textInputAction: TextInputAction.search,
                onSubmitted: runSearch,
                decoration: const InputDecoration(
                  labelText: 'Show title',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              if (pendingQuery.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: canSave ? () => save(pendingQuery.value) : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Add by title'),
                  ),
                ),
              ],
              if (saveError.value case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _SearchResults(
                waitingForQuery:
                    submittedQuery.value.isEmpty ||
                    pendingQuery.value != submittedQuery.value,
                results: searchResults,
                selectedDay: selectedDay.value,
                canSave: canSave,
                watchingShows: bookmarks.value ?? const [],
                onRetry: () => ref.invalidate(searchProvider),
                onSelect: (result) => save(result.displayTitle, match: result),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.waitingForQuery,
    required this.results,
    required this.selectedDay,
    required this.canSave,
    required this.watchingShows,
    required this.onRetry,
    required this.onSelect,
  });

  final bool waitingForQuery;
  final AsyncValue<List<TenraiAnimeSearchResult>> results;
  final int selectedDay;
  final bool canSave;
  final List<BookmarkedShowInfo> watchingShows;
  final VoidCallback onRetry;
  final ValueChanged<TenraiAnimeSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    if (waitingForQuery) {
      return _SearchStatus(
        label: 'Search for a show to add it to ${_weekdayName(selectedDay)}.',
      );
    }

    return results.when(
      skipLoadingOnRefresh: false,
      loading: () => const _SearchStatus(
        label: 'Searching Tenrai…',
        leading: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, _) => _SearchStatus(
        label: error.toString(),
        action: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return const _SearchStatus(label: 'No matching shows found.');
        }

        return Column(
          children: ListTile.divideTiles(
            context: context,
            tiles: matches.map((result) {
              final showName = result.displayTitle;
              final alreadyWatching = watchingShows.any(
                (show) =>
                    show.malId == result.malId ||
                    show.showName.trim().toLowerCase() ==
                        showName.trim().toLowerCase(),
              );

              return ListTile(
                key: ValueKey<String>('tenrai-search-result-${result.malId}'),
                enabled: canSave && !alreadyWatching,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ShowImage(
                    imageUrl: result.imageUrl,
                    width: 44,
                    height: 60,
                  ),
                ),
                title: Text(showName),
                subtitle: Text(_searchSubtitle(result, alreadyWatching)),
                trailing: Icon(
                  alreadyWatching
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                ),
                onTap: canSave && !alreadyWatching
                    ? () => onSelect(result)
                    : null,
              );
            }),
          ).toList(),
        );
      },
    );
  }

  String _searchSubtitle(TenraiAnimeSearchResult result, bool alreadyWatching) {
    if (alreadyWatching) {
      return 'Already in your watching list';
    }

    final details = <String>[
      if (result.type case final type? when type.trim().isNotEmpty) type.trim(),
      if (result.episodes case final episodes?) '$episodes eps',
      _weekdayName(selectedDay),
    ];
    return details.join(' • ');
  }
}

class _SearchStatus extends StatelessWidget {
  const _SearchStatus({required this.label, this.leading, this.action});

  final String label;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: leading,
        title: Text(label),
        trailing: action,
      ),
    );
  }
}

String _weekdayName(int weekday) {
  final monday = DateTime.utc(2024);
  return DateFormat('EEEE').format(monday.add(Duration(days: weekday - 1)));
}
