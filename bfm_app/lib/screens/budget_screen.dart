import 'package:flutter/material.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transactions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add transaction
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TransactionItem(label: "Fortnite", amount: -10.00, date: "Mon"),
          _TransactionItem(label: "Groceries", amount: -35.20, date: "Fri"),
          _TransactionItem(label: "Rent", amount: -180.00, date: "Thur"),
          _TransactionItem(label: "Textbooks", amount: -20.00, date: "Thur"),
          _TransactionItem(label: "StudyLink", amount: 280.00, date: "Wed"),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String label;
  final double amount;
  final String date;
  const _TransactionItem({required this.label, required this.amount, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label),
        subtitle: Text(date),
        trailing: Text(
          "\$${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: amount < 0 ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
