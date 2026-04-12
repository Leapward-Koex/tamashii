import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tamashii/services/gemini_nano_prompts.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class SeriesFolderAiSuggestion {
  const SeriesFolderAiSuggestion({
    required this.seriesName,
    required this.seasonFolder,
    required this.matchedExistingFolder,
    required this.reason,
  });

  final String seriesName;
  final String seasonFolder;
  final bool matchedExistingFolder;
  final String? reason;
}

class SeriesFolderResolutionPlan {
  const SeriesFolderResolutionPlan({
    required this.usedAi,
    required this.seriesFolderName,
    required this.seasonFolderName,
    required this.suggestedPath,
    required this.fallbackSeriesFolderName,
    required this.fallbackPath,
    required this.existingSeriesFolders,
    required this.rawAiResponse,
    required this.modelUsed,
    required this.reason,
  });

  final bool usedAi;
  final String seriesFolderName;
  final String? seasonFolderName;
  final String suggestedPath;
  final String fallbackSeriesFolderName;
  final String fallbackPath;
  final List<String> existingSeriesFolders;
  final String? rawAiResponse;
  final String? modelUsed;
  final String? reason;
}

class BaseFolderDirectoryLister {
  const BaseFolderDirectoryLister();

  Future<List<String>> listSeriesFolders(String basePath) async {
    final directory = Directory(basePath);
    if (!await directory.exists()) {
      return <String>[];
    }

    final entries =
        await directory
            .list(followLinks: false)
            .where((entity) => entity is Directory)
            .cast<Directory>()
            .map((directory) => p.basename(directory.path))
            .toList();

    entries.sort((lhs, rhs) => lhs.toLowerCase().compareTo(rhs.toLowerCase()));
    return entries;
  }
}

class SeriesFolderResolutionService {
  const SeriesFolderResolutionService({
    required this.textGenerator,
    this.directoryLister = const BaseFolderDirectoryLister(),
  });

  final OnDeviceTextGenerator textGenerator;
  final BaseFolderDirectoryLister directoryLister;

  Future<SeriesFolderResolutionPlan> plan({
    required String showTitle,
    required String basePath,
  }) async {
    final existingSeriesFolders = await directoryLister.listSeriesFolders(
      basePath,
    );
    final fallbackSeriesFolderName = sanitizeFolderSegment(showTitle);
    final fallbackPath = p.join(basePath, fallbackSeriesFolderName);

    try {
      final catalog = await textGenerator.getModelCatalog();
      if (!catalog.hasUsableModel) {
        return _fallbackPlan(
          existingSeriesFolders: existingSeriesFolders,
          fallbackPath: fallbackPath,
          fallbackSeriesFolderName: fallbackSeriesFolderName,
        );
      }

      final prompt = buildSeriesFolderPrompt(
        showTitle: showTitle,
        existingSeriesFolders: existingSeriesFolders,
      );
      final response = await textGenerator.generateText(prompt: prompt);
      final suggestion = parseAiSuggestion(
        response.text,
        fallbackSeriesFolderName: fallbackSeriesFolderName,
      );

      if (suggestion == null) {
        return _fallbackPlan(
          existingSeriesFolders: existingSeriesFolders,
          fallbackPath: fallbackPath,
          fallbackSeriesFolderName: fallbackSeriesFolderName,
        );
      }

      final seriesFolderName =
          existingSeriesFolders.contains(suggestion.seriesName)
              ? suggestion.seriesName
              : sanitizeFolderSegment(suggestion.seriesName);
      final seasonFolderName = normalizeUserSeasonFolder(
        suggestion.seasonFolder,
      );
      final suggestedPath = buildPath(
        basePath: basePath,
        seriesFolderName: seriesFolderName,
        seasonFolderName: seasonFolderName,
      );

      return SeriesFolderResolutionPlan(
        usedAi: true,
        seriesFolderName: seriesFolderName,
        seasonFolderName: seasonFolderName,
        suggestedPath: suggestedPath,
        fallbackSeriesFolderName: fallbackSeriesFolderName,
        fallbackPath: fallbackPath,
        existingSeriesFolders: existingSeriesFolders,
        rawAiResponse: response.text,
        modelUsed: response.modelUsed ?? catalog.availableModels.first,
        reason: suggestion.reason,
      );
    } catch (_) {
      return _fallbackPlan(
        existingSeriesFolders: existingSeriesFolders,
        fallbackPath: fallbackPath,
        fallbackSeriesFolderName: fallbackSeriesFolderName,
      );
    }
  }

