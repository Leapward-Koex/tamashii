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
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/release_download_button.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/show_info_match_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class ShowInfoPage extends HookConsumerWidget {
  const ShowInfoPage.release(
    ShowInfo this.release, {
    super.key,
    this.openExternal = _openExternal,
    this.onEpisodeSelected,
    this.onBack,
  }) : bookmark = null,
       openMatchPicker = false,
       _reader = false;

  const ShowInfoPage.reader(
    ShowInfo this.release, {
    required ValueChanged<ShowInfo> this.onEpisodeSelected,
    super.key,
    this.openExternal = _openExternal,
  }) : bookmark = null,
       openMatchPicker = false,
       onBack = null,
       _reader = true;

  const ShowInfoPage.schedule(
    BookmarkedShowInfo this.bookmark, {
    ShowInfo? latestRelease,
    this.openMatchPicker = false,
    this.openExternal = _openExternal,
    super.key,
  }) : release = latestRelease,
       onEpisodeSelected = null,
       onBack = null,
       _reader = false;

  final ShowInfo? release;
  final BookmarkedShowInfo? bookmark;
  final bool openMatchPicker;
  final Future<bool> Function(Uri uri) openExternal;
  final ValueChanged<ShowInfo>? onEpisodeSelected;
  final VoidCallback? onBack;
  final bool _reader;

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
    final match =
        ref.watch(cachedShowCatalogMatchProvider(target)) ?? lookup.value;
    final page = source?.page.trim() ?? '';
    final synopsis = page.isEmpty
        ? null
        : ref.watch(showSynopsisProvider(page)).value;
    final bookmarks = ref.watch(bookmarkedSeriesProvider);
    final showMore = useState(false);
    final watched =
        bookmarks.value?.any((show) => show.showName == title) ?? false;
    final updating = useState(false);
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
    final canWatch = bookmarks.hasValue && !updating.value;
    final matchPanel = _CatalogMatchPanel(
      target: target,
      lookup: lookup,
      match: match,
      openExternal: openExternal,
      editMatch: editMatch,
      showLink: !_reader,
      retry: () => ref.invalidate(showCatalogMatchProvider(target)),
    );
    final info = [
      matchPanel,
      if (synopsis != null && synopsis.trim().isNotEmpty) ...[
        const SizedBox(height: 20),
        const PaperSectionHeading('SubsPlease synopsis'),
        const SizedBox(height: 4),
        Text(synopsis),
      ],
    ];
    final entry = match?.entry;
    final content = ListView.builder(
      key: PageStorageKey((
        'show-info',
        title,
        release?.page,
        release?.episode,
      )),
      primary: _reader ? false : null,
      padding: EdgeInsets.fromLTRB(18, _reader ? 12 : 6, 18, 24),
      itemCount: scopedEpisodes.length + 1,
      itemBuilder: (context, index) {
        if (index > 0) {
          final episode = scopedEpisodes[index - 1];
          final isSelected =
              bookmark == null &&
              episode.episode == release!.episode &&
              episode.page == release!.page;
          final select = onEpisodeSelected;
          return _EpisodeTile(
            episode: episode,
            reader: _reader,
            selected: isSelected,
            onTap: isSelected
                ? null
                : () {
                    if (select != null) {
                      select(episode);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShowInfoPage.release(episode),
                        ),
                      );
                    }
                  },
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
              entry: entry,
              reader: _reader,
            ),
            const SizedBox(height: 12),
            if (_reader)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: canWatch ? toggleWatching : null,
                    icon: Icon(watched ? Icons.check : Icons.bookmark_border),
                    label: Text(watched ? 'Watching' : 'Watch'),
                  ),
                  if (entry != null && entry.malId > 0)
                    _CatalogLink(
                      malId: entry.malId,
                      openExternal: openExternal,
                      compact: true,
                    )
                  else if (!showMore.value)
                    TextButton(
                      onPressed: editMatch,
                      child: const Text('Find a match'),
                    ),
                  IconButton(
                    tooltip: showMore.value
                        ? 'Hide show details'
                        : 'Show details',
                    isSelected: showMore.value,
                    icon: const Icon(Icons.info_outline),
                    selectedIcon: const Icon(Icons.info),
                    onPressed: () => showMore.value = !showMore.value,
                  ),
                ],
              ),
            if (!_reader || showMore.value) ...[
              if (_reader) const SizedBox(height: 12),
              ...info,
            ],
            const SizedBox(height: 20),
            if (fromFeed) ...[
              PaperSectionHeading(_reader ? 'Releases' : 'SubsPlease releases'),
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
              const PaperSectionHeading('Schedule'),
              const SizedBox(height: 8),
              Text(
                'Added manually · ${DateFormat('EEEE').format(DateTime.utc(2024, 1, bookmark!.releaseDayOfWeek))}',
              ),
            ],
          ],
        );
      },
    );
    if (_reader) return content;
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null ? null : BackButton(onPressed: onBack),
        title: const Text('Show info'),
        actions: [
          TextButton.icon(
            onPressed: canWatch ? toggleWatching : null,
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
            child: content,
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.reader,
    required this.selected,
    required this.onTap,
  });

  final ShowInfo episode;
  final bool reader;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolutions =
        episode.downloads
            .map((option) => int.parse(option.resolution.toJson()))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      shape: const Border(bottom: BorderSide(color: PaperLantern.rule)),
      selected: reader && selected,
      titleTextStyle: Theme.of(context).textTheme.titleMedium,
      title: Text(formatEpisodeLabel(episode.episode)),
      subtitle: Text(
        [
          DateFormat.yMMMd().format(episode.releaseDate.toLocal()),
          ...resolutions.map((value) => '${value}p'),
        ].join(' · '),
      ),
      trailing: reader
          ? (episode.bestDownload == null
                ? null
                : Semantics(
                    label: formatEpisodeLabel(episode.episode),
                    child: ReleaseDownloadButton(show: episode),
                  ))
          : (selected ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.source,
    required this.sourceImage,
    required this.sourceLabel,
    required this.episode,
    required this.entry,
    required this.reader,
  });
  final String source;
  final String sourceImage;
  final String sourceLabel;
  final String? episode;
  final TenraiAnimeSearchResult? entry;
  final bool reader;

  @override
  Widget build(BuildContext context) {
    final matched = entry;
    final title = matched?.displayTitle ?? source;
    final image = matched?.posterUrl ?? '';
    final subtitle = matched != null && matched.title != title
        ? matched.title
        : (title != source ? source : null);
    final meta = [
      if (matched?.type case final type? when type.isNotEmpty) type,
      if (matched?.episodes case final count?)
        '$count ${count == 1 ? 'episode' : 'episodes'}',
      if (matched == null) sourceLabel,
      if (episode case final ep?) formatEpisodeLabel(ep),
    ];
    final theme = Theme.of(context);
    final metadata = Text(
      meta.join(' · '),
      style: PaperLantern.folio.copyWith(color: PaperLantern.red),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!reader && meta.isNotEmpty) ...[
          metadata,
          const SizedBox(height: 8),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineLarge?.copyWith(height: 1.05),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (reader && meta.isNotEmpty) ...[const SizedBox(height: 6), metadata],
      ],
    );
    final poster = ColoredBox(
      color: PaperLantern.wash,
      child: ShowImage(
        imageUrl: image.isEmpty ? sourceImage : image,
        fallbackImageUrl: sourceImage.isEmpty ? null : sourceImage,
        faceAware: true,
      ),
    );
    if (reader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image.isNotEmpty || sourceImage.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: AspectRatio(aspectRatio: 1.85, child: poster),
            ),
            const SizedBox(height: 12),
          ],
          copy,
        ],
      );
    }
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: PaperLantern.ink),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (image.isEmpty && sourceImage.isEmpty) return copy;
          final width = (constraints.maxWidth * .32)
              .clamp(72.0, 148.0)
              .toDouble();
          final thumbnail = SizedBox(
            width: width,
            height: width * 1.38,
            child: poster,
          );
          if (constraints.maxWidth - width <
              MediaQuery.textScalerOf(context).scale(160)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [thumbnail, const SizedBox(height: 12), copy],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 16),
              thumbnail,
            ],
          );
        },
      ),
    );
  }
}

