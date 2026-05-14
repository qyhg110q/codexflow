import 'package:flutter/services.dart';

class NativePlatformBridge {
  static const _channel = MethodChannel('codexflow/platform');
  static const fallbackAppVersion = String.fromEnvironment(
    'CODEXFLOW_APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  static Future<String> appVersion() async {
    try {
      final result = await _channel.invokeMethod<String>('getAppVersion');
      final trimmed = result?.trim() ?? '';
      return trimmed.isEmpty ? fallbackAppVersion : trimmed;
    } catch (_) {
      return fallbackAppVersion;
    }
  }

  static Future<bool> openExternalUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>(
            'openExternalUrl',
            <String, String>{'url': url},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
