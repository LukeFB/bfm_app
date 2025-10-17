// Author: Luke Fraser-Brown

import 'package:flutter/material.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/models/transaction_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshTransactions();
  }

  void _refreshTransactions() {
    setState(() {
      _transactionsFuture = TransactionRepository.getAll();
    });
  }

  // --- UI ---
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
          return ListView.builder(
            itemCount: txns.length,
            itemBuilder: (context, index) {
              final t = txns[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(
                    t.type == "expense" ? Icons.remove_circle : Icons.add_circle,
                    color: t.type == "expense" ? Colors.red : Colors.green,
                  ),
                  title: Text(t.description),
                  subtitle: Text("${t.date} • Category ID: ${t.categoryId ?? 'None'}"),
                  trailing: Text(
                    (t.type == "expense" ? "-" : "+") +
                        "\$${t.amount.abs().toStringAsFixed(2)}",
                    style: TextStyle(
                      color: t.type == "expense" ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onLongPress: () => _deleteTransaction(t.id!),
                ),
              );
            },
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
  void _showAddTransactionDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String type = "expense"; // default
    final dateController = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Transaction"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
              ),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: "expense", child: Text("Expense")),
                  DropdownMenuItem(value: "income", child: Text("Income")),
                ],
                onChanged: (value) {
                  if (value != null) type = value;
                },
                decoration: const InputDecoration(labelText: "Type"),
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: "Date (YYYY-MM-DD)",
                ),
              ),

              // TODO replace with category dropdown
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Category ID",
                ),
                onChanged: (value) {
                  selectedCategoryId = int.tryParse(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Delete Transaction ---
  Future<void> _deleteTransaction(int id) async {
    await TransactionRepository.delete(id);
    _refreshTransactions();
  }
}
