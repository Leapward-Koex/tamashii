import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/widgets/show_image.dart';

/// A page displaying a weekly schedule for bookmarked series.
class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarked =
        ref.watch(bookmarkedSeriesNotifierProvider).valueOrNull ?? <String>[];
    final latestAsync = ref.watch(combinedEpisodesProvider(''));

    // Controller for continuous horizontal scrolling
    final controller = PageController(
      viewportFraction: 0.9,
      initialPage: DateTime.now().weekday - 1, // Start on current day
    );

    return latestAsync.when(
      data: (shows) {
        // Filter only bookmarked shows
        final bookmarkedShows =
            shows.where((s) => bookmarked.contains(s.show)).toList();

        if (bookmarkedShows.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No scheduled shows'),
                SizedBox(height: 8),
                Text(
                  'Bookmark series to see their schedule here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Group by weekday
        final schedule = <int, List<ShowInfo>>{
          for (var i = 1; i <= 7; i++) i: [],
        };
        for (var show in bookmarkedShows) {
          final weekday = show.releaseDate.weekday; // 1=Mon,7=Sun
          schedule[weekday]?.add(show);
        }

        // Sort shows by their time label within each day
        for (var entry in schedule.entries) {
          entry.value.sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day indicator row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final dayIndex = index + 1;
                  final isToday = dayIndex == DateTime.now().weekday;
                  // Get abbreviated weekday name (Mon, Tue, etc)
                  // Create a date for the specified weekday (1=Mon, 7=Sun)
                  final now = DateTime.now();
                  final mondayOfThisWeek = now.subtract(
                    Duration(days: now.weekday - 1),
                  );
                  final dayName = DateFormat(
                    'E',
                  ).format(mondayOfThisWeek.add(Duration(days: dayIndex - 1)));
                  return InkWell(
                    onTap:
                        () => controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isToday
                                ? Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            isToday
                                ? Border.all(
                                  color: Theme.of(context).primaryColor,
                                )
                                : null,
                      ),
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color:
                              isToday ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Divider
            const Divider(height: 1),

            // Page view for days
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final dayIndex = index + 1;
                  // Full weekday name
                  // Create a date for the specified weekday (1=Mon, 7=Sun)
                  final now = DateTime.now();
                  final mondayOfThisWeek = now.subtract(
                    Duration(days: now.weekday - 1),
                  );
                  final dayName = DateFormat(
                    'EEEE',
                  ).format(mondayOfThisWeek.add(Duration(days: dayIndex - 1)));
                  final dayShows = schedule[dayIndex]!;

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child:
                              dayShows.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.event_busy,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No shows scheduled for $dayName',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: dayShows.length,
                                    itemBuilder: (context, i) {
                                      final show = dayShows[i];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6.0,
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 8.0,
                                              ),
                                          title: Text(
                                            show.show,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(show.timeLabel),
                                                  const SizedBox(width: 8),
                                                  if (show.episode.isNotEmpty)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Episode ${show.episode}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: ShowImage(
                                              show: show,
                                              width: 60,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
