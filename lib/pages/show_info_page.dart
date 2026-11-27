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
  const ShowInfoPage.series(
    ShowInfo this.release, {
    super.key,
    this.openExternal = _openExternal,
    this.onBack,
  }) : bookmark = null,
       onSelectDownloadFolder = null,
       openMatchPicker = false,
       _reader = false;

  const ShowInfoPage.reader(
    ShowInfo this.release, {
    super.key,
    this.openExternal = _openExternal,
  }) : bookmark = null,
       onSelectDownloadFolder = null,
       openMatchPicker = false,
       onBack = null,
       _reader = true;

  const ShowInfoPage.schedule(
    BookmarkedShowInfo this.bookmark, {
    ShowInfo? latestRelease,
    this.openMatchPicker = false,
    this.onSelectDownloadFolder,
    this.openExternal = _openExternal,
    super.key,
  }) : release = latestRelease,
       onBack = null,
       _reader = false;

  final ShowInfo? release;
  final BookmarkedShowInfo? bookmark;
  final bool openMatchPicker;
  final Future<void> Function(BuildContext, WidgetRef, ShowCatalogTarget)?
  onSelectDownloadFolder;
  final Future<bool> Function(Uri uri) openExternal;
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
    for (final item in [...?cached, ?release, ...?latest, ...?feed?.value]) {
      if (item.show.trim().toLowerCase() != sourceTitle) {
        continue;
      }
      if (release != null &&
          release!.page.isNotEmpty &&
          release!.page != item.page) {
        continue;
      }
      final key = (item.page, item.episode);
      if (item.bestDownload != null || related[key]?.bestDownload == null) {
        related[key] = item;
      }
    }
    final episodes = related.values.toList()..sort(_oldestFirst);
    final source = episodes.lastOrNull ?? release;
    final target = bookmark == null
        ? ShowCatalogTarget(title: title, page: release!.page)
        : ShowCatalogTarget.fromSchedule(bookmark!, latestRelease: source);
    final lookup = ref.watch(showCatalogMatchProvider(target));
    final match =
        ref.watch(cachedShowCatalogMatchProvider(target)) ?? lookup.value;
    final sourceImage =
        [
          source?.imageUrl,
          release?.imageUrl,
          bookmark?.imageUrl,
        ].whereType<String>().where((url) => url.isNotEmpty).firstOrNull ??
        '';
    final page = source?.page.trim() ?? '';
    final synopsis = page.isEmpty
        ? null
        : ref.watch(showSynopsisProvider(page)).value;
    final bookmarks = ref.watch(bookmarkedSeriesProvider);
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
                  imageUrl: sourceImage,
                  releaseDayOfWeek: source!.releaseDate.toLocal().weekday,
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
      final selectFolder = onSelectDownloadFolder;
      if (selectFolder != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) selectFolder(context, ref, target);
        });
      } else if (openMatchPicker) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) editMatch();
        });
      }
      return null;
    }, const []);
    final canWatch = bookmarks.hasValue && !updating.value;
    final entry = match?.entry;
    final content = ListView.builder(
      key: PageStorageKey(('series-info', title, release?.page)),
      primary: _reader ? false : null,
      padding: EdgeInsets.fromLTRB(18, _reader ? 12 : 6, 18, 24),
      itemCount: episodes.length + 1,
      itemBuilder: (context, index) {
        if (index > 0) {
          final episode = episodes[episodes.length - index];
          return ReleaseDownloadButton.episode(
            key: ValueKey(episode.torrentKey),
            show: episode,
            displayTitle: entry?.displayTitle ?? title,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              source: title,
              sourceImage: sourceImage,
              sourceLabel: fromFeed ? 'SubsPlease' : 'Schedule',
              entry: entry,
              reader: _reader,
            ),
            const SizedBox(height: 12),
            if (_reader) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: canWatch ? toggleWatching : null,
                  icon: Icon(watched ? Icons.check : Icons.bookmark_border),
                  label: Text(watched ? 'Watching' : 'Watch'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _CatalogMatchPanel(
              target: target,
              lookup: lookup,
              match: match,
              openExternal: openExternal,
              editMatch: editMatch,
              retry: () => ref.invalidate(showCatalogMatchProvider(target)),
            ),
            if (synopsis != null && synopsis.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const PaperSectionHeading('Synopsis'),
              const SizedBox(height: 4),
              Text(synopsis),
            ],
            const SizedBox(height: 20),
            if (fromFeed) ...[
              PaperSectionHeading(
                'Releases',
                trailing:
                    episodes.any((episode) => episode.bestDownload != null)
                    ? DownloadAllButton(
                        releases: episodes,
                        displayTitle: entry?.displayTitle ?? title,
                        loadingReleases: feed?.isLoading == true,
                      )
                    : null,
              ),
              if (episodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    feed?.isLoading == true
                        ? 'Looking for releases…'
                        : 'No releases available.',
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
        title: const Text('Series info'),
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

// Legacy cached releases can share a date without a time.
int _oldestFirst(ShowInfo a, ShowInfo b) {
  final date = a.releaseDate.compareTo(b.releaseDate);
  if (date != 0) return date;
  final left = double.tryParse(a.episode);
  final right = double.tryParse(b.episode);
  if (left != null && right != null) return left.compareTo(right);
  if (left != null) return -1;
  if (right != null) return 1;
  return a.episode.compareTo(b.episode);
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.source,
    required this.sourceImage,
    required this.sourceLabel,
    required this.entry,
    required this.reader,
  });
  final String source;
  final String sourceImage;
  final String sourceLabel;
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
    final posterUrl = image.isEmpty ? sourceImage : image;
    final fallback = sourceImage.isEmpty ? null : sourceImage;
    final poster = Tooltip(
      message: 'View full-size poster',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: PaperLantern.wash,
            child: ShowImage(
              imageUrl: posterUrl,
              fallbackImageUrl: fallback,
              faceAware: true,
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _openPoster(context, title, posterUrl, fallback),
            ),
          ),
        ],
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

Future<void> _openPoster(
  BuildContext context,
  String title,
  String posterUrl,
  String? fallback,
) => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          maxScale: 8,
          child: Semantics(
            image: true,
            label: title,
            child: ShowImage(
              imageUrl: posterUrl,
              fallbackImageUrl: fallback,
              fit: BoxFit.contain,
              fullResolution: true,
            ),
          ),
        ),
        PositionedDirectional(
          top: 8,
          end: 8,
          child: SafeArea(
            child: IconButton.filled(
              tooltip: 'Close poster',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    ),
  ),
);

class _CatalogLink extends StatelessWidget {
  const _CatalogLink({required this.malId, required this.openExternal});

  final int malId;
  final Future<bool> Function(Uri uri) openExternal;

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

    return FilledButton.icon(
      onPressed: open,
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('Open MyAnimeList'),
    );
  }
}

class _CatalogMatchPanel extends HookConsumerWidget {
  const _CatalogMatchPanel({
    required this.target,
    required this.lookup,
    required this.match,
    required this.openExternal,
    required this.editMatch,
    required this.retry,
  });
  final ShowCatalogTarget target;
  final AsyncValue<ShowCatalogMatch> lookup;
  final ShowCatalogMatch? match;
  final Future<bool> Function(Uri uri) openExternal;
  final VoidCallback editMatch;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = useState(false);
    final theme = Theme.of(context);
    final match = this.match;
    final entry = match?.entry;
    final candidates = match?.candidates.length ?? 0;
    final manual = match?.userSelected == true;
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
        'Your choice is saved for this series.',
      ),
      _ when candidates > 0 => (
        'Review possible matches',
        'Choose the catalog entry for this series.',
      ),
      _ => (
        'No catalog match found',
        'You can search for another title or keep this series unmatched.',
      ),
    };
    Future<void> leaveUnmatched() async {
      if (saving.value) return;
      saving.value = true;
      try {
        await ref
            .read(bookmarkedSeriesProvider.notifier)
            .saveCatalogChoice(target, null);
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
              ],
            ),
            if (entry != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (entry.malId > 0)
                    _CatalogLink(
                      malId: entry.malId,
                      openExternal: openExternal,
                    ),
                  TextButton(
                    onPressed: editMatch,
                    child: const Text('Fix match'),
                  ),
                ],
              ),
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