  SeriesFolderResolutionPlan _fallbackPlan({
    required List<String> existingSeriesFolders,
    required String fallbackSeriesFolderName,
    required String fallbackPath,
  }) {
    return SeriesFolderResolutionPlan(
      usedAi: false,
      seriesFolderName: fallbackSeriesFolderName,
      seasonFolderName: null,
      suggestedPath: fallbackPath,
      fallbackSeriesFolderName: fallbackSeriesFolderName,
      fallbackPath: fallbackPath,
      existingSeriesFolders: existingSeriesFolders,
      rawAiResponse: null,
      modelUsed: null,
      reason: null,
    );
  }
}

SeriesFolderAiSuggestion? parseAiSuggestion(
  String response, {
  required String fallbackSeriesFolderName,
}) {
  try {
    final jsonObject = _extractJsonObject(response);
    if (jsonObject == null) {
      return null;
    }

    final dynamic decoded = json.decode(jsonObject);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final seriesName =
        (decoded['series_name'] ?? decoded['seriesName'] ?? '')
            .toString()
            .trim();
    final reason = (decoded['reason'] ?? '').toString().trim();
    final matchedExistingFolder =
        decoded['matched_existing_folder'] == true ||
        decoded['matchedExistingFolder'] == true;

    return SeriesFolderAiSuggestion(
      seriesName: seriesName.isEmpty ? fallbackSeriesFolderName : seriesName,
      seasonFolder: normalizeAiSeasonFolder(
        (decoded['season_folder'] ?? decoded['seasonFolder'] ?? '')
            .toString()
            .trim(),
      ),
      matchedExistingFolder: matchedExistingFolder,
      reason: reason.isEmpty ? null : reason,
    );
  } catch (_) {
    return null;
  }
}

String buildPath({
  required String basePath,
  required String seriesFolderName,
  String? seasonFolderName,
}) {
  if (seasonFolderName == null || seasonFolderName.isEmpty) {
    return p.join(basePath, seriesFolderName);
  }

  return p.join(basePath, seriesFolderName, seasonFolderName);
}

String sanitizeFolderSegment(String input) {
  final sanitized =
      input
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]+'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  return sanitized.isEmpty ? 'Unknown Series' : sanitized;
}

String normalizeAiSeasonFolder(String input) {
  final normalized = _normalizeSeasonNumber(input);
  if (normalized != null) {
    return normalized;
  }

  if (input.trim().isEmpty) {
    return 'Season 01';
  }

  return sanitizeFolderSegment(input);
}

String? normalizeUserSeasonFolder(String? input) {
  if (input == null || input.trim().isEmpty) {
    return null;
  }

  final normalized = _normalizeSeasonNumber(input);
  if (normalized != null) {
    return normalized;
  }

  return sanitizeFolderSegment(input);
}

String? _normalizeSeasonNumber(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final patterns = <RegExp>[
    RegExp(r'^season\s*(\d+)$', caseSensitive: false),
    RegExp(r'^s(\d+)$', caseSensitive: false),
    RegExp(r'^part\s*(\d+)$', caseSensitive: false),
    RegExp(r'^(\d+)$'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(trimmed);
    if (match != null) {
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > 0) {
        return 'Season ${value.toString().padLeft(2, '0')}';
      }
    }
  }

  return null;
}

String? _extractJsonObject(String response) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(response);
  return match?.group(0);
}
