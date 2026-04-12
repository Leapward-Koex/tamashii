import 'dart:convert';

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
