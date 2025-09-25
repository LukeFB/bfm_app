import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:bfm_app/db/app_database.dart';

import 'package:bfm_app/repositories/goal_repository.dart';
import 'package:bfm_app/models/goal_model.dart';

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
              double progress = goal.currentAmount / goal.targetAmount;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(goal.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        color: bfmBlue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                          "\$${goal.currentAmount} / \$${goal.targetAmount}  (Due: ${goal.dueDate ?? 'N/A'})"),
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
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final currentController = TextEditingController();
    final dueDateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Goal"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Target Amount"),
              ),
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Current Amount"),
              ),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(
                  labelText: "Due Date (YYYY-MM-DD)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newGoal = GoalModel(
                title: titleController.text,
                targetAmount: double.tryParse(targetController.text) ?? 0,
                currentAmount: double.tryParse(currentController.text) ?? 0,
                dueDate: dueDateController.text.isNotEmpty ? dueDateController.text : null,
                status: 'active'
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
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(text: goal.targetAmount.toString());
    final currentController = TextEditingController(text: goal.currentAmount.toString());
    final dueDateController = TextEditingController(text: goal.dueDate ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Goal"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Target Amount"),
              ),
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Current Amount"),
              ),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(
                  labelText: "Due Date (YYYY-MM-DD)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await GoalRepository.update(goal.id!, {
                "title": titleController.text,
                "target_amount": double.tryParse(targetController.text) ?? goal.targetAmount,
                "current_amount": double.tryParse(currentController.text) ?? goal.currentAmount,
                "due_date": dueDateController.text.isNotEmpty ? dueDateController.text : null,
              });
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
}
