/// ---------------------------------------------------------------------------
/// File: lib/screens/bank_connect_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Navigation routes `/bankconnect` right after LockGate when no bank is
///     linked yet.
///
/// Purpose:
///   - Collects Akahu app/user tokens, persists them securely, toggles the
///     `bank_connected` flag, and kicks off an initial transaction sync.
///
/// Inputs:
///   - User-entered app/user tokens.
///
/// Outputs:
///   - SecureCredentialStore writes, SharedPreferences flags, navigation to the
///     budget builder on success.
/// ---------------------------------------------------------------------------

import 'package:bfm_app/services/secure_credential_store.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple form that handles bank credential onboarding.
class BankConnectScreen extends StatefulWidget {
  const BankConnectScreen({Key? key}) : super(key: key);

  @override
  State<BankConnectScreen> createState() => _BankConnectScreenState();
}

/// Owns the token text controllers and sync tap handler.
class _BankConnectScreenState extends State<BankConnectScreen> {
  final _appTokenController = TextEditingController();
  final _userTokenController = TextEditingController();

  /// Validates tokens, saves them securely, flips `bank_connected`, fires a
  /// sync, and routes to budget builder. Shows a snack bar on failure.
  Future<void> _onContinue() async {
    final appToken = _appTokenController.text.trim();
    final userToken = _userTokenController.text.trim();

    try {
      // Fetch from Akahu
      if (appToken.isEmpty || userToken.isEmpty) {
        throw Exception('Please enter both tokens.');
      }

      await SecureCredentialStore()
          .saveAkahuTokens(appToken: appToken, userToken: userToken);

      // Mark connected
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bank_connected', true);
      await prefs.remove('last_sync_at');

      // Trigger initial sync pipeline
      await TransactionSyncService().syncNow();

      if (!mounted) return;

      // Send user to the Budget Build screen
      Navigator.pushReplacementNamed(context, '/budget/build');
    } catch (e) {
      debugPrint("Bank connect error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  /// Renders the two text fields plus CTA.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connect Your Bank")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Enter your App Token (ID) and User Token (Bearer). "
              "This is a placeholder for connecting to the Akahu API.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _appTokenController,
              decoration: const InputDecoration(
                labelText: "App Token (X-Akahu-Id)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _userTokenController,
              decoration: const InputDecoration(
                labelText: "User Token (Bearer)",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _onContinue,
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
