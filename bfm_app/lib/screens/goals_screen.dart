/// ---------------------------------------------------------------------------
/// File: lib/screens/goals_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   Full UI for showing, creating, editing, contributing to, and deleting
///   savings goals.
///
/// Called by:
///   `app.dart` via the bottom nav Goals tab.
///
/// Inputs / Outputs:
///   Reads goals through `GoalRepository`, writes changes back via the same,
///   and logs manual contributions as transactions so analytics stay in sync.
/// ---------------------------------------------------------------------------
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/models/goal_model.dart';
import 'package:bfm_app/models/transaction_model.dart';

/// Stateful wrapper because the screen owns dialog controllers and refreshes
/// its own Future each time a CRUD action completes.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

/// Loads goals, handles CRUD dialogs, and keeps the list fresh.
class _GoalsScreenState extends State<GoalsScreen> {
  late Future<List<GoalModel>> _goalsFuture;

  /// Bootstraps the goals Future when entering the screen.
  @override
  void initState() {
    super.initState();
    _refreshGoals();
  }

  /// Reloads goals from SQLite and rebuilds the FutureBuilder in-place.
  void _refreshGoals() {
    setState(() {
      _goalsFuture = GoalRepository.getAll();
    });
  }

  // --- UI ---
  @override
  /// Builds the scaffold with:
  /// - App bar, loading fallback, “no goals” empty state.
  /// - Lazy list of goals that shows progress, CTA buttons, and popup menu.
  /// - FAB for adding new goals.
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  "Hold a goal card to edit, contribute, or delete.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final goalName =
                        goal.name.trim().isEmpty ? 'Goal' : goal.name;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        onLongPress: () => _showGoalActionsSheet(goal),
                        title: Text(goalName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Goal amount: \$${goal.amount.toStringAsFixed(2)}"),
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
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
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
        onPressed: () => _showAddGoalDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Add Goal Dialog ---
  /// Presents a dialog for creating a new goal, validates numeric inputs,
  /// persists via the repository, and triggers a refresh plus a navigator pop.
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
                amount: _parseCurrency(amountController.text.trim()),
                weeklyContribution:
                    _parseCurrency(weeklyController.text.trim()),
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
  /// Mirrors the add dialog but pre-fills fields, then updates the record and
  /// refreshes the list once the user saves changes.
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
                amount: _parseCurrency(
                  amountController.text.trim(),
                  fallback: goal.amount,
                ),
                weeklyContribution: _parseCurrency(
                  weeklyController.text.trim(),
                  fallback: goal.weeklyContribution,
                ),
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
  /// Deletes the goal by id and refreshes the visible list afterwards.
  Future<void> _deleteGoal(int id) async {
    await GoalRepository.delete(id);
    _refreshGoals();
  }

  /// Reveals goal actions through a long-press bottom sheet.
  void _showGoalActionsSheet(GoalModel goal) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text("Contribute"),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showContributeDialog(goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("Edit"),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditGoalDialog(goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final goalId = goal.id;
                if (goalId != null) {
                  _deleteGoal(goalId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Collects a manual contribution amount, applies it to the goal, writes a
  /// matching manual transaction, and surfaces toast feedback.
  /// Picks a helpful default amount (weekly contribution or capped catch-up).
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
              final amount = _parseCurrency(amountController.text.trim());
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
  
  /// Parses user-entered currency strings, tolerating commas and symbols.
  double _parseCurrency(String raw, {double fallback = 0.0}) {
    if (raw.trim().isEmpty) return fallback;
    final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    final value = double.tryParse(sanitized);
    if (value == null || value.isNaN || value.isInfinite) return fallback;
    return value;
  }
}
