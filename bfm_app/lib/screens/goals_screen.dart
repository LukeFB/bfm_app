import 'package:flutter/material.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Goals"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: open add goal form
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GoalCard(title: "Textbooks", progress: 0.4, contribution: 10, frequency: 7, target: 500),
          _GoalCard(title: "Car Savings", progress: 0.2, contribution: 10, frequency: 30, target: 2000),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final double progress;
  final double contribution;
  final double frequency;
  final double target;

  const _GoalCard({required this.title, required this.progress, required this.contribution, required this.frequency, required this.target});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: Colors.blue,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${(progress * 100).toStringAsFixed(0)}% of \$${target.toStringAsFixed(0)}"),
                  Text("\$${contribution.toStringAsFixed(0)} every ${frequency.toStringAsFixed(0)} days"),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
