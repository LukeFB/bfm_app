import 'dart:developer';

import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionSyncService {
  TransactionSyncService({SecureCredentialStore? credentialStore})
      : _credentialStore = credentialStore ?? SecureCredentialStore();

  final SecureCredentialStore _credentialStore;
  static const _lastSyncKey = 'last_sync_at';

  Future<void> syncNow() async {
    final tokens = await _credentialStore.readAkahuTokens();
    if (tokens == null) {
      throw Exception('No Akahu tokens stored. Please reconnect your bank.');
    }

    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) {
      log('Skipping sync: bank not connected.');
      return;
    }

    final payloads =
        await AkahuService.fetchTransactions(tokens.appToken, tokens.userToken);

    if (payloads.isEmpty) {
      await _markSynced();
      return;
    }

    await TransactionRepository.upsertFromAkahu(payloads);
    await _markSynced();
  }

  Future<bool> syncIfStale({Duration maxAge = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!connected) {
      return false;
    }

    final tokens = await _credentialStore.readAkahuTokens();
    if (tokens == null) {
      return false;
    }

    final lastSyncIso = prefs.getString(_lastSyncKey);
    if (lastSyncIso == null) {
      await syncNow();
      return true;
    }

    final lastSync = DateTime.tryParse(lastSyncIso);
    if (lastSync == null || DateTime.now().difference(lastSync) > maxAge) {
      await syncNow();
      return true;
    }
    return false;
  }

  Future<void> _markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }
}

