/// ---------------------------------------------------------------------------
/// File: lib/config/backend_config.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `content_sync_service.dart` + every other HTTP-oriented service before
///     constructing backend requests.
///
/// Purpose:
///   - Centralises how we determine the backend base host per environment so
///     services do not duplicate emulator/desktop/web branching.
///
/// Inputs:
///   - `BFM_BACKEND_URL` compile-time define and `defaultTargetPlatform`.
///
/// Outputs:
///   - Host strings, request timeouts, and helper URI builders shared across
///     every API client.
///
/// Notes:
///   - Treat this as the single source of truth for backend host tweaks so
///     dev/prod toggles stay consistent across services.
/// ---------------------------------------------------------------------------
import 'package:flutter/foundation.dart';

/// Holds static helpers for building backend URLs that work across devices,
/// emulators, and web.
class BackendConfig {
  static const String _envUrl = String.fromEnvironment('BFM_BACKEND_URL');

  /// Chooses the best base URL by:
  ///   1. Trusting the compile-time env override if present.
  ///   2. Using Android emulator loopback when running on an Android device.
  ///   3. Falling back to localhost for everything else (web/desktop/iOS).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }
    return 'http://localhost:4000';
  }

  /// Builds a full Uri by merging:
  ///   - the base host
  ///   - cleaned path segments from the provided `path`
  ///   - any optional query parameters
  /// Ensures there are no duplicate or empty "/" segments before returning.
  static Uri buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      ...cleanPath.split('/').where((segment) => segment.isNotEmpty),
    ];
    return base.replace(pathSegments: segments, queryParameters: query);
  }

  /// Default HTTP timeout shared by every backend call so retries stay sane.
  static const Duration requestTimeout = Duration(seconds: 8);
}
