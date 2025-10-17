// Author: Luke Fraser-Brown

import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BankConnectScreen extends StatefulWidget {
  const BankConnectScreen({Key? key}) : super(key: key);

  @override
  State<BankConnectScreen> createState() => _BankConnectScreenState();
}

class _BankConnectScreenState extends State<BankConnectScreen> {
  final _appTokenController = TextEditingController();
  final _userTokenController = TextEditingController();

  Future<void> _onContinue() async {
    final appToken = _appTokenController.text.trim();
    final userToken = _userTokenController.text.trim();

    try {
      // Fetch from Akahu
      final items = await AkahuService.fetchTransactions(appToken, userToken);

      // Insert into DB
      await TransactionRepository.insertFromAkahu(items);

      // Inserting income so I dont look broke during the demo TODO: remove income
      // final db = await AppDatabase.instance.database;
      // await db.rawInsert('''
      //   INSERT INTO transactions
      //     (amount, description, date, type, category_id, category_name, merchant_name)
      //   VALUES
      //     (?, ?, date('now','-7 day'), 'income', NULL, 'Income', 'Employer')
      // ''', [300.00, 'Payday (demo)']);

      // Detect recurring
      await BudgetAnalysisService.identifyRecurringTransactions();

      // Mark connected
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bank_connected', true);

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
