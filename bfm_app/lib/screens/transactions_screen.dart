/// ---------------------------------------------------------------------------
/// File: lib/screens/transactions_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `/transaction` route (from dashboard card).
///
/// Purpose:
///   - Simple list view showing all stored transactions with quick add/delete.
///
/// Inputs:
///   - Reads via `TransactionRepository`, writes back on add/delete.
///
/// Outputs:
///   - UI list plus manual insert/delete functionality.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/repositories/category_repository.dart';
import 'package:bfm_app/models/transaction_model.dart';
import 'package:bfm_app/models/category_model.dart';

/// Basic list of all stored transactions with add/delete affordances.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

/// Handles fetching transactions and reacting to add/delete events.
class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;
  Map<int, String> _categoryNames = {};

  /// Loads the first batch of transactions.
  @override
  void initState() {
    super.initState();
    _refreshTransactions();
  }

  /// Reloads all transactions so the FutureBuilder updates.
  void _refreshTransactions() {
    setState(() {
      _transactionsFuture = _loadTransactionsWithCategories();
    });
  }

  /// Loads transactions and fetches category names for display.
  Future<List<TransactionModel>> _loadTransactionsWithCategories() async {
    final txns = await TransactionRepository.getAll();
    // Collect all category IDs that need name lookup
    final categoryIds = txns
        .where((t) => t.categoryId != null && t.categoryName == null)
        .map((t) => t.categoryId!)
        .toSet();
    if (categoryIds.isNotEmpty) {
      _categoryNames = await CategoryRepository.getNamesByIds(categoryIds);
    }
    return txns;
  }

  /// Returns the display name for a transaction's category.
  String _getCategoryDisplay(TransactionModel t) {
    if (t.categoryName != null && t.categoryName!.isNotEmpty) {
      return t.categoryName!;
    }
    if (t.categoryId != null && _categoryNames.containsKey(t.categoryId)) {
      return _categoryNames[t.categoryId]!;
    }
    return 'Uncategorized';
  }

  // --- UI ---
  /// Renders the transaction list, loading states, and add FAB.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transactions")),
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final txns = snapshot.data!;
          if (txns.isEmpty) {
            return const Center(child: Text("No transactions yet."));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  "Hold a transaction to edit or delete it.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: txns.length,
                  itemBuilder: (context, index) {
                    final t = txns[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: Icon(
                          t.type == "expense"
                              ? Icons.remove_circle
                              : Icons.add_circle,
                          color:
                              t.type == "expense" ? Colors.red : Colors.green,
                        ),
                        title: Text(t.description),
                        subtitle: Text(
                            "${t.date} • ${_getCategoryDisplay(t)}"),
                        trailing: Text(
                          (t.type == "expense" ? "-" : "+") +
                              "\$${t.amount.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            color:
                                t.type == "expense" ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onLongPress: () => _showEditOptions(t),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Add Transaction Dialog ---
  /// Quick dialog for inserting a manual transaction (debug/testing use).
  void _showAddTransactionDialog() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String type = "expense"; // default
    final dateController = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));
    CategoryModel? selectedCategory;

    // Load categories for the dropdown, ordered by usage (most used first)
    final categoryMaps = await CategoryRepository.getAllOrderedByUsage();
    final categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Transaction"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "expense", child: Text("Expense")),
                        DropdownMenuItem(value: "income", child: Text("Income")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: "Type"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Date (YYYY-MM-DD)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CategoryModel>(
                      value: selectedCategory,
                      isExpanded: true,
                      hint: const Text("Select Category"),
                      items: categories.map((cat) {
                        return DropdownMenuItem<CategoryModel>(
                          value: cat,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategory = value);
                      },
                      decoration: const InputDecoration(labelText: "Category"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in description and amount")),
                      );
                      return;
                    }

                    final txn = TransactionModel(
                      description: descController.text,
                      amount: amount,
                      type: type,
                      date: dateController.text,
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                    );

                    await TransactionRepository.insertManual(txn);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    _refreshTransactions();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Edit Options Bottom Sheet ---
  /// Shows a bottom sheet with options to edit, change category, or delete.
  void _showEditOptions(TransactionModel txn) {
    final id = txn.id;
    if (id == null) return;

    final formattedAmount = txn.type == 'expense'
        ? "-\$${txn.amount.abs().toStringAsFixed(2)}"
        : "\$${txn.amount.abs().toStringAsFixed(2)}";
    final amountColor = txn.type == 'expense' ? Colors.red : Colors.green;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  txn.description.isEmpty ? "Transaction" : txn.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text("${txn.date} • ${_getCategoryDisplay(txn)}"),
                trailing: Text(
                  formattedAmount,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Transaction'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditTransactionDialog(txn);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Transaction', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(txn);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --- Edit Transaction Dialog ---
  /// Shows a dialog to edit all fields of a transaction.
  void _showEditTransactionDialog(TransactionModel txn) async {
    final id = txn.id;
    if (id == null) return;

    final descController = TextEditingController(text: txn.description);
    final amountController = TextEditingController(text: txn.amount.abs().toString());
    String type = txn.type;
    final dateController = TextEditingController(text: txn.date);

    // Load categories ordered by usage
    final categoryMaps = await CategoryRepository.getAllOrderedByUsage();
    final categories = categoryMaps.map((m) => CategoryModel.fromMap(m)).toList();

    // Find current category
    CategoryModel? selectedCategory;
    if (txn.categoryId != null) {
      try {
        selectedCategory = categories.firstWhere((c) => c.id == txn.categoryId);
      } catch (_) {
        // Category not found, leave as null
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Transaction"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "expense", child: Text("Expense")),
                        DropdownMenuItem(value: "income", child: Text("Income")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: "Type"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Date (YYYY-MM-DD)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CategoryModel>(
                      value: selectedCategory,
                      isExpanded: true,
                      hint: const Text("Select Category"),
                      items: categories.map((cat) {
                        return DropdownMenuItem<CategoryModel>(
                          value: cat,
                          child: Text(
                            cat.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategory = value);
                      },
                      decoration: const InputDecoration(labelText: "Category"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in description and amount")),
                      );
                      return;
                    }

                    final updatedTxn = TransactionModel(
                      id: id,
                      description: descController.text,
                      amount: amount,
                      type: type,
                      date: dateController.text,
                      categoryId: selectedCategory?.id,
                      categoryName: selectedCategory?.name,
                      akahuId: txn.akahuId,
                      akahuHash: txn.akahuHash,
                      accountId: txn.accountId,
                      connectionId: txn.connectionId,
                      excluded: txn.excluded,
                    );

                    await TransactionRepository.insertManual(updatedTxn);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    _refreshTransactions();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Confirm Delete ---
  /// Shows a confirmation dialog before deleting a transaction.
  void _confirmDelete(TransactionModel txn) {
    final id = txn.id;
    if (id == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Transaction"),
          content: Text(
            'Are you sure you want to delete "${txn.description.isEmpty ? "this transaction" : txn.description}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await TransactionRepository.delete(id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                _refreshTransactions();
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
