import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/cached_episodes_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/subsplease_api_providers.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/show_info_match_sheet.dart';

class ShowInfoPage extends HookConsumerWidget {
  const ShowInfoPage.release(ShowInfo this.release, {super.key})
    : bookmark = null,
      openMatchPicker = false;

  const ShowInfoPage.schedule(
    BookmarkedShowInfo this.bookmark, {
    ShowInfo? latestRelease,
    this.openMatchPicker = false,
    super.key,
  }) : release = latestRelease;

  final ShowInfo? release;
  final BookmarkedShowInfo? bookmark;
  final bool openMatchPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = bookmark?.showName ?? release!.show;
    final fromFeed = bookmark?.isManualEntry != true;
    final cached = fromFeed ? ref.watch(cachedEpisodesProvider).value : null;
    final latest = fromFeed ? ref.watch(latestShowsProvider).value : null;
    final feed = fromFeed ? ref.watch(searchShowsProvider(title)) : null;
    final related = <(String, String), ShowInfo>{};
    final sourceTitle = title.trim().toLowerCase();
    for (final item in [...?cached, ...?latest, ...?feed?.value, ?release]) {
      if (item.show.trim().toLowerCase() != sourceTitle) {
        continue;
      }
      if (release != null &&
          release!.page.isNotEmpty &&
          release!.page != item.page) {
        continue;
      }
      related[(item.page, item.episode)] = item;
    }
    final episodes = related.values.toList()
      ..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    final source = release ?? episodes.firstOrNull;
    final target = bookmark == null
        ? ShowCatalogTarget.fromRelease(release!)
        : ShowCatalogTarget.fromSchedule(bookmark!, latestRelease: source);
    final lookup = ref.watch(showCatalogMatchProvider(target));
    final match = lookup.value;
    final page = source?.page.trim() ?? '';
    final synopsis = page.isEmpty
        ? null
        : ref.watch(showSynopsisProvider(page)).value;
    final bookmarks = ref.watch(bookmarkedSeriesProvider);
    final watched =
        bookmarks.value?.any((show) => show.showName == title) ?? false;
    final updating = useState(false);
    final theme = Theme.of(context);

    Future<void> toggleWatching() async {
      if (updating.value) return;
      updating.value = true;
      try {
        final notifier = ref.read(bookmarkedSeriesProvider.notifier);
        if (watched) {
          await notifier.remove(title);
        } else {
          await notifier.add(
            bookmark ??
                BookmarkedShowInfo(
                  showName: title,
                  imageUrl: source!.imageUrl,
                  releaseDayOfWeek: source.releaseDate.toLocal().weekday,
                ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update the watching list.'),
            ),
          );
        }
      } finally {
        if (context.mounted) updating.value = false;
      }
    }

