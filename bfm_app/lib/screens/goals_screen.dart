import 'package:bfm_app/screens/dashboard_screen.dart';
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
          GoalCard(
            title: "Textbooks",
            progress: 0.4,
            contribution: 20,
            frequency: 7,
            target: 200,
          ),
          GoalCard(
            title: "Car Savings",
            progress: 0.2,
            contribution: 10,
            frequency: 30,
            target: 2000,
          ),
        ],
      ),
    );
  }
}

class GoalCard extends StatefulWidget {
  final String title;
  final double progress;
  final double contribution;
  final double frequency;
  final double target;

  const GoalCard({
    super.key,
    required this.title,
    required this.progress,
    required this.contribution,
    required this.frequency,
    required this.target,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool showOnDashboard = true; // default: visible

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + toggle in same row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    const Text("Dashboard"),
                    Switch(
                      value: showOnDashboard,
                      activeTrackColor: bfmBlue,   // track when ON
                      inactiveThumbColor: Colors.grey,      // knob when OFF
                      inactiveTrackColor: Colors.grey[300], // track when OFF
                      onChanged: (val) {
                        setState(() {
                          showOnDashboard = val;
                          // TODO: save to DB (dashboardVisible field)
                        });
                      },
                    ),
                  ],
                )
              ],
            ),

            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.progress,
              color: Colors.blue,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "${(widget.progress * 100).toStringAsFixed(0)}% of \$${widget.target.toStringAsFixed(0)}"),
                Text(
                    "\$${widget.contribution.toStringAsFixed(0)} every ${widget.frequency.toStringAsFixed(0)} days"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
