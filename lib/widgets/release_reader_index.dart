import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/show_models.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/theme/paper_lantern.dart';
import 'package:tamashii/widgets/show_image.dart';

typedef _IndexPosition = ({double offset, String releaseKey});

class ReleaseReaderIndex extends StatelessWidget {
  const ReleaseReaderIndex({
    super.key,
    required this.releases,
    required this.selectedRelease,
    required this.onSelected,
  });

  final List<ShowInfo> releases;
  final ShowInfo selectedRelease;
  final ValueChanged<ShowInfo> onSelected;

  static const scrollKey = PageStorageKey<String>('release-reader-index');
  static Key rowKey(String torrentKey) => ValueKey('reader-row-$torrentKey');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: PaperSectionHeading('Release index'),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => HookBuilder(
              builder: (context) => _buildRows(context, constraints.maxHeight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRows(BuildContext context, double viewportHeight) {
    final scaler = MediaQuery.textScalerOf(context);
    // Reserve three title lines and one episode line at the active
    // font scale. A stable extent also lets a freshly unfolded
    // reader reveal its selected release before the first paint.
    final titleSize = Theme.of(context).textTheme.titleLarge!.fontSize!;
    final rowExtent = math.max(
      98.0,
      28 + scaler.scale(titleSize) * 1.1 * 3 + scaler.scale(11) * 1.4,
    );
    final bucket = PageStorage.maybeOf(context);
    final releaseKey = selectedRelease.torrentKey;
    final initialOffset = useMemoized(() {
      final previous =
          bucket?.readState(context, identifier: scrollKey) as _IndexPosition?;
      final offset = previous?.offset ?? 0.0;
      if (previous?.releaseKey == releaseKey) return offset;
      final index = releases.indexWhere((r) => r.torrentKey == releaseKey);
      if (index < 0) return offset;
      final top = index * rowExtent;
      final bottom = top + rowExtent;
      if (top < offset) return top;
      return math.max(offset, bottom - viewportHeight);
    }, const []);
    final controller = useScrollController(
      initialScrollOffset: initialOffset,
      keepScrollOffset: false,
    );
    useEffect(() {
      // Store the selection alongside the offset so that choosing
      // a different release on the cover can reveal that row.
      void savePosition() => bucket?.writeState(context, (
        offset: controller.hasClients ? controller.offset : initialOffset,
        releaseKey: releaseKey,
      ), identifier: scrollKey);
      savePosition();
      controller.addListener(savePosition);
      return () => controller.removeListener(savePosition);
    }, [controller, bucket, releaseKey]);
    return ListView.builder(
      key: scrollKey,
      primary: false,
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemExtent: rowExtent,
      itemCount: releases.length,
      itemBuilder: (context, index) {
        final release = releases[index];
        return _ReaderRow(
          key: rowKey(release.torrentKey),
          release: release,
          selected: release.torrentKey == selectedRelease.torrentKey,
          onTap: () => onSelected(release),
        );
      },
    );
  }
}

class _ReaderRow extends ConsumerWidget {
  const _ReaderRow({
    required super.key,
    required this.release,
    required this.selected,
    required this.onTap,
  });

  final ShowInfo release;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      cachedShowCatalogMatchProvider(ShowCatalogTarget.fromRelease(release))
          .select((match) => match?.entry),
    );
    final title = entry?.displayTitle ?? release.show;
    final poster = entry?.posterUrl;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : PaperLantern.paper,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  width: 3,
                  color: selected ? PaperLantern.red : Colors.transparent,
                ),
                bottom: const BorderSide(color: PaperLantern.rule),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: ShowImage(
                        imageUrl: poster ?? release.imageUrl,
                        fallbackImageUrl: poster == null
                            ? null
                            : release.imageUrl,
                        width: 66,
                        height: 78,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(height: 1.1),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatEpisodeLabel(release.episode),
                          style: PaperLantern.folio.copyWith(height: 1.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
