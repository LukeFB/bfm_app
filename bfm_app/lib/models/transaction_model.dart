/// ---------------------------------------------------------------------------
/// File: transaction_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Represents a single financial transaction as stored by the app.
///   This model bridges the raw bank/aggregation payload (Akahu) and the
///   local DB row used throughout the UI.
///
/// Design notes:
///   - Models are intentionally thin: they hold data + small, stateless helpers.
///   - Business logic / aggregations (budgets, recurring detection) should
///     remain in service/repository layers to keep models testable and pure.
///   - We provide `fromAkahu` to translate Akahu's enriched JSON into our model.
///     This makes ingestion deterministic and centralised.
///   - `toDbMap()` returns only the keys currently present in our `transactions`
///     table. If you extend the table (e.g. to store `akahu_id`), add keys there.
///
/// Fields mapping (DB):
///   id           -> id
///   category_id  -> categoryId
///   amount       -> amount
///   description  -> description
///   date         -> date (YYYY-MM-DD)
///   type         -> type ('income'|'expense')
///
/// Caveats:
///   - Akahu returns types like "DEBIT", "CREDIT", "EFTPOS", etc. We map those
///     to our simplified 'income' / 'expense' domain via `mapAkahuTypeToLocal`.
/// ---------------------------------------------------------------------------

import 'dart:convert';

class TransactionModel {
  final int? id;

  // Optional Akahu metadata: keep to allow reconciliation and debugging.
  // These fields are not required by our current DB schema but are useful.
  final String? akahuId; // e.g. "trans_456..."
  final String? accountId;
  final String? connectionId;

  // Core fields mapped to local DB column names
  final int? categoryId;
  final double amount;
  final String description;
  final String date; // YYYY-MM-DD (we keep string to match current DB usage)
  final String type; // expected values: 'income' or 'expense'
  final String? categoryName;

  // Optional enrichment
  final double? balance; // if provided by Akahu
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
      balance: map['balance'] is num ? (map['balance'] as num).toDouble() : null,
      merchantName: map['merchant_name'] as String?,
      merchantWebsite: map['merchant_website'] as String?,
      logo: map['logo'] as String?,
      meta: map['meta'] != null
          ? (map['meta'] is String ? json.decode(map['meta'] as String) as Map<String, dynamic> : (map['meta'] as Map<String, dynamic>))
          : null,
    );
  }

  /// Convert model to a Map suitable for inserting/updating the DB table.
  ///
  /// NOTE: this returns the *core* keys expected by the current transactions
  /// table. If you add extra columns to the schema (e.g. akahu_id, merchant_name),
  /// include them here.
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
    // Include Akahu metadata in DB map if available
    if (akahuId != null) m['akahu_id'] = akahuId;
    if (accountId != null) m['account_id'] = accountId;
    if (connectionId != null) m['connection_id'] = connectionId;
    if (merchantName != null) m['merchant_name'] = merchantName;
    return m;
  }

  /// Convert to an enriched map that includes Akahu metadata.
  ///
  /// This is useful if you expand the DB to keep reconciliation columns.
  Map<String, dynamic> toEnrichedMap() {
    return {
      'akahu_id': akahuId,
      'account_id': accountId,
      'connection_id': connectionId,
      'category_id': categoryId,
      'amount': amount,
      'description': description,
      'date': date,
      'type': type,
      'balance': balance,
      'merchant_name': merchantName,
      'merchant_website': merchantWebsite,
      'logo': logo,
      'meta': meta == null ? null : json.encode(meta),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Build a TransactionModel from raw Akahu JSON (the enrichment format).
  ///
  /// This centralises the translation logic. We:
  ///  - safely read optional fields,
  ///  - normalise Akahu's transaction `type` to our local 'income'/'expense',
  ///  - extract merchant/category metadata when available.
  ///
  /// Example:
  ///   final t = TransactionModel.fromAkahu(akahuJson);
  factory TransactionModel.fromAkahu(Map<String, dynamic> a) {
    String akahuType = (a['type'] ?? '') as String;
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
    String localType;
    final amt = (a['amount'] as num).toDouble();

    // Prefer amount sign over type guess
    if (amt < 0) {
      localType = 'expense';
    } else if (amt > 0) {
      localType = 'income';
    } else {
      // fallback: if 0, try type
      localType = TransactionModel.mapAkahuTypeToLocal(akahuType);
    }

    final merchant = a['merchant'] as Map<String, dynamic>?;

    final categoryObj = a['category'] as Map<String, dynamic>?;
    String? akahuCategoryId;
    String? catName;
    if (categoryObj != null) {
      akahuCategoryId = (categoryObj['_id'] ?? categoryObj['id']) as String?;
      catName = categoryObj['name'] as String?;
    }

    return TransactionModel(
      akahuId: a['_id'] as String?,
      accountId: a['_account'] as String?,
      connectionId: a['_connection'] as String?,
      categoryId: null, // category mapping should be resolved by an enrichment step
      categoryName: catName,
      amount: (a['amount'] as num).toDouble(),
      description: (a['description'] ?? '') as String,
      date: isoDay,
      type: localType,
      balance: a['balance'] is num ? (a['balance'] as num).toDouble() : null,
      merchantName: merchant == null ? null : (merchant['name'] as String?),
      merchantWebsite:
          merchant == null ? null : (merchant['website'] as String?),
      logo: a['meta'] is Map && (a['meta'] as Map).containsKey('logo')
          ? (a['meta']['logo'] as String?)
          : null,
      meta: a['meta'] is Map ? Map<String, dynamic>.from(a['meta'] as Map) : null,
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

  /// Map Akahu's many granular types into our simplified domain of
  /// 'expense' / 'income'. This is conservative and should be extended
  /// as you discover edge cases.
  static String mapAkahuTypeToLocal(String akahuType) {
    final t = akahuType.toUpperCase();
    const expenseTypes = <String>{
      'DEBIT',
      'PAYMENT',
      'TRANSFER', // often internal, but treat as expense unless CREDIT
      'STANDING ORDER',
      'EFTPOS',
      'DIRECT DEBIT',
      'CREDIT CARD',
      'ATM',
      'LOAN',
      'FEE',
      'TAX',
    };
    const incomeTypes = <String>{
      'CREDIT',
      'DIRECT CREDIT',
      'INTEREST',
    };
    if (expenseTypes.contains(t)) return 'expense';
    if (incomeTypes.contains(t)) return 'income';
    // fallback: treat numeric-negative amounts or 'DEBIT' as expense
    return t.contains('DEBIT') ? 'expense' : 'income';
  }
}
