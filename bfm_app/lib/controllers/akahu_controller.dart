import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bfm_app/api/akahu_api.dart';
import 'package:bfm_app/providers/api_providers.dart';

@immutable
class AkahuState {
  final bool isLoading;
  final bool isConnected;
  final String? error;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;

  const AkahuState({
    this.isLoading = false,
    this.isConnected = false,
    this.error,
    this.accounts = const [],
    this.transactions = const [],
  });

  AkahuState copyWith({
    bool? isLoading,
    bool? isConnected,
    String? error,
    List<Map<String, dynamic>>? accounts,
    List<Map<String, dynamic>>? transactions,
    bool clearError = false,
  }) {
    return AkahuState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
      accounts: accounts ?? this.accounts,
      transactions: transactions ?? this.transactions,
    );
  }
}

class AkahuController extends Notifier<AkahuState> {
  late final AkahuApi _api;

  @override
  AkahuState build() {
    _api = ref.watch(akahuApiProvider);
    return const AkahuState();
  }

  /// Calls /akahu/connect and opens the returned URL in an external browser.
  Future<void> startConnect() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final url = await _api.connectUrl();
      await launchUrl(url, mode: LaunchMode.externalApplication);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Calls /akahu/accounts; if any come back, the user is connected.
  Future<bool> verifyConnected() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final accts = await _api.accounts();
      final connected = accts.isNotEmpty;
      state = state.copyWith(
        isLoading: false,
        isConnected: connected,
        accounts: accts,
      );
      return connected;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> fetchAccounts() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final accts = await _api.accounts();
      state = state.copyWith(
        isLoading: false,
        accounts: accts,
        isConnected: accts.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final txns = await _api.transactions();
      state = state.copyWith(isLoading: false, transactions: txns);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Revokes the Akahu session on the backend.
  Future<void> revokeConnection() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.revoke();
      state = const AkahuState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final akahuControllerProvider =
    NotifierProvider<AkahuController, AkahuState>(AkahuController.new);
