import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'api_client.dart';

class GitHubReleaseClient {
  GitHubReleaseClient({
    http.Client? client,
    this.repository = 'qyhg110q/codexflow',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String repository;

  Future<AppReleaseInfo> latestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$repository/releases/latest',
    );
    final response = await _client.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'CodexFlow-App',
      },
    );

    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
      } catch (_) {
        payload = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (payload is Map && payload['message'] != null) {
        throw ApiError(payload['message'].toString());
      }
      throw ApiError(
        'GitHub release request failed with status ${response.statusCode}',
      );
    }

    if (payload is Map<String, dynamic>) {
      return AppReleaseInfo.fromJson(payload);
    }
    if (payload is Map) {
      final map = payload.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      return AppReleaseInfo.fromJson(map);
    }

    throw ApiError('GitHub returned an invalid release response.');
  }
}
