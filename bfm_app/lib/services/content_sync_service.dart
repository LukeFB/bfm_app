/// ---------------------------------------------------------------------------
/// File: lib/services/content_sync_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Pulls dashboard copy (referrals, tips, events) from the backend and
///   mirrors it into SQLite so the UI works offline.
///
/// Called by:
///   `dashboard_screen.dart` whenever the user refreshes dashboard content.
///
/// Inputs / Outputs:
///   Hits the backend REST endpoints using `BackendConfig`, maps JSON into
///   models, and pushes them into their repositories using replace semantics.
/// ---------------------------------------------------------------------------
import 'dart:convert';

import 'package:bfm_app/config/backend_config.dart';
import 'package:bfm_app/models/event_model.dart';
import 'package:bfm_app/models/referral_model.dart';
import 'package:bfm_app/models/tip_model.dart';
import 'package:bfm_app/repositories/event_repository.dart';
import 'package:bfm_app/repositories/referral_repository.dart';
import 'package:bfm_app/repositories/tip_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Small singleton because we only need one HTTP client instance + state.
///
/// TODO: Once backend auth is the primary flow, replace these direct HTTP calls
/// with ContentApi (lib/api/content_api.dart) which includes the Bearer token
/// and goes through the authenticated Moni backend. Keep this for unauthenticated
/// fallback or local dev.
class ContentSyncService {
  ContentSyncService._internal();
  static final ContentSyncService _instance = ContentSyncService._internal();
  factory ContentSyncService() => _instance;

  final http.Client _client = http.Client();

  /// Fan-out helper used by the dashboard to refresh everything at once.
  /// Runs referral, tip, and event sync in parallel.
  Future<void> syncDashboardContent() async {
    await Future.wait([syncReferrals(), syncTips(), syncEvents()]);
  }

  /// Fetches referral JSON, maps to `ReferralModel`, and replaces the local
  /// table with the new list. Swallows errors but logs them for debugging.
  Future<void> syncReferrals() async {
    try {
      final list = await _fetchList('/api/referrals', {'limit': '200'});
      final models = list
          .whereType<Map<String, dynamic>>()
          .map(_mapReferral)
          .whereType<ReferralModel>()
          .toList();
      if (models.isNotEmpty) {
        await ReferralRepository.replaceWithBackend(models);
      }
    } catch (err, stack) {
      _log('referral sync failed: $err', stack);
    }
  }

  /// Same as `syncReferrals` but for the rotating financial tips.
  Future<void> syncTips() async {
    try {
      final list = await _fetchList('/api/tips', {'limit': '3'});
      final models = list
          .whereType<Map<String, dynamic>>()
          .map(_mapTip)
          .whereType<TipModel>()
          .toList();
      if (models.isNotEmpty) {
        await TipRepository.replaceWithBackend(models);
      }
    } catch (err, stack) {
      _log('tip sync failed: $err', stack);
    }
  }

  /// Same idea for live events/clinics. Keeps only the most recent items.
  Future<void> syncEvents() async {
    try {
      final list = await _fetchList('/api/events', {'limit': '5'});
      final models = list
          .whereType<Map<String, dynamic>>()
          .map(_mapEvent)
          .whereType<EventModel>()
          .toList();
      if (models.isNotEmpty) {
        await EventRepository.replaceWithBackend(models);
      }
    } catch (err, stack) {
      _log('event sync failed: $err', stack);
    }
  }

  /// Close the underlying HTTP client when the app shuts down or tests finish.
  void dispose() {
    _client.close();
  }

  /// Shared HTTP helper:
  /// - Builds the absolute URI with query params.
  /// - Applies a timeout using our backend config.
  /// - Ensures the payload is a JSON list before returning.
  Future<List<dynamic>> _fetchList(
    String path,
    Map<String, String> query,
  ) async {
    final uri = BackendConfig.buildUri(path, query);
    final response = await _client
        .get(uri)
        .timeout(BackendConfig.requestTimeout);

    if (response.statusCode >= 400) {
      throw Exception('Request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected payload for $path');
  }

  /// Maps referral JSON into our `ReferralModel`, converting timestamps and
  /// falling back to sensible defaults for optional fields.
  ReferralModel? _mapReferral(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return ReferralModel(
      backendId: (data['id'] as num?)?.toInt(),
      organisationName: data['organisationName'] as String?,
      category: data['category'] as String?,
      website: data['website'] as String?,
      phone: data['phone'] as String?,
      services: data['services'] as String?,
      demographics: data['demographics'] as String?,
      availability: data['availability'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      region: data['region'] as String?,
      notes: data['notes'] as String?,
      isActive: data['isActive'] != false,
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Converts a tip payload into `TipModel`, giving it a title fallback and
  /// parsing expiry/updated timestamps.
  TipModel? _mapTip(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    final title = data['title'] as String? ?? 'Financial Tip';
    return TipModel(
      backendId: (data['id'] as num?)?.toInt(),
      title: title,
      expiresAt: parseDate(data['expiresAt']),
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Converts event payloads into `EventModel`, capturing backend ids and
  /// guarding against bad timestamps.
  EventModel? _mapEvent(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return EventModel(
      backendId: (data['id'] as num?)?.toInt(),
      title: data['title'] as String? ?? 'Upcoming event',
      endDate: parseDate(data['endDate']),
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Lightweight logger so we can keep release builds quiet but still get
  /// breadcrumbs in debug runs.
  void _log(String message, [Object? error]) {
    debugPrint('[ContentSync] $message');
    if (error != null) {
      debugPrint(error.toString());
    }
  }
}
