/// ---------------------------------------------------------------------------
/// File: lib/widgets/main_shell.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Provides a Clash Royale-style swipeable navigation shell.
///   - Contains a PageView for horizontal swiping between screens.
///   - Bottom navigation bar syncs with the current page.
///   - Sticky top bar with settings and motivational message across all pages.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/budgets_screen.dart';
import 'package:bfm_app/screens/savings_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/services/dashboard_service.dart';

const Color bfmBlue = Color(0xFF005494);
const Color bfmOrange = Color(0xFFFF6934);

/// Navigation item data class.
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}

/// Main shell with swipeable PageView and synced bottom navigation.
class MainShell extends StatefulWidget {
  /// Optional initial page index (defaults to 2 for Dashboard).
  final int initialPage;

  const MainShell({super.key, this.initialPage = 2});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late PageController _pageController;
  late int _currentIndex;
  double _pageOffset = 2.0; // For smooth animation tracking
  
  // Data for sticky top bar
  double _leftToSpend = 0.0;
  double _totalWeeklyBudget = 0.0;
  bool _dataLoaded = false;

  /// Navigation items in order: Insights, Budget, Dashboard, Savings, Chat
  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'Insights',
      screen: const InsightsScreen(embedded: true),
    ),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Budget',
      screen: const BudgetsScreen(embedded: true),
    ),
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      screen: const DashboardScreen(embedded: true),
    ),
    _NavItem(
      icon: Icons.savings_outlined,
      activeIcon: Icons.savings,
      label: 'Savings',
      screen: const SavingsScreen(embedded: true),
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Moni AI',
      screen: const ChatScreen(embedded: true),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageOffset = widget.initialPage.toDouble();
    _pageController = PageController(initialPage: widget.initialPage);
    _pageController.addListener(_onPageScroll);
    _loadTopBarData();
  }

  /// Loads data needed for the sticky top bar (motivational message).
  Future<void> _loadTopBarData() async {
    try {
      final results = await Future.wait([
        DashboardService.getWeeklyIncome(),
        DashboardService.getTotalBudgeted(),
        DashboardService.getSpentOnBudgets(),
        DashboardService.getTotalExpensesThisWeek(),
        DashboardService.getGoalBudgetTotal(),
      ]);

      final weeklyIncome = results[0];
      final totalBudgeted = results[1];
      final spentOnBudgets = results[2];
      final totalExpenses = results[3];
      final goalBudgetTotal = results[4];

      // Calculate left to spend (goals subtracted separately from budget overspend)
      final budgetOverspend = (spentOnBudgets - totalBudgeted).clamp(0.0, double.infinity);
      final nonBudgetSpend = (totalExpenses - spentOnBudgets).clamp(0.0, double.infinity);
      final leftToSpend = weeklyIncome - totalBudgeted - goalBudgetTotal - budgetOverspend - nonBudgetSpend;

      if (mounted) {
        setState(() {
          _leftToSpend = leftToSpend;
          _totalWeeklyBudget = weeklyIncome - totalBudgeted - goalBudgetTotal;
          _dataLoaded = true;
        });
      }
    } catch (e) {
      // Silently fail - top bar will show default message
      if (mounted) {
        setState(() => _dataLoaded = true);
      }
    }
  }

  /// Friendly, dynamic header based on how much is left this week.
  String _headerMessage() {
    if (!_dataLoaded) return "Loading...";
    if (_totalWeeklyBudget <= 0) {
      return "Let's set up your budget and make a plan 🚀";
    }
    if (_leftToSpend < 0) {
      return "Slightly over — no stress. Fresh week, fresh start";
    }
    final ratio = _leftToSpend / _totalWeeklyBudget;
    if (ratio >= 0.75) return "Crushing it — plenty left this week 💪";
    if (ratio >= 0.50) return "You're on track! 🌟";
    if (ratio >= 0.25) return "You're doing fine — keep an eye on it 👀";
    if (ratio >= 0.10) return "Tight but doable — small choices win 💡";
    return "Almost tapped out — press pause on extras if you can ⏸️";
  }

  /// Refreshes the top bar data (called when returning from settings, etc.).
  void refreshTopBarData() {
    _loadTopBarData();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// Updates the page offset for smooth indicator animation.
  void _onPageScroll() {
    if (_pageController.hasClients && _pageController.page != null) {
      setState(() {
        _pageOffset = _pageController.page!;
      });
    }
  }

  /// Called when a nav item is tapped.
  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Called when page swipe completes.
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Navigate to a specific page by index (can be called from child screens).
  void navigateToPage(int index) {
    if (index >= 0 && index < _navItems.length) {
      _onNavItemTapped(index);
    }
  }

  /// Opens settings and refreshes data when returning.
  Future<void> _openSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (mounted) {
      _loadTopBarData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------- STICKY TOP BAR ----------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _headerMessage(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: "Roboto",
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
            // ---------- SWIPEABLE PAGES ----------
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: _navItems.map((item) => item.screen).toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// Builds the custom bottom navigation bar with smooth animations.
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: bfmBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              return _buildNavItem(index);
            }),
          ),
        ),
      ),
    );
  }

  /// Builds an individual nav item with animated selection state.
  Widget _buildNavItem(int index) {
    // Calculate how "selected" this item is (0.0 to 1.0) based on page scroll
    final distance = (_pageOffset - index).abs();
    final selected = (1.0 - distance).clamp(0.0, 1.0);
    final isCurrentPage = _currentIndex == index;

    final item = _navItems[index];

    // Interpolate colors and sizes based on selection
    final iconColor = Color.lerp(
      Colors.white.withOpacity(0.5),
      Colors.white,
      selected,
    )!;
    final labelColor = Color.lerp(
      Colors.white.withOpacity(0.5),
      Colors.white,
      selected,
    )!;
    final iconSize = 22.0 + (6.0 * selected); // 22 -> 28 when selected
    final labelSize = 9.0 + (3.0 * selected); // 9 -> 12 when selected
    final scale = 0.85 + (0.15 * selected); // 0.85 -> 1.0 scale

    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection indicator pill with glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: isCurrentPage ? 28 : 0,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: bfmOrange,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isCurrentPage
                      ? [
                          BoxShadow(
                            color: bfmOrange.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              // Icon with glow effect when selected
              Container(
                decoration: isCurrentPage
                    ? BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: Icon(
                  selected > 0.5 ? item.activeIcon : item.icon,
                  color: iconColor,
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                item.label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: labelSize,
                  fontWeight: selected > 0.5 ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
