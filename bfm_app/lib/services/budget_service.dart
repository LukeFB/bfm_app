// ---------------------------------------------------------------------------
// Author:Jack Unsworth
// Purpose:
//   Clear Budgets Button
// ---------------------------------------------------------------------------


import 'package:bfm_app/db/app_database.dart';

class BudgetService {
  /// Deletes all budgets from the local database
  static Future<void> clearAllBudgets() async {
    final db = await AppDatabase.instance.database;
    await db.delete('budgets');
  }
}
