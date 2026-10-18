import 'package:flutter/foundation.dart';

abstract final class ConfigValidator {
  static String? validateApiBase({
    String? apiBase,
    bool isRelease = kReleaseMode,
  }) {
    if (!isRelease) return null;

    final url = (apiBase ?? const String.fromEnvironment('API_BASE', defaultValue: '')).trim();
    if (url.isEmpty) {
      return 'API_BASE configuration is missing.\n\n'
          'Release builds require an HTTPS backend URL to connect to the transit routing engine.\n\n'
          'Example:\n--dart-define=API_BASE=https://api.marg.in/api/v1';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      return 'Insecure or invalid API_BASE: "$url".\n\n'
          'Release builds strictly require an HTTPS URL. Cleartext HTTP is forbidden in production.\n\n'
          'Example:\n--dart-define=API_BASE=https://api.marg.in/api/v1';
    }

    return null;
  }
}
