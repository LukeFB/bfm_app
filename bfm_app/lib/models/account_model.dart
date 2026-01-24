/// ---------------------------------------------------------------------------
/// File: lib/models/account_model.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Canonical representation of a connected bank account from Akahu.
///   Bridges Akahu payloads, SQLite rows, and UI display.
///
/// Called by:
///   `account_repository.dart`, `savings_service.dart`, `savings_screen.dart`
///
/// Inputs / Outputs:
///   - `fromAkahu` ingests raw API JSON.
///   - `fromMap` / `toDbMap` translate to SQLite.
///   - Helper getters provide derived values for UI.
/// ---------------------------------------------------------------------------

/// Represents the type of bank account.
enum AccountType {
  checking,
  savings,
  creditCard,
  kiwiSaver,
  investment,
  loan,
  other;

  /// Parses Akahu account type string to enum.
  static AccountType fromAkahu(String? type) {
    switch (type?.toUpperCase()) {
      case 'CHECKING':
        return AccountType.checking;
      case 'SAVINGS':
        return AccountType.savings;
      case 'CREDITCARD':
      case 'CREDIT_CARD':
        return AccountType.creditCard;
      case 'KIWISAVER':
        return AccountType.kiwiSaver;
      case 'INVESTMENT':
        return AccountType.investment;
      case 'LOAN':
        return AccountType.loan;
      default:
        return AccountType.other;
    }
  }

  /// Returns a human-readable label for display.
  String get displayName {
    switch (this) {
      case AccountType.checking:
        return 'Everyday';
      case AccountType.savings:
        return 'Savings';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.kiwiSaver:
        return 'KiwiSaver';
      case AccountType.investment:
        return 'Investment';
      case AccountType.loan:
        return 'Loan';
      case AccountType.other:
        return 'Account';
    }
  }

  /// Returns true if this account type typically represents a liability.
  bool get isLiability {
    return this == AccountType.creditCard || this == AccountType.loan;
  }
}

/// Immutable account domain object for connected bank accounts.
class AccountModel {
  final int? id;
  final String akahuId;
  final String name;
  final AccountType type;
  final double balanceCurrent;
  final double? balanceAvailable;
  final String? balanceFormatted;
  final String? connectionId;
  final String? connectionName;
  final String? connectionLogo;
  final String? connectionType;
  final String? accountNumber;
  final DateTime? refreshedAt;
  final DateTime? syncedAt;

  const AccountModel({
    this.id,
    required this.akahuId,
    required this.name,
    required this.type,
    required this.balanceCurrent,
    this.balanceAvailable,
    this.balanceFormatted,
    this.connectionId,
    this.connectionName,
    this.connectionLogo,
    this.connectionType,
    this.accountNumber,
    this.refreshedAt,
    this.syncedAt,
  });

  /// Creates an AccountModel from Akahu API JSON response.
  factory AccountModel.fromAkahu(Map<String, dynamic> json) {
    final connection = json['connection'] as Map<String, dynamic>?;
    final balance = json['balance'] as Map<String, dynamic>?;
    final meta = json['meta'] as Map<String, dynamic>?;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AccountModel(
      akahuId: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Account',
      type: AccountType.fromAkahu(json['type'] as String?),
      balanceCurrent: (balance?['current'] as num?)?.toDouble() ?? 0.0,
      balanceAvailable: (balance?['available'] as num?)?.toDouble(),
      balanceFormatted: balance?['formatted'] as String?,
      connectionId: connection?['_id'] as String?,
      connectionName: connection?['name'] as String?,
      connectionLogo: connection?['logo'] as String?,
      connectionType: connection?['connection_type'] as String?,
      accountNumber: meta?['account_number'] as String?,
      refreshedAt: parseDate(json['refreshed']),
      syncedAt: DateTime.now(),
    );
  }

  /// Creates an AccountModel from SQLite row.
  factory AccountModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AccountModel(
      id: map['id'] as int?,
      akahuId: map['akahu_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Account',
      type: AccountType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => AccountType.other,
      ),
      balanceCurrent: (map['balance_current'] as num?)?.toDouble() ?? 0.0,
      balanceAvailable: (map['balance_available'] as num?)?.toDouble(),
      balanceFormatted: map['balance_formatted'] as String?,
      connectionId: map['connection_id'] as String?,
      connectionName: map['connection_name'] as String?,
      connectionLogo: map['connection_logo'] as String?,
      connectionType: map['connection_type'] as String?,
      accountNumber: map['account_number'] as String?,
      refreshedAt: parseDate(map['refreshed_at']),
      syncedAt: parseDate(map['synced_at']),
    );
  }

  /// Converts to a map for SQLite insert/update.
  Map<String, dynamic> toDbMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'akahu_id': akahuId,
      'name': name,
      'type': type.name,
      'balance_current': balanceCurrent,
      'balance_available': balanceAvailable,
      'balance_formatted': balanceFormatted,
      'connection_id': connectionId,
      'connection_name': connectionName,
      'connection_logo': connectionLogo,
      'connection_type': connectionType,
      'account_number': accountNumber,
      'refreshed_at': refreshedAt?.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Returns the display balance (current balance for assets, absolute for liabilities).
  double get displayBalance => balanceCurrent;

  /// Returns true if this is an asset (positive contributes to net worth).
  bool get isAsset => !type.isLiability;

  /// Returns true if this is a liability (negative impact on net worth).
  bool get isLiability => type.isLiability;

  /// Returns the contribution to net worth (positive for assets, negative for liabilities).
  double get netWorthContribution {
    if (type.isLiability) {
      // Credit cards typically show negative balances for amounts owed
      return balanceCurrent < 0 ? balanceCurrent : -balanceCurrent.abs();
    }
    return balanceCurrent;
  }

  /// Formats the balance for display with currency symbol.
  String get formattedBalance {
    if (balanceFormatted != null && balanceFormatted!.isNotEmpty) {
      return balanceFormatted!;
    }
    final prefix = balanceCurrent < 0 ? '-\$' : '\$';
    return '$prefix${balanceCurrent.abs().toStringAsFixed(2)}';
  }

  /// Returns a masked account number for display (last 4 digits).
  String? get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) {
      return accountNumber;
    }
    return '••••${accountNumber!.substring(accountNumber!.length - 4)}';
  }

  /// Creates a copy with optional field overrides.
  AccountModel copyWith({
    int? id,
    String? akahuId,
    String? name,
    AccountType? type,
    double? balanceCurrent,
    double? balanceAvailable,
    String? balanceFormatted,
    String? connectionId,
    String? connectionName,
    String? connectionLogo,
    String? connectionType,
    String? accountNumber,
    DateTime? refreshedAt,
    DateTime? syncedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      akahuId: akahuId ?? this.akahuId,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceCurrent: balanceCurrent ?? this.balanceCurrent,
      balanceAvailable: balanceAvailable ?? this.balanceAvailable,
      balanceFormatted: balanceFormatted ?? this.balanceFormatted,
      connectionId: connectionId ?? this.connectionId,
      connectionName: connectionName ?? this.connectionName,
      connectionLogo: connectionLogo ?? this.connectionLogo,
      connectionType: connectionType ?? this.connectionType,
      accountNumber: accountNumber ?? this.accountNumber,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
