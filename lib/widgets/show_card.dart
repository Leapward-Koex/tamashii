import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simple_torrent/simple_torrent.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/pages/show_info_page.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/downloaded_torrents_provider.dart';
import 'package:tamashii/providers/foreground_torrent_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/torrent_download_provider.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/glowing_progress_bar.dart';
import 'package:tamashii/widgets/release_download_button.dart';
import 'package:tamashii/widgets/show_image.dart';
import 'package:tamashii/widgets/staggered_reveal.dart';

export 'release_download_button.dart' show SeriesFolderPlanBuilder;

class ShowCard extends ConsumerWidget {
  const ShowCard({
    super.key,
    required this.show,
    this.onOpen,
    this.seriesFolderPlanBuilder =
        ReleaseDownloadButton.defaultSeriesFolderPlanBuilder,
    this.featured = false,
    this.posterParallax,
    this.revealIndex = 0,
  });

  final ShowInfo show;
  final ValueChanged<ShowInfo>? onOpen;
  final SeriesFolderPlanBuilder seriesFolderPlanBuilder;
  final bool featured;
  final ValueListenable<double>? posterParallax;
  final int revealIndex;

  static Key featuredPosterTransformKey(String showName) =>
      ValueKey<String>('featured-show-poster-transform-$showName');

  static Key featuredCardKey(String showName) =>
      ValueKey<String>('featured-show-card-$showName');

  static Key featuredTopBadgeKey(String showName) =>
      ValueKey<String>('featured-show-top-badge-$showName');

  static Key featuredContentKey(String showName) =>
      ValueKey<String>('featured-show-content-$showName');

  static Key standardCardKey(String showName) =>
      ValueKey<String>('standard-show-card-$showName');

  static Key standardStatusKey(String showName) =>
      ValueKey<String>('standard-show-status-$showName');

  static Key standardActionsKey(String showName) =>
      ValueKey<String>('standard-show-actions-$showName');

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torrentKey = show.torrentKey;
    final target = ShowCatalogTarget.fromRelease(show);
    final isBookmarked = ref.watch(
      bookmarkedSeriesProvider.select(
        (bookmarks) =>
            bookmarks.value?.any(
              (bookmark) => bookmark.showName == show.show,
            ) ??
            false,
      ),
    );
    final torrentDownloadState = ref.watch(
      foregroundTorrentForShowProvider(torrentKey),
    );
    final isDownloaded = ref.watch(
      downloadedTorrentsProvider.select(
        (downloads) => downloads.value?.contains(torrentKey) ?? false,
      ),
    );

    final hasActiveTorrent = torrentDownloadState.torrentId != null;
    final showTorrentDetails =
        hasActiveTorrent && !torrentDownloadState.isCompleted;

    final saved = ref.watch(cachedShowCatalogMatchProvider(target));
    final discover = featured && isBookmarked && !target.isReleaseScoped;
    final lookup = discover && saved == null
        ? ref.watch(showCatalogMatchProvider(target))
        : null;
    final entry = (saved ?? lookup?.value)?.entry;
    final title = entry?.displayTitle ?? show.show;

    Future<void> handleBookmarkPressed() async {
      final bookmarkedNotifier = ref.read(bookmarkedSeriesProvider.notifier);
      if (isBookmarked) {
        await bookmarkedNotifier.remove(show.show);
        return;
      }

      await bookmarkedNotifier.add(
        BookmarkedShowInfo(
          imageUrl: show.imageUrl,
          releaseDayOfWeek: show.releaseDate.toLocal().weekday,
          showName: show.show,
        ),
      );
    }