    void editMatch() {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ShowInfoMatchSheet(target: target),
      );
    }

    useEffect(() {
      if (openMatchPicker) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) editMatch();
        });
      }
      return null;
    }, const []);
    final scopedEpisodes =
        (target.isReleaseScoped || match?.releaseOnly == true) &&
            bookmark == null
        ? [release!]
        : episodes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show info'),
        actions: [
          TextButton.icon(
            onPressed: bookmarks.hasValue && !updating.value
                ? toggleWatching
                : null,
            icon: Icon(watched ? Icons.bookmark : Icons.bookmark_border),
            label: Text(watched ? 'Watching' : 'Watch'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: scopedEpisodes.length + 1,
              itemBuilder: (context, index) {
                if (index > 0) {
                  final episode = scopedEpisodes[index - 1];
                  final selected =
                      bookmark == null &&
                      episode.episode == release!.episode &&
                      episode.page == release!.page;
                  final resolutions =
                      episode.downloads
                          .map(
                            (option) => int.parse(option.resolution.toJson()),
                          )
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a));
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie_outlined),
                    title: Text(_episodeLabel(episode.episode)),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd().format(
                          episode.releaseDate.toLocal(),
                        ),
                        ...resolutions.map((value) => '${value}p'),
                      ].join(' · '),
                    ),
                    trailing: selected ? null : const Icon(Icons.chevron_right),
                    onTap: selected
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ShowInfoPage.release(episode),
                            ),
                          ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      source: title,
                      sourceImage: source?.imageUrl ?? bookmark?.imageUrl ?? '',
                      sourceLabel: fromFeed ? 'SubsPlease' : 'Schedule',
                      episode: bookmark == null ? release!.episode : null,
                      entry: match?.entry,
                    ),
                    const SizedBox(height: 14),
                    _MatchCard(
                      target: target,
                      lookup: lookup,
                      editMatch: editMatch,
                      retry: () =>
                          ref.invalidate(showCatalogMatchProvider(target)),
                    ),
                    if (synopsis != null && synopsis.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'SubsPlease synopsis',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(synopsis),
                    ],
                    const SizedBox(height: 20),
                    if (fromFeed) ...[
                      Text(
                        'SubsPlease releases',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (scopedEpisodes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            feed?.isLoading == true
                                ? 'Looking for releases…'
                                : 'No SubsPlease releases available.',
                          ),
                        ),
                    ] else ...[
                      Text('Schedule', style: theme.textTheme.titleMedium),
                      Text(
                        'Added manually · ${DateFormat('EEEE').format(DateTime.utc(2024, 1, bookmark!.releaseDayOfWeek))}',
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _episodeLabel(String episode) =>
    RegExp(r'^\d+(?:\.\d+)?(?:v\d+)?$', caseSensitive: false).hasMatch(episode)
    ? 'Episode $episode'
    : episode;

class _Hero extends StatelessWidget {
  const _Hero({
    required this.source,
    required this.sourceImage,
    required this.sourceLabel,
    required this.episode,
    required this.entry,
  });
  final String source;
  final String sourceImage;
  final String sourceLabel;
  final String? episode;
  final TenraiAnimeSearchResult? entry;

  @override
  Widget build(BuildContext context) {
    final matched = entry;
    final title = matched?.displayTitle ?? source;
    final image = matched?.largeImageUrl ?? matched?.imageUrl ?? '';
    final subtitle = matched != null && matched.title != title
        ? matched.title
        : (title != source ? source : null);
    final meta = [
      if (matched?.type case final type? when type.isNotEmpty) type,
      if (matched?.episodes case final count?)
        '$count ${count == 1 ? 'episode' : 'episodes'}',
      if (matched == null) sourceLabel,
      if (episode case final ep?) _episodeLabel(ep),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xff26323f),
              child: image.isEmpty && sourceImage.isEmpty
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Icon(
                          Icons.local_movies_outlined,
                          size: 58,
                          color: Colors.white24,
                        ),
                      ),
                    )
                  : ShowImage(
                      imageUrl: image.isEmpty ? sourceImage : image,
                      fallbackImageUrl: sourceImage,
                      faceAware: true,
                    ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xb3000000),
                    Color(0xf2000000),
                  ],
                  stops: [0, .7, 1],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 210,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (meta.isNotEmpty)
                    Text(
                      meta.join(' · '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends HookConsumerWidget {
  const _MatchCard({
    required this.target,
    required this.lookup,
    required this.editMatch,
    required this.retry,
  });
  final ShowCatalogTarget target;
  final AsyncValue<ShowCatalogMatch> lookup;
  final VoidCallback editMatch;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = useState(false);
    final saving = useState(false);
    final theme = Theme.of(context);
    final match = lookup.value;
    final entry = match?.entry;
    final candidates = match?.candidates.length ?? 0;
    final manual = match?.userSelected == true;
    final releaseOnly = target.isReleaseScoped || match?.releaseOnly == true;
    final scope = releaseOnly ? 'release' : 'show';
    final scopeDescription = releaseOnly
        ? 'Applies only to this release.'
        : 'Applies to the regular episodes of this show.';
    final evidence =
        match?.evidence ??
        (manual && entry != null
            ? 'You linked “${target.title}” to “${entry.displayTitle}”. $scopeDescription'
            : null);
    final (heading, description) = switch (match) {
      ShowCatalogMatch(entry: _?) => (
        'MyAnimeList match',
        manual ? 'Chosen by you' : 'Matched automatically',
      ),
      _ when lookup.hasError => (
        'Catalog lookup unavailable',
        'Unable to check Tenrai right now. You can try again.',
      ),
      null => ('Finding a MyAnimeList match…', 'Checking Tenrai'),
      ShowCatalogMatch(userSelected: true) => (
        'Kept unmatched',
        'Your choice is saved for this $scope.',
      ),
      _ when candidates > 0 => (
        'Review possible matches',
        'Choose the catalog entry that fits this $scope.',
      ),
      _ => (
        'No catalog match found',
        'You can search for another title or keep this $scope unmatched.',
      ),
    };
    Future<void> leaveUnmatched() async {
      if (saving.value) return;
      saving.value = true;
      try {
        if (releaseOnly) {
          await ref
              .read(catalogMatchOverridesProvider.notifier)
              .save(target.forThisRelease, null);
        } else {
          await ref
              .read(bookmarkedSeriesProvider.notifier)
              .saveCatalogChoice(target, null);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to save the match. Please try again.'),
            ),
          );
        }
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    entry != null ? Icons.link : Icons.manage_search_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (entry != null)
                  TextButton(
                    onPressed: editMatch,
                    child: const Text('Fix match'),
                  ),
              ],
            ),
            if (entry != null) ...[
              const Divider(),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                children: [
                  SelectableText(
                    'Tenrai · MAL #${entry.malId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (evidence != null)
                    TextButton(
                      onPressed: () => expanded.value = !expanded.value,
                      child: Text(manual ? 'Match details' : 'Why this match?'),
                    ),
                ],
              ),
              if (expanded.value && evidence != null) Text(evidence),
            ] else ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (lookup.hasError)
                    TextButton(onPressed: retry, child: const Text('Retry')),
                  FilledButton.tonal(
                    onPressed: saving.value ? null : editMatch,
                    child: Text(
                      candidates > 0
                          ? 'Review $candidates ${candidates == 1 ? 'match' : 'matches'}'
                          : 'Find a match',
                    ),
                  ),
                  if (match != null && !manual)
                    TextButton(
                      onPressed: saving.value ? null : leaveUnmatched,
                      child: const Text('Leave unmatched'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
