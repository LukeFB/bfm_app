/// ---------------------------------------------------------------------------
/// File: lib/models/transaction_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Canonical representation of a user transaction inside the app.
///   Bridges Akahu payloads, SQLite rows, and UI-friendly helpers.
///
/// Called by:
///   `transaction_repository.dart`, `budget_analysis_service.dart`,
///   dashboards, insights, and transaction/goal screens that need typed data.
///
/// Inputs / Outputs:
///   - `fromAkahu` ingests raw API JSON.
///   - `fromMap` / `toDbMap` translate to SQLite.
///   - Helper getters provide derived values for UI.
/// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Immutable transaction domain object.
/// Gives every consumer the same names, types, and helper methods.
class TransactionModel {
  final int? id;

  // Optional Akahu metadata for debugging.
  // These fields are not required by our current DB schema
  final String? akahuId;
  final String? accountId;
  final String? connectionId;
  final String? akahuHash;

  // Core fields mapped to local DB column names
  final int? categoryId;
  final double amount;
  final String description;
  final String date; // YYYY-MM-DD (we keep string to match current DB usage)
  final String type; // expected values: 'income' or 'expense'
  final String? categoryName; // Essential if present uncategorized if not

  // Optional enrichment
  final double? balance;
  final String? merchantName;
  final String? merchantWebsite;
  final String? logo;
  final Map<String, dynamic>? meta; // raw metadata object from Akahu

  /// When true this transaction should be ignored by spend/budget calculations.
  final bool excluded;

  const TransactionModel({
    this.id,
    this.akahuId,
    this.accountId,
    this.connectionId,
    this.akahuHash,
    this.categoryId,
    this.categoryName,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    this.balance,
    this.merchantName,
    this.merchantWebsite,
    this.logo,
    this.meta,
    this.excluded = false,
  });

  /// Rehydrates a transaction from SQLite (snake_case keys expected).
  /// Handles nullable ints and alternate `_id` columns so migrations stay easy.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      akahuId: (map['akahu_id'] as String?) ?? (map['_id'] as String?), // tolerate variants
      accountId: map['account_id'] as String?,
      connectionId: map['connection_id'] as String?,
      akahuHash: map['akahu_hash'] as String?,
      categoryId: map['category_id'] is int ? map['category_id'] as int : (map['category_id'] as int?),
      categoryName: map['category_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: (map['description'] ?? '') as String,
      date: (map['date'] as String),
      type: (map['type'] as String),
      merchantName: map['merchant_name'] as String?,
      excluded: _boolFromDb(map['excluded']),
    );
  }

  /// Serialises the model back into a map for inserts/updates.
  /// Only writes populated optional fields so legacy columns stay untouched.
  Map<String, dynamic> toDbMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'date': date,
      'type': type,
      'excluded': excluded ? 1 : 0,
    };
    if (includeId && id != null) m['id'] = id;
    if (categoryName != null) m['category_name'] = categoryName;
    if (akahuId != null) m['akahu_id'] = akahuId;
    if (accountId != null) m['account_id'] = accountId;
    if (connectionId != null) m['connection_id'] = connectionId;
    if (akahuHash != null) m['akahu_hash'] = akahuHash;
    if (merchantName != null) m['merchant_name'] = merchantName;
    return m;
  }

  /// Converts raw Akahu JSON into our local format.
  /// - Normalises dates to YYYY-MM-DD.
  /// - Derives local type based on amount sign (safer than Akahu type alone).
  /// - Pulls category + merchant metadata when available.
  /// - Generates a deterministic hash when Akahu doesn't send one.
  factory TransactionModel.fromAkahu(Map<String, dynamic> a) {
    // Keep the bank-provided date but normalise to 'YYYY-MM-DD' if possible.
    String dt = (a['date'] ?? a['created_at'] ?? '').toString();
    if (dt.isEmpty) dt = DateTime.now().toIso8601String();
    String isoDay;
    try {
      final parsed = DateTime.parse(dt);
      isoDay =
          "${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
    } catch (_) {
      isoDay = dt.split('T').first; // best-effort
    }

    // Map akahu type to local domain
    String localType = 'income'; // default
    final amt = (a['amount'] as num).toDouble();

    // Prefer amount sign over type field for now TODO:
    if (amt < 0) {
      localType = 'expense';
    }

    final merchant = a['merchant'] as Map<String, dynamic>?;

    final categoryObj = a['category'] as Map<String, dynamic>?;
    String? catName;
    if (categoryObj != null) {
      catName = categoryObj['name'] as String?;
    } else {
      final groups = a['groups'] as Map<String, dynamic>?;
      if (groups != null && groups['personal_finance'] is Map<String, dynamic>) {
        catName =
            (groups['personal_finance'] as Map<String, dynamic>)['name'] as String?;
      }
    }
    if (catName == null || catName.trim().isEmpty) {
      catName = null;
    }

    final akahuHash = _resolveHash(a);

    return TransactionModel(
      akahuId: a['_id'] as String?,
      accountId: a['_account'] as String?,
      connectionId: a['_connection'] as String?,
      akahuHash: akahuHash,
      categoryName: catName,
      amount: (a['amount'] as num).toDouble(),
      description: (a['description'] ?? '') as String,
      date: isoDay,
      type: localType,
      balance: a['balance'] is num ? (a['balance'] as num).toDouble() : null,
      merchantName: merchant == null ? null : (merchant['name'] as String?),
      excluded: false,
    );
  }

  /// Returns the provided Akahu hash if it exists, otherwise derives one using
  /// account/date/amount/description so duplicate detection still works.
  static String _resolveHash(Map<String, dynamic> a) {
    final provided = (a['hash'] as String?)?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final account = (a['_account'] ?? '').toString();
    final date = (a['date'] ?? a['created_at'] ?? '').toString();
    final amount = (a['amount'] ?? '').toString();
    final description = (a['description'] ?? '').toString().trim().toLowerCase();
    final payload = '$account|$date|$amount|$description';
    return sha1.convert(utf8.encode(payload)).toString();
  }

  // ---------------------------
  // Small, useful helpers
  // ---------------------------

  /// True when this record should be treated as a debit/expense downstream.
  bool get isExpense {
    final t = type.toLowerCase();
    return t == 'expense' || t == 'debit';
  }

  /// Converts `amount` into a signed number that downstream charts expect.
  double get signedAmount => isExpense ? -amount.abs() : amount.abs();

  /// Formats the amount with a currency prefix for quick UI labels.
  String formattedAmount({int decimals = 2}) =>
      '\$${amount.toStringAsFixed(decimals)}';

  /// Coerces SQLite values into a bool flag.
  static bool _boolFromDb(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes';
    }
    return false;
  }
}
