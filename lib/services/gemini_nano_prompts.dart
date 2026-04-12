import 'dart:convert';

String buildSeasonInferencePrompt(String title) {
  return '''
You are extracting season information from an anime or TV show title.

Determine what season the title belongs to.
Examples:
- "Show Name S4" -> "Season 04"
- "Show Name Season 4" -> "Season 04"
- "Show Name Season 04" -> "Season 04"
- "Show Name part 4" -> "Season 04"
- "Show Name" -> "Season 01"

Respond with exactly two lines:
Season: Season NN or Unknown
Reason: one short sentence

Title: $title
'''.trim();
}

String buildSeriesFolderPrompt({
  required String showTitle,
  required List<String> existingSeriesFolders,
}) {
  final encodedFolders = const JsonEncoder.withIndent(
    '  ',
  ).convert(existingSeriesFolders);

  return '''
You are helping choose a download folder for an anime or TV series.

Your task:
1. Separate the series name from the season indicator in the raw title.
2. If the title does not include an explicit season indicator, use Season 01.
3. If one of the existing series folders is clearly the same franchise, reuse that exact folder name.
4. Convert season or part markers like S4, Season 4, Season 04, Part 4 into a season folder formatted exactly as "Season NN".

Return JSON only. No markdown fences. No extra commentary.

JSON schema:
{
  "series_name": "exact series folder name to use",
  "season_folder": "Season NN",
  "matched_existing_folder": true,
  "reason": "short explanation"
}

Rules:
- If you reuse an existing folder, the "series_name" value must exactly match one of the provided existing folders.
- If no existing folder is a clear match, choose a clean series name without the season suffix.
- If uncertain, prefer the closest existing folder and explain briefly.

Raw title:
$showTitle

Existing series folders at the base path:
$encodedFolders
'''.trim();
}

String buildJikanLookupPreparationPrompt(String rawTitle) {
  return '''
You normalize anime series titles before searching the Jikan/MyAnimeList API.

Return JSON only. No markdown fences. No extra commentary.

JSON schema:
{
  "search_title": "series title with season/part markers removed",
  "season_hint": "Season NN",
  "reason": "short explanation"
}

Rules:
- Remove trailing season, part, cour, or sequel markers from the search title.
- Keep the core franchise name intact.
- Convert S2, Season 2, 2nd Season, Part 2, Cour 2 into "Season 02".
- If the title has no explicit season marker, use "Season 01".

Raw title:
$rawTitle
'''.trim();
}

String buildJikanCandidateSelectionPrompt({
  required String rawTitle,
  required String searchTitle,
  required String seasonHint,
  required List<Map<String, dynamic>> candidates,
}) {
  final encodedCandidates = const JsonEncoder.withIndent(
    '  ',
  ).convert(candidates);

  return '''
You are matching a local anime release title to the correct Jikan/MyAnimeList anime entry.

Choose the candidate that most likely represents the same series and season/part as the raw title.
Prefer the correct season over the most popular base series.
Avoid recap movies, specials, summaries, and side stories unless the raw title clearly points to one.

Return JSON only. No markdown fences. No extra commentary.

JSON schema:
{
  "mal_id": 12345,
  "reason": "short explanation"
}

If no candidate is plausible, return:
{
  "mal_id": null,
  "reason": "short explanation"
}

Raw title:
$rawTitle

Normalized search title:
$searchTitle

Season hint:
$seasonHint

Candidates:
$encodedCandidates
'''.trim();
}
