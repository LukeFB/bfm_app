/// ---------------------------------------------------------------------------
/// File: transaction_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents a single financial transaction
///   This model bridges the raw bank/aggregation payload 
///   from Akahu and the local DB 
///   
/// Design notes:
///   - We provide `fromAkahu` to translate Akahu's enriched JSON into our model.
///     This makes ingestion deterministic and centralised.
///   - `toDbMap()` returns only the keys currently present in our transactions table
///
/// ---------------------------------------------------------------------------

import 'dart:convert';

class TransactionModel {
  final int? id;

  // Optional Akahu metadata for debugging.
  // These fields are not required by our current DB schema
  final String? akahuId;
  final String? accountId;
  final String? connectionId;

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

  const TransactionModel({
    this.id,
    this.akahuId,
    this.accountId,
    this.connectionId,
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
  });

  /// Convert from a DB row (Map) to model.
  /// Expects snake_case keys produced by sqflite.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      akahuId: (map['akahu_id'] as String?) ?? (map['_id'] as String?), // tolerate variants
      accountId: map['account_id'] as String?,
      connectionId: map['connection_id'] as String?,
      categoryId: map['category_id'] is int ? map['category_id'] as int : (map['category_id'] as int?),
      categoryName: map['category_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: (map['description'] ?? '') as String,
      date: (map['date'] as String),
      type: (map['type'] as String),
      merchantName: map['merchant_name'] as String?,
    );
  }

  /// Convert model to a Map suitable for inserting/updating the DB table.
  Map<String, dynamic> toDbMap({bool includeId = false}) {
    final m = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'date': date,
      'type': type,
    };
    if (includeId && id != null) m['id'] = id;
    if (categoryName != null) m['category_name'] = categoryName;
    if (akahuId != null) m['akahu_id'] = akahuId;
    if (accountId != null) m['account_id'] = accountId;
    if (connectionId != null) m['connection_id'] = connectionId;
    if (merchantName != null) m['merchant_name'] = merchantName;
    return m;
  }

  /// Build a TransactionModel from raw Akahu JSON.
  /// This centralises the translation logic. We:
  ///  - safely read optional fields,
  ///  - Assign transactions to local 'income'/'expense', (future prospect would be do dive deeper into types)
  ///  - extract merchant/category when available.
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
    }

    return TransactionModel(
      akahuId: a['_id'] as String?,
      accountId: a['_account'] as String?,
      connectionId: a['_connection'] as String?,
      categoryName: catName,
      amount: (a['amount'] as num).toDouble(),
      description: (a['description'] ?? '') as String,
      date: isoDay,
      type: localType,
      balance: a['balance'] is num ? (a['balance'] as num).toDouble() : null,
      merchantName: merchant == null ? null : (merchant['name'] as String?),
    );
  }

  // ---------------------------
  // Small, useful helpers
  // ---------------------------

  /// Returns true if this transaction should be treated as an expense.
  bool get isExpense {
    final t = type.toLowerCase();
    return t == 'expense' || t == 'debit';
  }

  /// Signed amount: negative for expenses, positive for income.
  double get signedAmount => isExpense ? -amount.abs() : amount.abs();

  /// Return a simple human-friendly amount string with currency symbol.
  String formattedAmount({int decimals = 2}) =>
      '\$${amount.toStringAsFixed(decimals)}';
}
