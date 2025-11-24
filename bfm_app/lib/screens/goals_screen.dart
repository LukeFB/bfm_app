import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Future<List<GoalModel>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _refreshGoals();
  }

  void _refreshGoals() {
    setState(() {
      _goalsFuture = GoalRepository.getAll();
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Goals")),
      body: FutureBuilder<List<GoalModel>>(
        future: _goalsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final goals = snapshot.data!;
          if (goals.isEmpty) {
            return const Center(child: Text("No goals yet. Add one!"));
          }
          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final goalName = goal.name.trim().isEmpty ? 'Goal' : goal.name;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(goalName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Goal amount: \$${goal.amount.toStringAsFixed(2)}"),
                      Text(
                        "Weekly contribution: \$${goal.weeklyContribution.toStringAsFixed(2)}/wk",
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: goal.progressFraction,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.progressLabel(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showContributeDialog(goal),
                          icon: const Icon(Icons.savings_outlined, size: 16),
                          label: const Text("Contribute"),
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (choice) {
                      if (choice == 'edit') {
                        _showEditGoalDialog(goal);
                      } else if (choice == 'delete') {
                        _deleteGoal(goal.id!);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(value: 'delete', child: Text("Delete")),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Add Goal Dialog ---
  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final weeklyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Goal"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Goal Amount"),
              ),
              TextField(
                controller: weeklyController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Weekly Contribution"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newGoal = GoalModel(
                name: nameController.text.trim(),
                amount: double.tryParse(amountController.text.trim()) ?? 0,
                weeklyContribution:
                    double.tryParse(weeklyController.text.trim()) ?? 0,
              );
              await GoalRepository.insert(newGoal);
              _refreshGoals();
              Navigator.of(context).pop(true); // return true so dashboard can decide to refresh
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- Edit Goal Dialog ---
  void _showEditGoalDialog(GoalModel goal) {
    final nameController = TextEditingController(text: goal.name);
    final amountController =
        TextEditingController(text: goal.amount.toStringAsFixed(2));
    final weeklyController = TextEditingController(
        text: goal.weeklyContribution.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Goal"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Goal Amount"),
              ),
              TextField(
                controller: weeklyController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Weekly Contribution"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final updated = goal.copyWith(
                name: nameController.text.trim(),
                amount: double.tryParse(amountController.text.trim()) ??
                    goal.amount,
                weeklyContribution:
                    double.tryParse(weeklyController.text.trim()) ??
                        goal.weeklyContribution,
              );
              await GoalRepository.update(updated);
              _refreshGoals();
              Navigator.of(context).pop(true);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // --- Delete Goal ---
  Future<void> _deleteGoal(int id) async {
    await GoalRepository.delete(id);
    _refreshGoals();
  }

  void _showContributeDialog(GoalModel goal) {
    final defaultAmount = goal.weeklyContribution > 0
        ? goal.weeklyContribution
        : math.min(25, (goal.amount - goal.savedAmount).clamp(0, goal.amount));
    final amountController =
        TextEditingController(text: defaultAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Contribute to ${goal.name}"),
        content: TextField(
          controller: amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: const InputDecoration(
            labelText: "Amount",
            prefixText: "\$",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              final amount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amount <= 0) return;
              final applied =
                  await GoalRepository.addManualContribution(goal, amount);
              if (applied > 0) {
                final today = DateTime.now();
                final dateStr =
                    "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
                await TransactionRepository.insertManual(
                  TransactionModel(
                    amount: -applied,
                    description: "Goal contribution: ${goal.name}",
                    date: dateStr,
                    type: 'expense',
                    categoryName: 'Goal contribution',
                  ),
                );
                _refreshGoals();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            "Contributed \$${applied.toStringAsFixed(2)} to ${goal.name}")),
                  );
                }
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text("Contribute"),
          ),
        ],
      ),
    );
  }
}
