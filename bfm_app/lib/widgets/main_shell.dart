import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/budgets_screen.dart';
import 'package:bfm_app/screens/savings_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;
  final bool elevated;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
    this.elevated = false,
  });
}

class MainShell extends StatefulWidget {
  final int initialPage;
  const MainShell({super.key, this.initialPage = 2});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late PageController _pageController;
  late int _currentIndex;

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.show_chart_rounded,
      activeIcon: Icons.show_chart_rounded,
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
      activeIcon: Icons.home_rounded,
      label: 'Home',
      screen: const DashboardScreen(embedded: true),
      elevated: true,
    ),
    _NavItem(
      icon: Icons.savings_outlined,
      activeIcon: Icons.savings,
      label: 'Savings',
      screen: const SavingsScreen(embedded: true),
    ),
    _NavItem(
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy,
      label: 'Buxly AI',
      screen: const ChatScreen(embedded: true),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentIndex = index);
  }

  void navigateToPage(int index) {
    if (index >= 0 && index < _navItems.length) _onNavItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BuxlyColors.offWhite,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          children: _navItems.map((item) => item.screen).toList(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: BuxlyColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: BuxlyColors.darkText.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, _buildNavItem),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isActive = _currentIndex == index;

    if (item.elevated) {
      return _buildElevatedNavItem(index, item, isActive);
    }

    final color = isActive ? BuxlyColors.teal : BuxlyColors.midGrey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
                fontFamily: BuxlyTheme.fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevatedNavItem(int index, _NavItem item, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isActive ? BuxlyColors.teal : BuxlyColors.teal.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: BuxlyColors.teal.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: BuxlyColors.white,
                  size: 28,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? BuxlyColors.teal : BuxlyColors.midGrey,
                  fontFamily: BuxlyTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
