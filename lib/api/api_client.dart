// lib/api/subsplease_api.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

import '../models/show_models.dart'; // your ShowInfo, ShowDownloadInfo, etc.

class SubsPleaseApi {
  static const String _baseUrl = 'https://subsplease.org';
  String get baseUrl => _baseUrl;

  final http.Client _httpClient;

  SubsPleaseApi({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// GET https://subsplease.org/api/?f=latest&tz=Pacific/Auckland
  Future<List<ShowInfo>> getLatestShowList() async {
    final Uri url = Uri.parse('$_baseUrl/api/?f=latest&tz=Pacific/Auckland');
    try {
      final http.Response response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> raw = json.decode(response.body) as Map<String, dynamic>;
        final List<ShowInfo> shows = raw.values.map((dynamic entry) => ShowInfo.fromJson(entry as Map<String, dynamic>)).toList();
        debugPrint('Retrieved subsplease shows (${shows.length})');
        return shows;
      } else {
        debugPrint('Error fetching latest shows: ${response.statusCode} ${response.reasonPhrase}');
        return <ShowInfo>[];
      }
    } catch (error) {
      debugPrint('Error fetching latest shows: $error');
      return <ShowInfo>[];
    }
  }

  /// POST https://subsplease.org/api/?f=search&tz=Pacific/Auckland&s=<encoded>
  Future<List<ShowInfo>> getShowsFromSearch(String searchTerm) async {
    final String encodedTerm = Uri.encodeComponent(searchTerm);
    final Uri url = Uri.parse('$_baseUrl/api/?f=search&tz=Pacific/Auckland&s=$encodedTerm');
    try {
      final http.Response response = await _httpClient.post(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> raw = json.decode(response.body) as Map<String, dynamic>;
        final List<ShowInfo> shows = raw.values.map((dynamic entry) => ShowInfo.fromJson(entry as Map<String, dynamic>)).toList();
        return shows;
      } else {
        debugPrint('Error searching shows: ${response.statusCode} ${response.reasonPhrase}');
        return <ShowInfo>[];
      }
    } catch (error) {
      debugPrint('Error searching shows: $error');
      return <ShowInfo>[];
    }
  }

  /// GET https://subsplease.org/shows/{showPage} → parse synopsis from HTML
  Future<String?> getShowSynopsis(String showPage) async {
    final Uri url = Uri.parse('$_baseUrl/shows/$showPage');
    try {
      final http.Response response = await _httpClient.get(url);

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final synopsisElement = document.querySelector('.series-syn p');
        return synopsisElement?.text.trim();
      } else {
        debugPrint('Error fetching synopsis: ${response.statusCode} ${response.reasonPhrase}');
        return null;
      }
    } catch (error) {
      debugPrint('Error fetching synopsis: $error');
      return null;
    }
  }
}
