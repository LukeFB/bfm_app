import 'package:flutter/material.dart';

const Color bfmBlue = Color(0xFF005494);
const Color bfmOrange = Color(0xFFFF6934);
const Color bfmBeige = Color(0xFFF5F5E1);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "You're on track!",
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: "Roboto",
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "\$34.8",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: bfmBlue,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Left to spend"),
                  Text("Weekly budget: \$100"),
                ],
              ),

              const SizedBox(height: 24),

              // Goals Snapshot
              _DashboardCard(
                title: "Savings Goals",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Textbooks", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.4, // 40% complete
                      color: Colors.blue,
                      backgroundColor: Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    const Text("40% of \$500 saved"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Alerts
              _DashboardCard(
                title: "Alerts",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("👉 You spent \$30 on Fortnite last month"),
                    SizedBox(height: 8),
                    Text("💡 StudyLink payment due in 3 days"),
                    SizedBox(height: 8),
                    Text("⚠️ Phone bill due in 4 days"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recent Activity
              _DashboardCard(
                title: "Recent Activity",
                child: Column(
                  children: const [
                    _ActivityItem(label: "Fortnite", amount: -10.00, date: "Mon"),
                    _ActivityItem(label: "Groceries", amount: -45.20, date: "Fri"),
                    _ActivityItem(label: "Rent", amount: -180.00, date: "Thur"),
                    _ActivityItem(label: "Savings", amount: -10.00, date: "Thur"),
                    _ActivityItem(label: "StudyLink Payment", amount: 280.00, date: "Wed"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Consistency Validation
              _DashboardCard(
                title: "Streaks",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Center(
                      child: Text(
                        "🔥3",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text("You’ve stayed under budget 3 weeks in a row!",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tips
              _DashboardCard(
                title: "Financial Tip",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "💡 Cook in bulk: Preparing meals ahead can save up to \$30 per week.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Upcoming Events
              _DashboardCard(
                title: "Upcoming Events",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("🎓 Orientation – Free sausage sizzle - in 2 days"),
                    SizedBox(height: 8),
                    Text("🥪 Food bank visit - Free food in room 1 - in 5 days"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        color: bfmBlue,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomBarButton(
              icon: Icons.add,
              label: "Transactions",
              onTap: () => Navigator.pushNamed(context, '/budget'),
            ),
            _BottomBarButton(
              icon: Icons.insights,
              label: "Insights",
              onTap: () => Navigator.pushNamed(context, '/insights'),
            ),
            _BottomBarButton(
              icon: Icons.flag,
              label: "Goals",
              onTap: () => Navigator.pushNamed(context, '/goals'),
            ),
            _BottomBarButton(
              icon: Icons.chat_bubble,
              label: "Moni AI",
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable card widget
class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashboardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// Bottom bar button
class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomBarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Activity row item
class _ActivityItem extends StatelessWidget {
  final String label;
  final double amount;
  final String date;
  const _ActivityItem({required this.label, required this.amount, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text("\$${amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: amount < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              )),
          Text(date, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
