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
import 'package:bfm_app/widgets/help_icon_tooltip.dart';

/// Stateful wrapper because the screen owns dialog controllers and refreshes
/// its own Future each time a CRUD action completes.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

/// Holds both savings and recovery goals for display.
class _GoalsData {
  final List<GoalModel> savingsGoals;
  final List<GoalModel> recoveryGoals;
  
  const _GoalsData({required this.savingsGoals, required this.recoveryGoals});
}

/// Loads goals, handles CRUD dialogs, and keeps the list fresh.
class _GoalsScreenState extends State<GoalsScreen> {
  late Future<_GoalsData> _goalsFuture;

  /// Bootstraps the goals Future when entering the screen.
  @override
  void initState() {
    super.initState();
    _refreshGoals();
  }

  /// Reloads goals from SQLite and rebuilds the FutureBuilder in-place.
  void _refreshGoals() {
    setState(() {
      _goalsFuture = _loadGoals();
    });
  }
  
  Future<_GoalsData> _loadGoals() async {
    final results = await Future.wait([
      GoalRepository.getSavingsGoals(),
      GoalRepository.getRecoveryGoals(),
    ]);
    return _GoalsData(
      savingsGoals: results[0] as List<GoalModel>,
      recoveryGoals: results[1] as List<GoalModel>,
    );
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
      body: FutureBuilder<_GoalsData>(
        future: _goalsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final savingsGoals = data.savingsGoals;
          final recoveryGoals = data.recoveryGoals;
          
          if (savingsGoals.isEmpty && recoveryGoals.isEmpty) {
            return const Center(child: Text("No goals yet. Add one!"));
          }
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    "Hold a goal card to edit, contribute, or delete.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                // Recovery Goals Section
                if (recoveryGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.trending_down, 
                          color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Recovery Goals",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        HelpIconTooltip(
                          title: 'Recovery Goals',
                          message: 'Recovery goals help you bounce back after overspending.\n\n'
                              'When you go over budget, instead of stressing, Moni creates a '
                              'recovery goal that spreads the deficit over several weeks.\n\n'
                              'Each week, pay the suggested amount to gradually get back on track. '
                              'Once fully paid back, the goal will be marked complete!\n\n'
                              'Tip: The weekly overview will automatically prompt you to contribute.',
                          size: 16,
                          color: Colors.orange.shade600,
                        ),
                      ],
                    ),
                  ),
                  ...recoveryGoals.map((goal) => _buildRecoveryGoalCard(goal)),
                  const SizedBox(height: 8),
                ],
                // Savings Goals Section
                if (savingsGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.savings_outlined, 
                          color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Savings Goals",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...savingsGoals.map((goal) => _buildSavingsGoalCard(goal)),
                ],
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSavingsGoalCard(GoalModel goal) {
    final goalName = goal.name.trim().isEmpty ? 'Goal' : goal.name;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onLongPress: () => _showGoalActionsSheet(goal),
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecoveryGoalCard(GoalModel goal) {
    final remaining = (goal.amount - goal.savedAmount).clamp(0.0, double.infinity);
    final weeksText = goal.recoveryWeeks != null 
        ? "${goal.recoveryWeeks} week plan" 
        : "";
    final isComplete = goal.isComplete;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
      child: ListTile(
        onLongPress: () => _showGoalActionsSheet(goal),
        leading: Icon(
          isComplete ? Icons.check_circle : Icons.trending_down,
          color: isComplete ? Colors.green : Colors.orange.shade700,
        ),
        title: Text(
          "\$${goal.amount.toStringAsFixed(0)} to pay back",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isComplete ? Colors.green.shade800 : Colors.orange.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Weekly payment: \$${goal.weeklyContribution.toStringAsFixed(2)}/wk",
              style: const TextStyle(fontSize: 13),
            ),
            if (weeksText.isNotEmpty)
              Text(
                weeksText,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: goal.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.orange.shade100,
              color: isComplete ? Colors.green : Colors.orange.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              isComplete 
                  ? "Fully paid back!" 
                  : "\$${goal.savedAmount.toStringAsFixed(0)} paid back, \$${remaining.toStringAsFixed(0)} remaining",
              style: TextStyle(
                fontSize: 12,
                color: isComplete ? Colors.green.shade700 : Colors.grey,
                fontWeight: isComplete ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
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
