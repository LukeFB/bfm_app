import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String _envUrl = String.fromEnvironment('BFM_BACKEND_URL');

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://localhost:4000';
  }

  static Uri buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      ...cleanPath.split('/').where((segment) => segment.isNotEmpty),
    ];
    return base.replace(pathSegments: segments, queryParameters: query);
  }

  static const Duration requestTimeout = Duration(seconds: 8);
}
