/// ---------------------------------------------------------------------------
/// File: lib/screens/onboarding_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Multi-step onboarding flow that collects registration details, referrer
///     token, configures the account, explains core app features, and prompts
///     for an initial Akahu bank connection.
///
/// Backend data structure (assembled in _completeOnboarding):
///   See OnboardingResponse.toJson() in models/onboarding_response.dart
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

  // Registration form
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  DateTime? _selectedDob;

  // Referrer token
  final _referrerTokenCtrl = TextEditingController();

  // Account setup
  String? _incomeFrequency;
  String? _primaryGoal;

  // Akahu
  final _bankAppTokenCtrl = TextEditingController();
  final _bankUserTokenCtrl = TextEditingController();

  int _currentPage = 0;
  bool _saving = false;
  bool _bankConnecting = false;
  bool _bankConnected = false;
  String? _bankConnectError;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const int _registrationIndex = 0;
  static const int _referrerTokenIndex = 1;
  static const int _accountSetupIndex = 2;
  static const int _appExplainIndex = 3;
  static const int _akahuConnectIndex = 4;
  static const int _recurringExplainIndex = 5;
  static const int _categorisationExplainIndex = 6;
  static const int _budgetExplainIndex = 7;
  static const int _totalPages = 8;

  static const _incomeOptions = [
    ('weekly', 'Weekly'),
    ('fortnightly', 'Fortnightly'),
    ('monthly', 'Monthly'),
    ('irregular', 'Irregular / Varies'),
  ];

  static const _goalOptions = [
    ('save_more', 'Save more money'),
    ('pay_debt', 'Pay off debt'),
    ('budget_better', 'Get better at budgeting'),
    ('track_spending', 'Track my spending'),
    ('grow_wealth', 'Grow my wealth'),
  ];

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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _referrerTokenCtrl.dispose();
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
            _OnboardingProgress(
              currentPage: _currentPage,
              totalPages: _totalPages,
            ),
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
                  _buildRegistrationPage(),
                  _buildReferrerTokenPage(),
                  _buildAccountSetupPage(),
                  _buildAppExplainPage(),
                  _buildAkahuConnectPage(),
                  _buildRecurringExplainPage(),
                  _buildCategorisationExplainPage(),
                  _buildBudgetExplainPage(),
                ],
              ),
            ),
            _buildNavigation(showBackButton, isProcessing),
            if (isProcessing) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Widget _buildNavigation(bool showBackButton, bool isProcessing) {
    final isRegistration = _currentPage == _registrationIndex;
    final isAkahuConnect = _currentPage == _akahuConnectIndex;
    final isFinalPage = _currentPage == _budgetExplainIndex;
    final isReferrerPage = _currentPage == _referrerTokenIndex;

    String nextLabel;
    IconData nextIcon;

    if (isRegistration) {
      nextLabel = 'Continue';
      nextIcon = Icons.arrow_forward;
    } else if (isAkahuConnect) {
      nextLabel = _bankConnected ? 'Continue' : 'Connect bank';
      nextIcon = _bankConnected ? Icons.arrow_forward : Icons.link;
    } else if (isFinalPage) {
      nextLabel = 'Get started';
      nextIcon = Icons.check;
    } else {
      nextLabel = 'Continue';
      nextIcon = Icons.arrow_forward;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
          if (isReferrerPage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: isProcessing ? null : _goToNextPage,
                child: const Text('Skip'),
              ),
            ),
          if (isAkahuConnect && !_bankConnected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: isProcessing ? null : _goToNextPage,
                child: const Text('Skip'),
              ),
            ),
          Flexible(
            child: FilledButton.icon(
              icon: Icon(nextIcon, size: 18),
              label: Text(nextLabel, overflow: TextOverflow.ellipsis),
              onPressed: isProcessing ? null : _handleNext,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (_currentPage == _registrationIndex) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentPage == _akahuConnectIndex) {
      if (_bankConnected) {
        _goToNextPage();
      } else {
        _handleBankConnect();
      }
      return;
    }
    if (_currentPage == _budgetExplainIndex) {
      _completeOnboarding();
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

  // ---------------------------------------------------------------------------
  // Page 0 – Registration
  // ---------------------------------------------------------------------------

  Widget _buildRegistrationPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        scrollable: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We need a few details to set up your profile.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StyledFormField(
                      controller: _firstNameCtrl,
                      label: 'First name',
                      validator: _requiredValidator('First name is required'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StyledFormField(
                      controller: _lastNameCtrl,
                      label: 'Last name',
                      validator: _requiredValidator('Last name is required'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StyledFormField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _StyledFormField(
                controller: _phoneCtrl,
                label: 'Phone number',
                hint: 'Optional',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickDateOfBirth,
                child: AbsorbPointer(
                  child: _StyledFormField(
                    controller: _dobCtrl,
                    label: 'Date of birth',
                    hint: 'Tap to select',
                    suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 1 – White-Label Referrer Token
  // ---------------------------------------------------------------------------

  Widget _buildReferrerTokenPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Have a referrer code?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'If your organisation or advisor gave you a code, enter it below to link your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _StyledTextField(
              controller: _referrerTokenCtrl,
              label: 'Referrer token',
              hint: 'e.g. WL-ABC123',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 2 – Account Setup Wizard
  // ---------------------------------------------------------------------------

  Widget _buildAccountSetupPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up your account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'A few quick preferences so Moni works best for you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'How often do you get paid?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ..._incomeOptions.map((opt) => _SelectionTile(
                  label: opt.$2,
                  selected: _incomeFrequency == opt.$1,
                  onTap: () => setState(() => _incomeFrequency = opt.$1),
                )),
            const SizedBox(height: 16),
            Text(
              'What is your main financial goal?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ..._goalOptions.map((opt) => _SelectionTile(
                  label: opt.$2,
                  selected: _primaryGoal == opt.$1,
                  onTap: () => setState(() => _primaryGoal = opt.$1),
                )),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 3 – App Explanation
  // ---------------------------------------------------------------------------

  Widget _buildAppExplainPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.savings_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Moni',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your financial personal trainer',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.black54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ExplainerCard(
              icon: Icons.trending_down,
              title: 'Track, budget & reduce',
              description:
                  'Creates budgets based on your average spending and works with you to reduce them.',
            ),
            const SizedBox(height: 8),
            _ExplainerCard(
              icon: Icons.sync_alt,
              title: 'Automatic bank syncing',
              description:
                  'Connects securely to your bank via Akahu and pulls in transactions automatically.',
            ),
            const SizedBox(height: 8),
            _ExplainerCard(
              icon: Icons.pie_chart_outline,
              title: 'Spending insights',
              description:
                  'See where your money goes with intelligent categorisation and weekly breakdowns.',
            ),
            const SizedBox(height: 8),
            _ExplainerCard(
              icon: Icons.lightbulb_outline,
              title: 'AI-powered guidance',
              description:
                  'Chat with your personal money coach to get tailored advice and stay on track.',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 4 – Akahu Connection
  // ---------------------------------------------------------------------------

  Widget _buildAkahuConnectPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        scrollable: true,
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
              'Moni uses Akahu to securely read your transactions. Enter the tokens provided to you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            if (_bankConnected) ...[
              _SuccessBanner(
                icon: Icons.check_circle_outline,
                message: 'Your bank is connected! Tap Continue to proceed.',
              ),
            ] else ...[
              _ExplainerCard(
                icon: Icons.lock_outline,
                title: 'Bank-grade security',
                description:
                    'Akahu is a trusted NZ open-finance provider. Your login credentials are never shared with Moni.',
              ),
              const SizedBox(height: 20),
              _StyledTextField(
                controller: _bankAppTokenCtrl,
                label: 'App Token',
                hint: 'X-Akahu-Id',
                enabled: !_bankConnecting,
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
  // Page 5 – Recurring Transactions Explanation
  // ---------------------------------------------------------------------------

  Widget _buildRecurringExplainPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6934).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.replay,
                size: 36,
                color: Color(0xFFFF6934),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recurring transactions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Moni automatically detects your regular payments like rent, subscriptions, and bills.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ExplainerCard(
              icon: Icons.auto_awesome,
              title: 'Smart detection',
              description:
                  'Analyses your transaction history to find repeating payments and their frequency.',
            ),
            const SizedBox(height: 8),
            _ExplainerCard(
              icon: Icons.notifications_active_outlined,
              title: 'Stay ahead of bills',
              description:
                  'Get notified before upcoming payments so you always have enough in your account.',
            ),
            const SizedBox(height: 8),
            _ExplainerCard(
              icon: Icons.cancel_outlined,
              title: 'Cut what you don\'t need',
              description:
                  'Identify your essential recurring payments and cancel the rest.',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 6 – Categorisation Explanation
  // ---------------------------------------------------------------------------

  Widget _buildCategorisationExplainPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 36,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Transaction categorisation',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Every transaction is automatically sorted into a spending category so you know exactly where your money is going.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const _DemoInsightsChart(),
            const SizedBox(height: 12),
            _ExplainerCard(
              icon: Icons.tune,
              title: 'NZ-specific categories',
              description:
                  'Based on the NZ Financial Capability Census to match real Kiwi spending patterns.',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page 7 – Budgets Explanation
  // ---------------------------------------------------------------------------

  Widget _buildBudgetExplainPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _PageShell(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Build smart budgets',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Moni suggests budgets based on your average spending to start with a realistic plan and will work with you to reduce these budgets.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const _DemoBudgetList(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bank Connection Logic
  // ---------------------------------------------------------------------------

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
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _goToNextPage();
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

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);

    final response = OnboardingResponse(
      registration: OnboardingRegistration(
        firstName: _trimOrNull(_firstNameCtrl.text),
        lastName: _trimOrNull(_lastNameCtrl.text),
        email: _trimOrNull(_emailCtrl.text),
        phone: _trimOrNull(_phoneCtrl.text),
        dateOfBirth: _trimOrNull(_dobCtrl.text),
      ),
      referrerToken: _trimOrNull(_referrerTokenCtrl.text),
      accountSetup: OnboardingAccountSetup(
        incomeFrequency: _incomeFrequency,
        primaryGoal: _primaryGoal,
      ),
      akahuConnected: _bankConnected,
      completedAt: DateTime.now().toUtc().toIso8601String(),
    );

    // TODO: POST response.toJson() to backend registration endpoint
    debugPrint('--- Onboarding payload (backend-ready) ---');
    debugPrint(response.toJson().toString());

    await _store.saveResponse(response);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, widget.onCompleteRoute);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  String? _trimOrNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(totalPages, (index) {
          final isActive = index <= currentPage;
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
  final bool scrollable;

  const _PageShell({
    required this.child,
    this.alignment = Alignment.topLeft,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: alignment == Alignment.center
            ? child
            : Align(alignment: alignment, child: child),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: inner,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: inner,
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

class _StyledFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  const _StyledFormField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? primary.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? primary : Colors.black.withOpacity(0.08),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? primary : Colors.black87,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: primary, size: 22)
                else
                  Icon(Icons.circle_outlined, color: Colors.black26, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ExplainerCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.3,
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

// =============================================================================
// Demo Widgets (reused from previous onboarding for visual context)
// =============================================================================

class _DemoInsightsChart extends StatelessWidget {
  const _DemoInsightsChart();

  @override
  Widget build(BuildContext context) {
    final demoData = [
      _DemoChartItem(
          '🍽️', 'Supermarkets & grocery', 0.35, const Color(0xFF4CAF50)),
      _DemoChartItem(
          '🏡', 'Rent', 0.28, const Color(0xFF2196F3)),
      _DemoChartItem('🚌', 'Fuel', 0.15, const Color(0xFFFF9800)),
      _DemoChartItem('⚡️', 'Electricity', 0.12, const Color(0xFF9C27B0)),
      _DemoChartItem('🎉', 'Cafes & restaurants', 0.10, const Color(0xFFE91E63)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (final item in demoData) ...[
            _DemoChartBar(item: item),
            if (item != demoData.last) const SizedBox(height: 8),
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
    final demoBudgets = [
      _DemoBudgetItem('🍽️', 'Supermarkets & grocery', 150.0),
      _DemoBudgetItem('🎉', 'Cafes & restaurants', 50.0),
      _DemoBudgetItem('🚌', 'Fuel', 80.0),
      _DemoBudgetItem('⚕️', 'Gym & fitness', 40.0),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
