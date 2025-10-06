import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/recurring_repository.dart';

class BankService {
  static Future<void> disconnect() async {
    // Clear transactions + recurring bills
    await TransactionRepository.clearAll();
    await RecurringRepository.clearAll();
    await BudgetRepository.clearAll();

    // Clear bank connection flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bank_connected', false);

    // TODO: disconnect akahu clear tokens
  }
}
