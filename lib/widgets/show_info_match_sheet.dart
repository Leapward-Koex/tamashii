import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/models/show_catalog_match.dart';
import 'package:tamashii/models/tenrai_models.dart';
import 'package:tamashii/providers/bookmarked_series_provider.dart';
import 'package:tamashii/providers/show_catalog_match_provider.dart';
import 'package:tamashii/providers/tenrai_api_providers.dart';
import 'package:tamashii/services/show_catalog_matcher.dart';

class ShowInfoMatchSheet extends ConsumerStatefulWidget {
  const ShowInfoMatchSheet({required this.target, super.key});
  final ShowCatalogTarget target;
  static const searchFieldKey = ValueKey('show-info-catalog-search');
  static Key entryKey(int id) => ValueKey('show-info-catalog-entry-$id');

  @override
  ConsumerState<ShowInfoMatchSheet> createState() => _ShowInfoMatchSheetState();
}

class _ShowInfoMatchSheetState extends ConsumerState<ShowInfoMatchSheet> {
  Timer? _debounce;
  String _typed = '';
  String _query = '';
  TenraiAnimeSearchResult? _selected;
  bool _saving = false;
  bool _onlyThisRelease = false;
  String? _saveError;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String text, {bool submit = false}) {
    _debounce?.cancel();
    final query = text.trim();
    if (query != _typed) {
      setState(() {
        _typed = query;
        _selected = null;
        _saveError = null;
      });
    }
    if (submit || query.isEmpty) {
      setState(() => _query = query);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => setState(() => _query = query),
      );
    }
  }

  Future<void> _save(
    TenraiAnimeSearchResult? entry, {
    required bool releaseOnly,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (releaseOnly) {
        await ref
            .read(catalogMatchOverridesProvider.notifier)
            .save(widget.target.forThisRelease, entry);
      } else {
        await ref
            .read(bookmarkedSeriesProvider.notifier)
            .saveCatalogChoice(widget.target, entry);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = error is DuplicateScheduleMatch
              ? error.toString()
              : 'Unable to save your choice. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = widget.target;
    final current = ref.watch(showCatalogMatchProvider(target));
    final match = current.value;
    final currentId = match?.entry?.malId;
    final isId = RegExp(r'^\d+$').hasMatch(_query);
    final id = isId ? int.tryParse(_query) : null;
    AsyncValue<List<TenraiAnimeSearchResult>> results;
    VoidCallback? retry;
    if (_typed != _query) {
      results = const AsyncLoading();
    } else if (_query.isEmpty) {
      results = current.whenData(
        (m) => [
          ?m.entry,
          ...m.candidates.where((c) => c.malId != m.entry?.malId),
        ],
      );
      retry = () => ref.invalidate(showCatalogMatchProvider(target));
    } else if (isId) {
      if (id == null || id <= 0) {
        results = const AsyncData([]);
      } else {
        final provider = catalogEntryByIdProvider(id);
        results = ref.watch(provider).whenData((entry) => [?entry]);
        retry = () => ref.invalidate(provider);
      }
    } else {
      final provider = searchTenraiShowsProvider(_query);
      results = ref.watch(provider);
      retry = () => ref.invalidate(provider);
    }
    final options = {
      for (final e in results.asData?.value ?? <TenraiAnimeSearchResult>[])
        e.malId: e,
    };
    final selectedId = _selected?.malId;
    final chosen = options[selectedId];
    final savedChoices = ref.watch(catalogMatchOverridesProvider);
    final savedForRelease =
        savedChoices.hasValue &&
        target.effectiveOverride(savedChoices.requireValue).releaseOnly;
    final selectsSpecial =
        target.episode != null &&
        chosen != null &&
        catalogEntryIsSpecial(chosen);
    final fixedScope =
        target.isReleaseScoped || savedForRelease || selectsSpecial;
    final releaseOnly = fixedScope || _onlyThisRelease;
    final canEdit = !_saving && savedChoices.hasValue;
    final canSave = canEdit && chosen != null;
    final scope = releaseOnly
        ? 'Applies only to this release.'
        : 'Applies to the regular episodes of this show.';
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).height - keyboard < 320;
    final actions = [
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: canSave
            ? () => _save(chosen, releaseOnly: releaseOnly)
            : null,
        icon: const Icon(Icons.check),
        label: const Text('Use this match'),
      ),
      TextButton(
        onPressed: canEdit ? () => _save(null, releaseOnly: releaseOnly) : null,
        child: const Text('Leave unmatched'),
      ),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: keyboard + 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
            maxWidth: 640,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentId != null ? 'Fix match' : 'Find a match',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      [
                        target.title,
                        if (target.episode != null) target.episode!,
                      ].join(' · '),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(scope, style: theme.textTheme.bodyMedium),
                    if (!target.isReleaseScoped && target.episode != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilterChip(
                          label: const Text('Only this release'),
                          selected: releaseOnly,
                          onSelected: fixedScope || _saving
                              ? null
                              : (selected) =>
                                    setState(() => _onlyThisRelease = selected),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      key: ShowInfoMatchSheet.searchFieldKey,
                      enabled: !_saving,
                      textInputAction: TextInputAction.search,
                      onChanged: _search,
                      onSubmitted: (value) => _search(value, submit: true),
                      decoration: const InputDecoration(
                        labelText: 'Search by title or MAL ID',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _query.isEmpty ? 'Possible entries' : 'Search results',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (results.isLoading || _typed != _query)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Searching Tenrai…'),
                      )
                    else if (results.hasError)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(results.error.toString()),
                        trailing: TextButton(
                          onPressed: retry,
                          child: const Text('Retry'),
                        ),
                      )
                    else if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _query.isEmpty
                              ? 'Search the catalog for another title or a MAL ID.'
                              : 'No entries found. Try another title or MAL ID.',
                        ),
                      )
                    else
                      for (final entry in options.values)
                        ListTile(
                          key: ShowInfoMatchSheet.entryKey(entry.malId),
                          enabled: !_saving,
                          selected: selectedId == entry.malId,
                          selectedTileColor:
                              theme.colorScheme.secondaryContainer,
                          leading: Icon(
                            selectedId == entry.malId
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(entry.displayTitle),
                          subtitle: Text(
                            [
                              if (entry.title != entry.displayTitle)
                                entry.title,
                              [
                                if (entry.type case final type?
                                    when type.isNotEmpty)
                                  type,
                                if (entry.episodes case final count?)
                                  '$count ep',
                                'MAL #${entry.malId}',
                                if (entry.malId == currentId) 'Current',
                              ].join(' · '),
                            ].join('\n'),
                          ),
                          onTap: () => setState(() => _selected = entry),
                        ),
                    if (_saveError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _saveError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (compact) ...actions,
                  ],
                ),
              ),
              if (!compact) ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
