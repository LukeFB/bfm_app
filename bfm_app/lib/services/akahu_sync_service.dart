/// ---------------------------------------------------------------------------
/// File: akahu_sync_service.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Orchestrates the process of importing bank data from Akahu into the local 
///   app. This includes using the AkahuService to fetch accounts and transactions, 
///   mapping them to local models, categorizing transactions, and saving them in 
///   the local SQLite database. It also triggers detection of recurring transactions 
///   once data is imported.
/// 
/// Notes:
///   - This service assumes the user has already obtained and stored a valid 
///     Akahu access token (via the OAuth login flow).
///   - Transactions fetched are converted to `TransactionModel` for consistency 
///     with local usage. The service attempts to map Akahu categories to existing 
///     local categories (in `categories` table) by name, creating new categories 
///     if needed.
///   - After importing transactions, it calls `BudgetAnalysisService.identifyRecurringTransactions` 
///     to analyze and store any recurring expenses (e.g., subscriptions, rent).
/// ---------------------------------------------------------------------------

import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/category_model.dart';
import 'package:bfm_app/services/akahu_service.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';

class AkahuSyncService {
  /// Fetch accounts and transactions from Akahu and store them locally.
  /// 
  /// - Uses the [accessToken] to retrieve all accounts linked to the user.
  /// - For each account, fetches recent transactions and converts them to `TransactionModel`.
  /// - Maps each transaction's category (if provided by Akahu) to a local category. 
  ///   If a matching category is not found, a new category entry is inserted.
  /// - Stores all transactions in the local `transactions` SQLite table.
  /// - After import, triggers detection of recurring transactions.
  /// 
  /// Returns the total number of transactions imported.
  static Future<int> importAccountsAndTransactions(String accessToken) async {
    int importedCount = 0;
    // 1. Fetch all accounts from Akahu
    final accounts = await AkahuService.getAccounts(accessToken);
    if (accounts.isEmpty) {
      // No accounts or invalid token
      return 0;
    }

    // 2. Prepare local categories for mapping
    final categoryList = await CategoryRepository.getAll(); 
    // Build a map of category name (lowercase) -> CategoryModel for quick lookup
    final Map<String, CategoryModel> categoriesByName = {
      for (var m in categoryList) 
        if ((m['name'] as String?) != null) 
          (m['name'] as String).toLowerCase(): CategoryModel.fromMap(m)
    };

    // 3. For each account, fetch its transactions
    for (var acct in accounts) {
      final acctId = acct['_id'] ?? acct['id'];
      if (acctId == null) continue;
      final accountId = acctId as String;
      // Fetch transactions for this account
      final txnData = await AkahuService.getTransactions(accessToken, accountId);
      // Convert each transaction JSON to TransactionModel and insert into DB
      for (var item in txnData) {
        final txnJson = item as Map<String, dynamic>;
        // Use TransactionModel.fromAkahu to map Akahu data to our model
        TransactionModel txnModel = TransactionModel.fromAkahu(txnJson);

        // Attempt to categorize the transaction using Akahu's category info
        if (txnJson.containsKey('category') && txnJson['category'] is Map) {
          final akahuCat = txnJson['category'] as Map<String, dynamic>;
          final akahuCatName = akahuCat['name'] as String?; 
          if (akahuCatName != null && akahuCatName.isNotEmpty) {
            final key = akahuCatName.toLowerCase();
            if (categoriesByName.containsKey(key)) {
              // Match found: assign existing local category
              txnModel = TransactionModel(
                id: txnModel.id,
                akahuId: txnModel.akahuId,
                accountId: txnModel.accountId,
                connectionId: txnModel.connectionId,
                categoryId: categoriesByName[key]!.id,
                amount: txnModel.amount,
                description: txnModel.description,
                date: txnModel.date,
                type: txnModel.type,
                balance: txnModel.balance,
                merchantName: txnModel.merchantName,
                merchantWebsite: txnModel.merchantWebsite,
                logo: txnModel.logo,
                meta: txnModel.meta,
              );
            } else {
              // No matching category in our DB: create a new category entry
              final newCategory = CategoryModel(
                name: akahuCatName,
                icon: null,
                color: null,
                akahuCategoryId: akahuCat['_id'] as String?,
              );
              // Insert the new category into the database
              final newId = await CategoryRepository.insert(newCategory.toMap());
              // Update our local map for future transactions
              final savedCat = CategoryModel(
                id: newId,
                name: newCategory.name,
                icon: newCategory.icon,
                color: newCategory.color,
                akahuCategoryId: newCategory.akahuCategoryId,
              );
              categoriesByName[akahuCatName.toLowerCase()] = savedCat;
              // Assign the new category to the transaction
              txnModel = TransactionModel(
                id: txnModel.id,
                akahuId: txnModel.akahuId,
                accountId: txnModel.accountId,
                connectionId: txnModel.connectionId,
                categoryId: savedCat.id,
                amount: txnModel.amount,
                description: txnModel.description,
                date: txnModel.date,
                type: txnModel.type,
                balance: txnModel.balance,
                merchantName: txnModel.merchantName,
                merchantWebsite: txnModel.merchantWebsite,
                logo: txnModel.logo,
                meta: txnModel.meta,
              );
            }
          }
        }

        // 4. Insert transaction into local database
        await TransactionRepository.insert(txnModel);
        importedCount++;
      }
    }

    // 5. Identify recurring transactions from the newly imported data
    await BudgetAnalysisService.identifyRecurringTransactions();
    return importedCount;
  }
}
