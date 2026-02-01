/// ---------------------------------------------------------------------------
/// File: lib/services/manual_budget_store.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Persists manually created budgets separately from the budgets table.
///   This allows manual budgets to be remembered even when unselected.
///
/// Called by:
///   - budgets_screen.dart
/// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a manually created budget item.
class ManualBudget {
  final String name;
  final double weeklyLimit;
  final bool isSelected;

  const ManualBudget({
    required this.name,
    required this.weeklyLimit,
    this.isSelected = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'weeklyLimit': weeklyLimit,
    'isSelected': isSelected,
  };

  factory ManualBudget.fromJson(Map<String, dynamic> json) => ManualBudget(
    name: json['name'] as String? ?? '',
    weeklyLimit: (json['weeklyLimit'] as num?)?.toDouble() ?? 0.0,
    isSelected: json['isSelected'] as bool? ?? true,
  );

  ManualBudget copyWith({String? name, double? weeklyLimit, bool? isSelected}) {
    return ManualBudget(
      name: name ?? this.name,
      weeklyLimit: weeklyLimit ?? this.weeklyLimit,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Persists manually created budgets.
class ManualBudgetStore {
  static const _keyManualBudgets = 'manual_budgets_v1';

  /// Loads all manual budgets.
  static Future<List<ManualBudget>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyManualBudgets);
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((item) => ManualBudget.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves all manual budgets.
  static Future<void> saveAll(List<ManualBudget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(budgets.map((b) => b.toJson()).toList());
    await prefs.setString(_keyManualBudgets, json);
  }

  /// Clears all manual budgets.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyManualBudgets);
  }

  /// Adds a single manual budget to the store.
  /// Inserts at the beginning of the list and marks as selected.
  static Future<void> add(ManualBudget budget) async {
    final existing = await getAll();
    // Insert at beginning
    final updated = [budget, ...existing];
    await saveAll(updated);
  }
}
