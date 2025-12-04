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

class ContentSyncService {
  ContentSyncService._internal();
  static final ContentSyncService _instance = ContentSyncService._internal();
  factory ContentSyncService() => _instance;

  final http.Client _client = http.Client();

  Future<void> syncDashboardContent() async {
    await Future.wait([syncReferrals(), syncTips(), syncEvents()]);
  }

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

  void dispose() {
    _client.close();
  }

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

  void _log(String message, [Object? error]) {
    debugPrint('[ContentSync] $message');
    if (error != null) {
      debugPrint(error.toString());
    }
  }
}
