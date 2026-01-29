/// ---------------------------------------------------------------------------
/// File: lib/screens/onboarding_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Polished onboarding flow that welcomes new users, explains Moni's value,
///     collects optional context, and connects their bank account.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/services/bank_service.dart';
import 'package:bfm_app/services/onboarding_store.dart';

class OnboardingScreen extends StatefulWidget {
  final String onCompleteRoute;

  const OnboardingScreen({super.key, this.onCompleteRoute = '/subscriptions'});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final OnboardingStore _store = OnboardingStore();

  // Form controllers
  final _ageCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _referrerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _bankAppTokenCtrl = TextEditingController();
  final _bankUserTokenCtrl = TextEditingController();

  int _currentPage = 0;
  bool _saving = false;
  bool _bankConnecting = false;
  bool _bankConnected = false;
  String? _bankConnectError;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Page indices
  static const int _welcomeIndex = 0;
  static const int _feature1Index = 1;
  static const int _feature2Index = 2;
  static const int _feature3Index = 3;
  static const int _aboutYouIndex = 4;
  static const int _yourWhyIndex = 5;
  static const int _privacyIndex = 6;
  static const int _bankConnectIndex = 7;
  static const int _totalPages = 8;

  @override
  void initState() {
    super.initState();
    _hydrateBankStatus();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  Future<void> _hydrateBankStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!mounted) return;
    setState(() => _bankConnected = connected);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _ageCtrl.dispose();
    _genderCtrl.dispose();
    _locationCtrl.dispose();
    _referrerCtrl.dispose();
    _reasonCtrl.dispose();
    _bankAppTokenCtrl.dispose();
    _bankUserTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _saving || _bankConnecting;
    final showBackButton = _currentPage > 0 && !isProcessing;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _OnboardingProgress(
              currentPage: _currentPage,
              totalPages: _totalPages,
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _fadeController.reset();
                  _fadeController.forward();
                },
                children: [
                  _buildWelcomePage(),
                  _buildTrackSpendingPage(),
                  _buildBudgetsPage(),
                  _buildFeaturePage(
                    icon: Icons.lightbulb_outline,
                    title: 'Get personalised guidance',
                    description:
                        'Your AI coach helps you stay on track and reach your goals.',
                  ),
                  _buildAboutYouPage(),
                  _buildYourWhyPage(),
                  _buildPrivacyPage(),
                  _buildBankConnectPage(),
                ],
              ),
            ),
            // Navigation buttons
            _buildNavigation(showBackButton, isProcessing),
            if (isProcessing) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(bool showBackButton, bool isProcessing) {
    final isWelcome = _currentPage == _welcomeIndex;
    final isBankConnect = _currentPage == _bankConnectIndex;
    final isSkippablePage =
        _currentPage == _aboutYouIndex || _currentPage == _yourWhyIndex;

    String nextLabel;
    IconData nextIcon;

    if (isWelcome) {
      nextLabel = 'Get started';
      nextIcon = Icons.arrow_forward;
    } else if (isBankConnect) {
      nextLabel = _bankConnected ? 'Continue' : 'Connect bank';
      nextIcon = _bankConnected ? Icons.arrow_forward : Icons.link;
    } else {
      nextLabel = 'Continue';
      nextIcon = Icons.arrow_forward;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        children: [
          if (showBackButton)
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          if (isSkippablePage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: isProcessing ? null : _goToNextPage,
                child: const Text('Skip'),
              ),
            ),
          FilledButton.icon(
            icon: Icon(nextIcon, size: 18),
            label: Text(nextLabel),
            onPressed: isProcessing ? null : _handleNext,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page Builders
  // ---------------------------------------------------------------------------

  Widget _buildWelcomePage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.savings_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome to Moni',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your personal money coach',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              "Let's set up your account in just a few steps.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black87,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackSpendingPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Track your spending',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'See exactly where your money goes with automatic categorisation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Demo insights chart
            const _DemoInsightsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Build smart budgets',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create weekly budgets based on your detected average spending.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Demo budget items
            const _DemoBudgetList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutYouPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A bit about you',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us tailor advice to your situation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            _StyledTextField(
              controller: _ageCtrl,
              label: 'Age',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _StyledTextField(
              controller: _genderCtrl,
              label: 'Gender',
            ),
            const SizedBox(height: 16),
            _StyledTextField(
              controller: _locationCtrl,
              label: 'Location',
              hint: 'City or region',
            ),
            const SizedBox(height: 16),
            _StyledTextField(
              controller: _referrerCtrl,
              label: 'Who referred you to Moni?',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourWhyPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your goals',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'What would you like help with?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            _StyledTextField(
              controller: _reasonCtrl,
              label: 'Share your situation',
              hint:
                  'e.g., I want to save for a holiday, pay off debt, or just get better at budgeting...',
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data is safe',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'We take your privacy seriously.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            _PrivacyCard(
              icon: Icons.phone_android_outlined,
              title: 'Stored on your device',
              description:
                  'Your financial data stays on your phone. Nothing is uploaded to external servers.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.lock_outline,
              title: 'Bank-grade security',
              description:
                  'We use Akahu, a trusted NZ service, to securely connect to your bank.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.visibility_off_outlined,
              title: 'We never see your login',
              description:
                  'Your bank credentials are handled directly by Akahu, not by us.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankConnectPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect your bank',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the Akahu tokens we provided to securely link your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            if (_bankConnected) ...[
              _SuccessBanner(
                icon: Icons.check_circle_outline,
                message: 'Your bank is connected! Tap Continue to proceed.',
              ),
            ] else ...[
              _StyledTextField(
                controller: _bankAppTokenCtrl,
                label: 'App Token',
                hint: 'X-Akahu-Id',
                enabled: !_bankConnecting,
                obscure: false,
              ),
              const SizedBox(height: 16),
              _StyledTextField(
                controller: _bankUserTokenCtrl,
                label: 'User Token',
                hint: 'Bearer token',
                enabled: !_bankConnecting,
                obscure: true,
              ),
              const SizedBox(height: 12),
              Text(
                'Tokens are stored securely on your device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                    ),
              ),
            ],
            if (_bankConnectError != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _bankConnectError!),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation Logic
  // ---------------------------------------------------------------------------

  void _handleNext() {
    if (_currentPage == _bankConnectIndex) {
      if (_bankConnected) {
        _completeOnboarding();
      } else {
        _handleBankConnect();
      }
      return;
    }
    _goToNextPage();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleBankConnect() async {
    if (_bankConnecting) return;

    final appToken = _bankAppTokenCtrl.text.trim();
    final userToken = _bankUserTokenCtrl.text.trim();

    if (appToken.isEmpty || userToken.isEmpty) {
      setState(() {
        _bankConnectError = 'Please enter both tokens to continue.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _bankConnecting = true;
      _bankConnectError = null;
    });

    try {
      await BankService.connect(appToken: appToken, userToken: userToken);
      if (!mounted) return;
      setState(() {
        _bankConnecting = false;
        _bankConnected = true;
      });
      // Auto-proceed after successful connection
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _completeOnboarding();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _bankConnecting = false;
        _bankConnectError = err is ArgumentError
            ? err.message ?? 'Unable to connect. Check your tokens.'
            : 'Connection failed. Please check your tokens and try again.';
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);

    final response = OnboardingResponse(
      age: _trimOrNull(_ageCtrl.text),
      gender: _trimOrNull(_genderCtrl.text),
      location: _trimOrNull(_locationCtrl.text),
      referrer: _trimOrNull(_referrerCtrl.text),
      mainReason: _trimOrNull(_reasonCtrl.text),
    );

    await _store.saveResponse(response);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, widget.onCompleteRoute);
  }

  String? _trimOrNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

// -----------------------------------------------------------------------------
// Shared Widgets
// -----------------------------------------------------------------------------

class _OnboardingProgress extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _OnboardingProgress({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(totalPages, (index) {
          final isActive = index <= currentPage;
          final isCurrent = index == currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              margin: EdgeInsets.only(right: index < totalPages - 1 ? 4 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black12,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PageShell extends StatelessWidget {
  final Widget child;
  final Alignment alignment;

  const _PageShell({
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: alignment == Alignment.center
              ? child
              : Align(alignment: alignment, child: child),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscure;

  const _StyledTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.enabled = true,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SuccessBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoInsightsChart extends StatelessWidget {
  const _DemoInsightsChart();

  @override
  Widget build(BuildContext context) {
    // Using actual NZFCC category names
    final demoData = [
      _DemoChartItem(
          '🍽️', 'Supermarkets and grocery stores', 0.35, const Color(0xFF4CAF50)),
      _DemoChartItem(
          '🏡', 'Rent for permanent accommodation', 0.28, const Color(0xFF2196F3)),
      _DemoChartItem('🚌', 'Fuel stations', 0.15, const Color(0xFFFF9800)),
      _DemoChartItem('⚡️', 'Electricity services', 0.12, const Color(0xFF9C27B0)),
      _DemoChartItem('🎉', 'Cafes and restaurants', 0.10, const Color(0xFFE91E63)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Horizontal bar chart
          for (final item in demoData) ...[
            _DemoChartBar(item: item),
            if (item != demoData.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DemoChartItem {
  final String emoji;
  final String label;
  final double percentage;
  final Color color;

  const _DemoChartItem(this.emoji, this.label, this.percentage, this.color);
}

class _DemoChartBar extends StatelessWidget {
  final _DemoChartItem item;

  const _DemoChartBar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(item.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(
            item.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade100,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item.percentage,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: item.color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${(item.percentage * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.5),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _DemoBudgetList extends StatelessWidget {
  const _DemoBudgetList();

  @override
  Widget build(BuildContext context) {
    // Using actual NZFCC category names
    final demoBudgets = [
      _DemoBudgetItem('🍽️', 'Supermarkets and grocery stores', 150.0),
      _DemoBudgetItem('🎉', 'Cafes and restaurants', 50.0),
      _DemoBudgetItem('🚌', 'Fuel stations', 80.0),
      _DemoBudgetItem('⚕️', 'Gyms, fitness, aquatic facilities, yoga, pilates', 40.0),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < demoBudgets.length; i++) ...[
            _DemoBudgetTile(item: demoBudgets[i]),
            if (i < demoBudgets.length - 1)
              Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          ],
        ],
      ),
    );
  }
}

class _DemoBudgetItem {
  final String emoji;
  final String label;
  final double budget;

  const _DemoBudgetItem(this.emoji, this.label, this.budget);
}

class _DemoBudgetTile extends StatelessWidget {
  final _DemoBudgetItem item;

  const _DemoBudgetTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        border: Border(
          left: BorderSide(
            width: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                        ),
                        child: Text(
                          '\$${item.budget.toStringAsFixed(0)}/week',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
                border: Border.all(
                  width: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
