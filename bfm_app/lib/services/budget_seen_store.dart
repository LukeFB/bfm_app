/// ---------------------------------------------------------------------------
/// File: lib/services/budget_seen_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Tracks which subscriptions, budgets, and uncategorized items the user has
///   "seen" in the budget screen, along with their amounts. This enables showing
///   alerts only for:
///   - Truly new items (never seen before)
///   - Existing items with significant amount changes (>10%)
///
/// Called by:
///   - budgets_screen.dart
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which budget items the user has seen and their amounts.
class BudgetSeenStore {
  static const _keySeenSubscriptions = 'budget_seen_subscriptions';
  static const _keySeenSubscriptionAmounts = 'budget_seen_subscription_amounts';
  static const _keySeenCategories = 'budget_seen_categories';
  static const _keySeenCategoryAmounts = 'budget_seen_category_amounts';
  static const _keySeenUncatKeys = 'budget_seen_uncat_keys';
  static const _keySeenUncatAmounts = 'budget_seen_uncat_amounts';

  /// Loads the set of seen subscription (recurring) IDs.
  static Future<Set<int>> getSeenSubscriptionIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySeenSubscriptions) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toSet();
  }

  /// Loads the map of subscription ID -> last seen amount.
  static Future<Map<int, double>> getSeenSubscriptionAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySeenSubscriptionAmounts);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
        int.tryParse(k) ?? 0,
        (v as num?)?.toDouble() ?? 0.0,
      ))..removeWhere((k, v) => k == 0);
    } catch (_) {
      return {};
    }
  }

  /// Saves the set of seen subscription IDs.
  static Future<void> setSeenSubscriptionIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keySeenSubscriptions,
      ids.map((id) => id.toString()).toList(),
    );
  }

  /// Saves the map of subscription ID -> amount.
  static Future<void> setSeenSubscriptionAmounts(Map<int, double> amounts) async {
    final prefs = await SharedPreferences.getInstance();
    final map = amounts.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString(_keySeenSubscriptionAmounts, jsonEncode(map));
  }

  /// Loads the set of seen category IDs.
  static Future<Set<int>> getSeenCategoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySeenCategories) ?? [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toSet();
  }

  /// Loads the map of category ID -> last seen amount.
  static Future<Map<int, double>> getSeenCategoryAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySeenCategoryAmounts);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
        int.tryParse(k) ?? 0,
        (v as num?)?.toDouble() ?? 0.0,
      ))..removeWhere((k, v) => k == 0);
    } catch (_) {
      return {};
    }
  }

  /// Saves the set of seen category IDs.
  static Future<void> setSeenCategoryIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keySeenCategories,
      ids.map((id) => id.toString()).toList(),
    );
  }

  /// Saves the map of category ID -> amount.
  static Future<void> setSeenCategoryAmounts(Map<int, double> amounts) async {
    final prefs = await SharedPreferences.getInstance();
    final map = amounts.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString(_keySeenCategoryAmounts, jsonEncode(map));
  }

  /// Loads the set of seen uncategorized keys.
  static Future<Set<String>> getSeenUncatKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySeenUncatKeys) ?? [];
    return list.toSet();
  }

  /// Loads the map of uncategorized key -> last seen amount.
  static Future<Map<String, double>> getSeenUncatAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keySeenUncatAmounts);
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
    } catch (_) {
      return {};
    }
  }

  /// Saves the set of seen uncategorized keys.
  static Future<void> setSeenUncatKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySeenUncatKeys, keys.toList());
  }

  /// Saves the map of uncategorized key -> amount.
  static Future<void> setSeenUncatAmounts(Map<String, double> amounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySeenUncatAmounts, jsonEncode(amounts));
  }

  /// Marks a subscription as seen with its current amount.
  static Future<void> markSubscriptionSeen(int id, double amount) async {
    final ids = await getSeenSubscriptionIds();
    final amounts = await getSeenSubscriptionAmounts();
    ids.add(id);
    amounts[id] = amount;
    await setSeenSubscriptionIds(ids);
    await setSeenSubscriptionAmounts(amounts);
  }

  /// Marks a category as seen with its current amount.
  static Future<void> markCategorySeen(int id, double amount) async {
    final ids = await getSeenCategoryIds();
    final amounts = await getSeenCategoryAmounts();
    ids.add(id);
    amounts[id] = amount;
    await setSeenCategoryIds(ids);
    await setSeenCategoryAmounts(amounts);
  }

  /// Marks an uncategorized item as seen with its current amount.
  static Future<void> markUncatSeen(String key, double amount) async {
    final keys = await getSeenUncatKeys();
    final amounts = await getSeenUncatAmounts();
    keys.add(key);
    amounts[key] = amount;
    await setSeenUncatKeys(keys);
    await setSeenUncatAmounts(amounts);
  }

  /// Marks all current subscriptions as seen with their amounts.
  static Future<void> markAllSubscriptionsSeen(Map<int, double> currentAmounts) async {
    final ids = await getSeenSubscriptionIds();
    final amounts = await getSeenSubscriptionAmounts();
    for (final entry in currentAmounts.entries) {
      ids.add(entry.key);
      amounts[entry.key] = entry.value;
    }
    await setSeenSubscriptionIds(ids);
    await setSeenSubscriptionAmounts(amounts);
  }

  /// Marks all current categories as seen with their amounts.
  static Future<void> markAllCategoriesSeen(Map<int, double> currentAmounts) async {
    final ids = await getSeenCategoryIds();
    final amounts = await getSeenCategoryAmounts();
    for (final entry in currentAmounts.entries) {
      ids.add(entry.key);
      amounts[entry.key] = entry.value;
    }
    await setSeenCategoryIds(ids);
    await setSeenCategoryAmounts(amounts);
  }

  /// Marks all current uncategorized items as seen with their amounts.
  static Future<void> markAllUncatSeen(Map<String, double> currentAmounts) async {
    final keys = await getSeenUncatKeys();
    final amounts = await getSeenUncatAmounts();
    for (final entry in currentAmounts.entries) {
      keys.add(entry.key);
      amounts[entry.key] = entry.value;
    }
    await setSeenUncatKeys(keys);
    await setSeenUncatAmounts(amounts);
  }

  /// Clears all seen data (useful for testing or reset).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySeenSubscriptions);
    await prefs.remove(_keySeenSubscriptionAmounts);
    await prefs.remove(_keySeenCategories);
    await prefs.remove(_keySeenCategoryAmounts);
    await prefs.remove(_keySeenUncatKeys);
    await prefs.remove(_keySeenUncatAmounts);
  }
}