class _CatalogLink extends StatelessWidget {
  const _CatalogLink({
    required this.malId,
    required this.openExternal,
    this.compact = false,
  });

  final int malId;
  final Future<bool> Function(Uri uri) openExternal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Future<void> open() async {
      try {
        if (await openExternal(Uri.https('myanimelist.net', '/anime/$malId'))) {
          return;
        }
      } on Exception {
        // The operating system could not hand the URL to a browser.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open MyAnimeList.')),
        );
      }
    }

    const icon = Icon(Icons.open_in_new, size: 16);
    return compact
        ? OutlinedButton.icon(
            onPressed: open,
            icon: icon,
            label: const Text('MyAnimeList'),
          )
        : TextButton.icon(
            onPressed: open,
            icon: icon,
            label: Text('MyAnimeList #$malId'),
          );
  }
}

class _CatalogMatchPanel extends HookConsumerWidget {
  const _CatalogMatchPanel({
    required this.target,
    required this.lookup,
    required this.match,
    required this.showLink,
    required this.openExternal,
    required this.editMatch,
    required this.retry,
  });
  final ShowCatalogTarget target;
  final AsyncValue<ShowCatalogMatch> lookup;
  final ShowCatalogMatch? match;
  final bool showLink;
  final Future<bool> Function(Uri uri) openExternal;
  final VoidCallback editMatch;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = useState(false);
    final saving = useState(false);
    final theme = Theme.of(context);
    final match = this.match;
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PaperLantern.wash,
        border: Border(left: BorderSide(color: PaperLantern.red, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry != null ? Icons.link : Icons.manage_search_outlined,
                  color: PaperLantern.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading, style: theme.textTheme.titleMedium),
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
                  if (showLink && entry.malId > 0)
                    _CatalogLink(
                      malId: entry.malId,
                      openExternal: openExternal,
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