    final preferredPoster = entry?.posterUrl;
    final poster = ShowImage(
      imageUrl: preferredPoster ?? show.imageUrl,
      fallbackImageUrl: preferredPoster == null ? null : show.imageUrl,
      faceAware: featured && isBookmarked && !(lookup?.isLoading ?? false),
    );
    final download = ReleaseDownloadButton(
      show: show,
      displayTitle: title,
      withLabel: featured,
      seriesFolderPlanBuilder: seriesFolderPlanBuilder,
    );
    final watching = IconButton(
      tooltip: isBookmarked ? 'Remove from watching' : 'Mark as watching',
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        size: 20,
      ),
      color: isBookmarked ? PaperLantern.red : PaperLantern.muted,
      onPressed: handleBookmarkPressed,
    );
    final status = showTorrentDetails
        ? _transferStatus(context, torrentDownloadState)
        : null;
    final card = featured
        ? _feature(
            context,
            title.trim(),
            poster,
            download,
            watching,
            isDownloaded,
            status,
          )
        : _releaseRow(
            context,
            title,
            poster,
            download,
            watching,
            isDownloaded,
            status,
          );
    return StaggeredReveal(index: revealIndex, child: card);
  }

  Widget _releaseSurface(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        key: key,
        color: PaperLantern.paper,
        child: InkWell(
          onTap: () {
            if (onOpen case final open?) {
              open(show);
            } else {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => ShowInfoPage.series(show)),
              );
            }
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: featured
                    ? const BorderSide(color: PaperLantern.ink)
                    : BorderSide.none,
                bottom: BorderSide(
                  color: featured ? PaperLantern.ink : PaperLantern.rule,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: featured ? 14 : 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  String get _episodeLine {
    final resolution = show.bestDownload?.resolution;
    return [
      'Episode ${show.episode}',
      if (resolution != null) '${resolution.toJson()}p',
    ].join(' · ');
  }

  Widget _feature(
    BuildContext context,
    String title,
    Widget poster,
    Widget download,
    Widget watching,
    bool isDownloaded,
    Widget? status,
  ) {
    final theme = Theme.of(context);
    final parallax = posterParallax;
    final editionDate = DateFormat.MMMd().format(show.releaseDate.toLocal());
    final lastWord = title.lastIndexOf(' ');
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Featured release',
          key: featuredTopBadgeKey(show.show),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: PaperLantern.serif,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: PaperLantern.red,
          ),
        ),
        const SizedBox(height: 9),
        Column(
          key: featuredContentKey(show.show),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  if (lastWord != -1)
                    TextSpan(text: title.substring(0, lastWord + 1)),
                  TextSpan(
                    text: title.substring(lastWord + 1),
                    style: lastWord == -1
                        ? null
                        : const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: PaperLantern.red,
                          ),
                  ),
                ],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: PaperLantern.serif,
                color: PaperLantern.ink,
                height: 1.04,
              ),
            ),
            const SizedBox(height: 9),
            Text(_episodeLine, style: PaperLantern.folio),
            Text(
              [
                editionDate,
                if (show.timeLabel.trim().isNotEmpty) show.timeLabel,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: PaperLantern.muted,
              ),
            ),
            if (isDownloaded)
              Text(
                'DOWNLOADED',
                style: PaperLantern.folio.copyWith(color: PaperLantern.red),
              ),
            const SizedBox(height: 7),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [download, watching],
            ),
          ],
        ),
      ],
    );
    final portrait = ClipRect(
      child: parallax == null
          ? poster
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  top: -28,
                  child: ValueListenableBuilder<double>(
                    valueListenable: parallax,
                    child: poster,
                    builder: (context, offset, child) => Transform.translate(
                      key: featuredPosterTransformKey(show.show),
                      offset: Offset(0, offset.clamp(0.0, 28.0)),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
    );
    return _releaseSurface(
      context,
      key: featuredCardKey(show.show),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final posterWidth = (width * .42).clamp(0.0, 220.0);
              final frame = SizedBox(
                width: posterWidth,
                height: posterWidth * 1.32,
                child: ColoredBox(color: PaperLantern.wash, child: portrait),
              );
              // Give large accessibility type the entire column on a narrow phone.
              if (width < 260 ||
                  width < 440 &&
                      MediaQuery.textScalerOf(context).scale(16) >= 26) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [frame, const SizedBox(height: 14), copy],
                );
              }
              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  frame,
                ],
              );
            },
          ),
          if (status != null) ...[const SizedBox(height: 10), status],
        ],
      ),
    );
  }

  Widget _releaseRow(
    BuildContext context,
    String title,
    Widget poster,
    Widget download,
    Widget watching,
    bool isDownloaded,
    Widget? status,
  ) {
    final theme = Theme.of(context);
    return _releaseSurface(
      context,
      key: standardCardKey(show.show),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 60,
                child: ColoredBox(color: PaperLantern.wash, child: poster),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: PaperLantern.serif,
                        fontSize: 18,
                        height: 1.12,
                        color: PaperLantern.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_episodeLine · ${DateFormat.MMMd().format(show.releaseDate.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PaperLantern.muted,
                      ),
                    ),
                    if (isDownloaded)
                      Text(
                        'DONE',
                        style: PaperLantern.folio.copyWith(
                          color: PaperLantern.red,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                key: standardActionsKey(show.show),
                mainAxisSize: MainAxisSize.min,
                children: [download, watching],
              ),
            ],
          ),
          if (status != null) ...[const SizedBox(height: 8), status],
        ],
      ),
    );
  }

  Widget _transferStatus(BuildContext context, TorrentDownloadState state) {
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: PaperLantern.muted);
    final progress = state.progressFraction.isFinite
        ? state.progressFraction.clamp(0.0, 1.0)
        : 0.0;
    final rateText = [
      if (state.metadata != null)
        featured ? state.displayName : state.formattedSize,
      'Down ${_formatBytes(state.downloadRate)}/s',
      'Up ${_formatBytes(state.uploadRate)}/s',
      if (!featured && state.stats != null)
        '${state.seeds} seeds · ${state.peers} peers',
    ].join(' · ');
    return Column(
      key: featured ? null : standardStatusKey(show.show),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _torrentStateLabel(state.currentState),
                style: PaperLantern.folio.copyWith(color: PaperLantern.red),
              ),
            ),
            Text('${(progress * 100).round()}%', style: PaperLantern.folio),
          ],
        ),
        const SizedBox(height: 4),
        GlowingProgressBar(
          progress: progress,
          height: 3,
          color: PaperLantern.red,
          backgroundColor: PaperLantern.wash,
          fillKey: ValueKey<String>(
            'show-progress-fill-${show.show}-${show.episode}',
          ),
        ),
        const SizedBox(height: 4),
        Text(rateText, style: muted),
      ],
    );
  }

  String _torrentStateLabel(TorrentState state) {
    switch (state) {
      case TorrentState.starting:
        return 'STARTING';
      case TorrentState.downloadingMetadata:
        return 'GETTING INFO';
      case TorrentState.downloading:
        return 'DOWNLOADING';
      case TorrentState.seeding:
        return 'SEEDING';
      case TorrentState.paused:
        return 'PAUSED';
      case TorrentState.error:
        return 'ERROR';
      case TorrentState.stopped:
        return 'STOPPED';
    }
  }
}
