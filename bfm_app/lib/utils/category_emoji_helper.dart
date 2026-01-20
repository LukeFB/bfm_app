import 'dart:async';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads NZFCC category metadata and exposes emoji helpers for budget rows.
class CategoryEmojiHelper {
  CategoryEmojiHelper._(this._categoryGroups);

  final Map<String, String> _categoryGroups;

  static CategoryEmojiHelper? _instance;

  static const String defaultEmoji = '💸';
  static const String uncategorizedEmoji = '❓';

  static const Map<String, String> _groupEmoji = {
    'Food': '🍽️',
    'Transport': '🚌',
    'Lifestyle': '🎉',
    'Appearance': '🧥',
    'Household': '🏠',
    'Professional Services': '💼',
    'Education': '📚',
    'Health': '⚕️',
    'Utilities': '⚡️',
    'Housing': '🏡',
  };

  static Future<CategoryEmojiHelper> ensureLoaded() async {
    if (_instance != null) return _instance!;

    final csvRaw = await rootBundle.loadString(
      'assets/data/nzfcc_categories.csv',
    );
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvRaw);

    final map = <String, String>{};
    for (final row in rows.skip(1)) {
      if (row.length < 3) continue;
      final name = '${row[1]}'.trim();
      final group = '${row[2]}'.trim();
      if (name.isEmpty || group.isEmpty) continue;
      map[name.toLowerCase()] = group;
    }

    _instance = CategoryEmojiHelper._(map);
    return _instance!;
  }

  String emojiForName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return defaultEmoji;
    }
    final normalized = rawName.trim().toLowerCase();
    final group = _categoryGroups[normalized];
    if (group != null) {
      return _groupEmoji[group] ?? _emojiFromText(group);
    }
    return _emojiFromText(rawName);
  }

  String _emojiFromText(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, ['grocery', 'food', 'restaurant', 'cafe'])) {
      return _groupEmoji['Food'] ?? defaultEmoji;
    }
    if (_containsAny(lower, [
      'transport',
      'fuel',
      'taxi',
      'rideshare',
      'bus',
    ])) {
      return _groupEmoji['Transport'] ?? defaultEmoji;
    }
    if (_containsAny(lower, ['rent', 'housing', 'mortgage'])) {
      return _groupEmoji['Housing'] ?? defaultEmoji;
    }
    if (_containsAny(lower, [
      'utility',
      'electric',
      'power',
      'gas',
      'internet',
      'water',
    ])) {
      return _groupEmoji['Utilities'] ?? defaultEmoji;
    }
    if (_containsAny(lower, [
      'health',
      'doctor',
      'medical',
      'pharmacy',
      'gym',
    ])) {
      return _groupEmoji['Health'] ?? defaultEmoji;
    }
    if (_containsAny(lower, ['education', 'school', 'book', 'library'])) {
      return _groupEmoji['Education'] ?? defaultEmoji;
    }
    if (_containsAny(lower, ['appearance', 'clothing', 'salon', 'hair'])) {
      return _groupEmoji['Appearance'] ?? defaultEmoji;
    }
    if (_containsAny(lower, [
      'lifestyle',
      'entertainment',
      'travel',
      'holiday',
      'hotel',
    ])) {
      return _groupEmoji['Lifestyle'] ?? defaultEmoji;
    }
    if (_containsAny(lower, ['household', 'home', 'furnish', 'garden'])) {
      return _groupEmoji['Household'] ?? defaultEmoji;
    }
    if (_containsAny(lower, ['professional', 'services', 'tax', 'legal'])) {
      return _groupEmoji['Professional Services'] ?? defaultEmoji;
    }
    return defaultEmoji;
  }

  static bool _containsAny(String input, List<String> needles) =>
      needles.any(input.contains);
}
