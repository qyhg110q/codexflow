import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:codexflow_flutter/services/github_release_client.dart';

void main() {
  test('parses latest GitHub release and resolves APK asset', () async {
    final client = GitHubReleaseClient(
      client: MockClient((http.Request request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/qyhg110q/codexflow/releases/latest',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'tag_name': 'v0.2.0',
            'name': 'CodexFlow v0.2.0',
            'body': '- Fixes\n- Improvements',
            'html_url':
                'https://github.com/qyhg110q/codexflow/releases/tag/v0.2.0',
            'published_at': '2026-05-14T12:00:00Z',
            'assets': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'codexflow-android-v0.2.0.apk',
                'content_type': 'application/vnd.android.package-archive',
                'browser_download_url':
                    'https://github.com/qyhg110q/codexflow/releases/download/v0.2.0/codexflow-android-v0.2.0.apk',
                'size': 123,
              },
            ],
          }),
          200,
        );
      }),
    );

    final release = await client.latestRelease();
    expect(release.versionLabel, '0.2.0');
    expect(release.apkAsset?.name, 'codexflow-android-v0.2.0.apk');
    expect(
      release.apkAsset?.downloadUrl,
      'https://github.com/qyhg110q/codexflow/releases/download/v0.2.0/codexflow-android-v0.2.0.apk',
    );
  });
}
