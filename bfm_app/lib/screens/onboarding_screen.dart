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

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bfm_app/api/api_client.dart';
import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/providers/api_providers.dart';
import 'package:bfm_app/repositories/account_repository.dart';
import 'package:bfm_app/repositories/transaction_repository.dart';
import 'package:bfm_app/services/budget_analysis_service.dart';
import 'package:bfm_app/services/bank_service.dart';
import 'package:bfm_app/services/income_settings_store.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/services/transaction_sync_service.dart';

/// How the user connects their bank during onboarding.
enum _AkahuConnectMode { webflow, manualTokens }

class OnboardingScreen extends StatefulWidget {
  final String onCompleteRoute;

  /// When true, skips registration + Akahu connect and starts at the data
  /// processing pages (recurring, categorisation, budgets). Re-syncs
  /// transactions before showing those pages.
  final bool replayMode;

  const OnboardingScreen({
    super.key,
    this.onCompleteRoute = '/subscriptions',
    this.replayMode = false,
  });

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

  // Akahu – manual token entry (dev/test)
  final _bankAppTokenCtrl = TextEditingController();
  final _bankUserTokenCtrl = TextEditingController();

  // Akahu – webflow (production)
  _AkahuConnectMode _connectMode = _AkahuConnectMode.webflow;
  bool _webflowLaunched = false;
  bool _verifyingConnection = false;
  int _backendAccountCount = 0;
  int _backendTxnCount = 0;

  // Backend auth state
  bool _backendAuthed = false;
  bool _backendAuthLoading = false;
  String? _backendAuthError;
  bool _isLoginMode = false;
  final _authPasswordCtrl = TextEditingController();
  final _authConfirmPasswordCtrl = TextEditingController();

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
    ('SaveMore', 'Save more money'),
    ('PayDebt', 'Pay off debt'),
    ('BudgetBetter', 'Get better at budgeting'),
    ('TrackSpending', 'Track my spending'),
    ('GrowWealth', 'Grow my wealth'),
  ];

  bool _replaySyncing = false;

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

    if (widget.replayMode) {
      _backendAuthed = true;
      _bankConnected = true;
      _replaySyncTransactions();
    }
  }

  /// In replay mode, re-pull transactions from the backend before showing
  /// the recurring / categorisation / budget pages.
  Future<void> _replaySyncTransactions() async {
    setState(() => _replaySyncing = true);
    try {
      await TransactionSyncService().syncNow(forceRefresh: true);
    } catch (e) {
      debugPrint('Replay sync error: $e');
    }
    if (!mounted) return;
    setState(() => _replaySyncing = false);
  }

  Future<void> _hydrateBankStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('bank_connected') ?? false;
    if (!mounted) return;
    setState(() => _bankConnected = connected);

    // Check if we already have a backend JWT (e.g. from a previous session)
    try {
      final container = ProviderScope.containerOf(context);
      final tokenStore = container.read(tokenStoreProvider);
      final token = await tokenStore.getToken();
      if (token != null && token.isNotEmpty && mounted) {
        setState(() => _backendAuthed = true);
      }
    } catch (_) {
      // ProviderScope not ready yet, will check later
    }
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
    _authPasswordCtrl.dispose();
    _authConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  /// Pages shown in replay mode (skip registration + Akahu connect).
  static const int _replayPageCount = 3; // recurring, categorisation, budget

  @override
  Widget build(BuildContext context) {
    if (widget.replayMode) return _buildReplayMode(context);

    final isProcessing = _saving || _bankConnecting || _verifyingConnection || _backendAuthLoading;
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
                  setState(() {
                    _currentPage = index;
                    _backendAuthError = null;
                  });
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

  /// Replay mode: sync → recurring → categorisation → budgets → done.
  Widget _buildReplayMode(BuildContext context) {
    final isLast = _currentPage == _replayPageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingProgress(
              currentPage: _currentPage,
              totalPages: _replayPageCount,
            ),
            if (_replaySyncing) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Syncing your latest transactions...'),
                    ],
                  ),
                ),
              ),
            ] else ...[
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
                    _buildRecurringExplainPage(),
                    _buildCategorisationExplainPage(),
                    _buildBudgetExplainPage(),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
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
                  FilledButton.icon(
                    icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
                    label: Text(isLast ? 'Done' : 'Continue'),
                    onPressed: _replaySyncing
                        ? null
                        : () {
                            if (isLast) {
                              _completeReplay();
                            } else {
                              _goToNextPage();
                            }
                          },
                  ),
                ],
              ),
            ),
            if (_replaySyncing) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  /// Finishes replay mode – routes to subscriptions then budget build.
  Future<void> _completeReplay() async {
    if (_saving) return;
    setState(() => _saving = true);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, '/subscriptions');
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
      if (_backendAuthLoading) {
        nextLabel = _isLoginMode ? 'Signing in…' : 'Creating account…';
        nextIcon = Icons.hourglass_empty;
      } else {
        nextLabel = _isLoginMode ? 'Sign in' : 'Continue';
        nextIcon = _isLoginMode ? Icons.login : Icons.arrow_forward;
      }
    } else if (isAkahuConnect) {
      if (_bankConnected) {
        nextLabel = 'Continue';
        nextIcon = Icons.arrow_forward;
      } else if (_connectMode == _AkahuConnectMode.webflow && _webflowLaunched) {
        nextLabel = "I've connected";
        nextIcon = Icons.check_circle_outline;
      } else {
        nextLabel = 'Connect bank';
        nextIcon = Icons.link;
      }
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
      if (!_isLoginMode) {
        if (!_formKey.currentState!.validate()) return;
      } else {
        // In login mode, only validate email + password
        final email = _emailCtrl.text.trim();
        final pass = _authPasswordCtrl.text.trim();
        if (email.isEmpty || pass.isEmpty) {
          setState(() => _backendAuthError = 'Email and password are required.');
          return;
        }
      }
      _handleRegistration();
      return;
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

  /// Handles the Continue/Sign in tap on the registration page.
  Future<void> _handleRegistration() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_backendAuthed && !_isLoginMode) {
      _goToNextPage();
      return;
    }

    if (_isLoginMode) {
      await _handleLogin();
    } else {
      await _handleBackendAuth();
      if (_backendAuthed && mounted) {
        _goToNextPage();
      }
    }
  }

  /// Login flow: authenticate → check Akahu connection → sync data →
  /// jump to the appropriate page.
  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _authPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _backendAuthError = 'Email and password are required.');
      return;
    }

    setState(() {
      _backendAuthLoading = true;
      _backendAuthError = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final authApi = container.read(authApiProvider);
      final tokenStore = container.read(tokenStoreProvider);
      final akahuApi = container.read(akahuApiProvider);

      // Clear any stale JWT so the login request goes out clean
      await tokenStore.clear();

      final token = await authApi.login(email: email, password: password);
      await tokenStore.setToken(token);

      if (!mounted) return;
      setState(() {
        _backendAuthed = true;
        _backendAuthLoading = false;
      });

      // Check if Akahu is already connected
      List<Map<String, dynamic>> accounts = [];
      try {
        accounts = await akahuApi.accounts();
      } catch (_) {}

      if (!mounted) return;

      if (accounts.isNotEmpty) {
        setState(() {
          _bankConnected = true;
          _backendAuthLoading = true;
        });

        // Mark connected BEFORE any DB writes
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('bank_connected', true);
        await prefs.remove('last_sync_at');

        // Store accounts directly (same as webflow verify & manual token paths)
        await AccountRepository.upsertFromAkahu(accounts);

        // Pull transactions using the same provider client the debug screen uses
        List<Map<String, dynamic>> txnPayloads = [];
        try {
          txnPayloads = await akahuApi.transactions();
        } catch (e) {
          debugPrint('Login txn fetch error: $e');
        }

        if (txnPayloads.isNotEmpty) {
          // This calls TransactionModel.fromAkahu → _resolveCategoryId →
          // CategoryRepository.ensureByName — exact same pipeline as manual tokens
          await TransactionRepository.upsertFromAkahu(txnPayloads);
        }

        debugPrint('Login sync: ${accounts.length} accounts, '
            '${txnPayloads.length} transactions upserted to local DB');

        // Same post-processing as manual token flow
        await IncomeSettingsStore.detectAndSetIncomeType();
        await BudgetAnalysisService.identifyRecurringTransactions();

        if (!mounted) return;
        setState(() => _backendAuthLoading = false);

        _pageController.jumpToPage(_recurringExplainIndex);
      } else {
        // Not connected – jump to Akahu connect (skip profile pages)
        _pageController.jumpToPage(_akahuConnectIndex);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _backendAuthLoading = false;
        _backendAuthError = _friendlyAuthError(err);
      });
    }
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
                _isLoginMode ? 'Sign in' : 'Create your account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginMode
                    ? 'Sign in with your existing account.'
                    : 'We need a few details to set up your profile.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 20),
              if (!_isLoginMode) ...[
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
              ],
              _StyledFormField(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
                textInputAction: TextInputAction.next,
              ),
              if (!_isLoginMode) ...[
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
              const SizedBox(height: 16),
              _StyledFormField(
                controller: _authPasswordCtrl,
                label: 'Password',
                hint: _isLoginMode ? '' : 'Min 8 characters',
                obscureText: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Password is required';
                  }
                  if (!_isLoginMode && v.trim().length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
                textInputAction: _isLoginMode ? TextInputAction.done : TextInputAction.next,
              ),
              if (!_isLoginMode) ...[
                const SizedBox(height: 16),
                _StyledFormField(
                  controller: _authConfirmPasswordCtrl,
                  label: 'Confirm password',
                  obscureText: true,
                  validator: (v) {
                    if (v != _authPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                ),
              ],
              if (_backendAuthError != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _backendAuthError!),
              ],
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _backendAuthLoading
                      ? null
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _backendAuthError = null;
                          });
                        },
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Register"
                        : 'Already have an account? Sign in',
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
              _connectMode == _AkahuConnectMode.webflow
                  ? 'Moni uses Akahu to securely read your transactions. '
                    'Tap the button below to connect through your bank\'s login.'
                  : 'Moni uses Akahu to securely read your transactions. '
                    'Enter the tokens provided to you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),

            // ── Connected state ──
            if (_bankConnected) ...[
              _SuccessBanner(
                icon: Icons.check_circle_outline,
                message: _backendAccountCount > 0
                    ? 'Connected! $_backendAccountCount account(s) found.'
                      '${_backendTxnCount > 0 ? ' $_backendTxnCount transaction(s) loaded.' : ' Transactions will sync shortly.'}'
                    : 'Your bank is connected! Tap Continue to proceed.',
              ),
            ]

            // ── Webflow mode (production) ──
            else if (_connectMode == _AkahuConnectMode.webflow) ...[
              _ExplainerCard(
                icon: Icons.lock_outline,
                title: 'Bank-grade security',
                description:
                    'Akahu is a trusted NZ open-finance provider. '
                    'Your login credentials are never shared with Moni.',
              ),
              const SizedBox(height: 24),

              if (!_webflowLaunched) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _bankConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.open_in_browser),
                    label: const Text('Connect with Akahu'),
                    onPressed: _bankConnecting ? null : _handleWebflowConnect,
                  ),
                ),
              ]

              // Step 3: Verify + pull data
              else ...[
                _ExplainerCard(
                  icon: Icons.open_in_browser,
                  title: 'Complete the connection in your browser',
                  description:
                      'Sign in to your bank through Akahu, then come '
                      'back here and tap "I\'ve connected".',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _verifyingConnection
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _verifyingConnection
                          ? 'Checking connection...'
                          : 'I\'ve connected my bank',
                    ),
                    onPressed:
                        _verifyingConnection ? null : _handleWebflowVerify,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _bankConnecting ? null : _handleWebflowConnect,
                    child: const Text('Re-open Akahu'),
                  ),
                ),
              ],
            ]

            // ── Manual tokens mode (dev/test) ──
            else ...[
              _ExplainerCard(
                icon: Icons.lock_outline,
                title: 'Bank-grade security',
                description:
                    'Akahu is a trusted NZ open-finance provider. '
                    'Your login credentials are never shared with Moni.',
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

            // ── Mode toggle (small link at the bottom) ──
            if (!_bankConnected) ...[
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  icon: Icon(
                    _connectMode == _AkahuConnectMode.webflow
                        ? Icons.code
                        : Icons.open_in_browser,
                    size: 16,
                  ),
                  label: Text(
                    _connectMode == _AkahuConnectMode.webflow
                        ? 'Use manual tokens (dev)'
                        : 'Use Akahu webflow',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _bankConnecting
                      ? null
                      : () {
                          setState(() {
                            _connectMode =
                                _connectMode == _AkahuConnectMode.webflow
                                    ? _AkahuConnectMode.manualTokens
                                    : _AkahuConnectMode.webflow;
                            _bankConnectError = null;
                          });
                        },
                ),
              ),
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

  // ── Backend auth (register / login) ────────────────────────────────────────

  /// Registers (or logs in) with the backend using the credentials from the
  /// registration page. Called automatically when the user taps "Connect bank".
  Future<void> _handleBackendAuth() async {
    if (_backendAuthLoading) return;

    final email = _emailCtrl.text.trim();
    final password = _authPasswordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _backendAuthError = 'Please go back and fill in your email and password on the registration page.';
      });
      return;
    }

    setState(() {
      _backendAuthLoading = true;
      _backendAuthError = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final authApi = container.read(authApiProvider);
      final tokenStore = container.read(tokenStoreProvider);

      final profilePayload = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim().isNotEmpty
            ? _firstNameCtrl.text.trim()
            : 'User',
        if (_lastNameCtrl.text.trim().isNotEmpty)
          'last_name': _lastNameCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_selectedDob != null)
          'date_of_birth':
              '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}',
        if (_incomeFrequency != null && _incomeFrequency!.isNotEmpty)
          'income_frequency': _incomeFrequency,
        if (_primaryGoal != null && _primaryGoal!.isNotEmpty)
          'primary_goal': _primaryGoal,
        if (_referrerTokenCtrl.text.trim().isNotEmpty)
          'referrer_token': _referrerTokenCtrl.text.trim(),
      };

      String token;
      bool didLogin = false;
      try {
        token = await authApi.register(
          email: email,
          password: password,
          passwordConfirmation: password,
          firstName: profilePayload['first_name'] as String,
          lastName: profilePayload['last_name'] as String?,
          phone: profilePayload['phone'] as String?,
          dateOfBirth: profilePayload['date_of_birth'] as String?,
          incomeFrequency: profilePayload['income_frequency'] as String?,
          primaryGoal: profilePayload['primary_goal'] as String?,
          referrerToken: profilePayload['referrer_token'] as String?,
        );
      } on DioException catch (e) {
        final body = e.response?.data;
        final isAlreadyTaken = e.response?.statusCode == 422 &&
            body.toString().contains('taken');
        if (isAlreadyTaken) {
          try {
            token = await authApi.login(email: email, password: password);
            didLogin = true;
          } on DioException catch (_) {
            throw Exception(
              'An account with this email already exists. '
              'Please use the password you originally registered with, '
              'or use a different email address.',
            );
          }
        } else {
          rethrow;
        }
      }

      await tokenStore.setToken(token);

      // When we fell back to login, the backend didn't get the onboarding
      // profile data (register sends it, login doesn't). Push it now.
      if (didLogin) {
        try {
          final profileApi = container.read(profileApiProvider);
          await profileApi.onboarding(profilePayload);
        } catch (_) {
          // Non-fatal: profile update can be retried later
        }
      }

      if (!mounted) return;
      setState(() {
        _backendAuthLoading = false;
        _backendAuthed = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _backendAuthLoading = false;
        _backendAuthError = _friendlyAuthError(err);
      });
    }
  }

  /// Extracts a human-readable message from auth errors.
  String _friendlyAuthError(Object err) {
    // Pull the actual server message from DioException response
    if (err is DioException && err.response?.data != null) {
      final data = err.response!.data;
      final status = err.response!.statusCode ?? 0;

      if (data is Map<String, dynamic>) {
        // Laravel validation: { "message": "...", "errors": { "email": [...] } }
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final messages = <String>[];
          for (final entry in errors.entries) {
            final fieldErrors = entry.value;
            if (fieldErrors is List) {
              messages.addAll(fieldErrors.map((e) => e.toString()));
            }
          }
          if (messages.isNotEmpty) return messages.join('\n');
        }

        // Simple message field
        final message = data['message'] ?? data['error'];
        if (message is String && message.isNotEmpty) return message;
      }

      if (data is String && data.isNotEmpty) {
        final trimmed = data.length > 200 ? '${data.substring(0, 197)}...' : data;
        return trimmed;
      }

      if (status == 401) return 'Invalid email or password.';
      if (status == 422) return 'Please check your details and try again.';
      return 'Server error ($status). Please try again.';
    }

    final msg = err.toString();
    if (msg.contains('No access_token')) {
      return 'Server did not return a token. Please try again.';
    }
    // Surface the message from plain Exceptions (e.g. "already exists" fallback)
    if (err is Exception) {
      final cleaned = msg.replaceFirst('Exception: ', '');
      if (cleaned.isNotEmpty) return cleaned;
    }
    return 'Connection failed. Please check your internet and try again.';
  }

  // ── Akahu bank connection ─────────────────────────────────────────────────

  /// Dispatches to the correct connect flow based on [_connectMode].
  Future<void> _handleBankConnect() async {
    if (_connectMode == _AkahuConnectMode.webflow) {
      if (_webflowLaunched) {
        await _handleWebflowVerify();
      } else {
        await _handleWebflowConnect();
      }
    } else {
      await _handleManualTokenConnect();
    }
  }

  // ── Webflow (production) ──────────────────────────────────────────────────

  /// Step 1: Call /akahu/connect on the backend and open the URL.
  /// If the JWT has expired (401), re-authenticates and retries once.
  Future<void> _handleWebflowConnect() async {
    if (_bankConnecting) return;

    setState(() {
      _bankConnecting = true;
      _bankConnectError = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final akahuApi = container.read(akahuApiProvider);

      Uri url;
      try {
        url = await akahuApi.connectUrl();
      } on DioException catch (e) {
        if (e.error is UnauthorizedException) {
          // Token expired – try to re-authenticate silently
          final refreshed = await _refreshBackendToken();
          if (!refreshed) {
            throw Exception('Session expired. Please go back and sign in again.');
          }
          url = await akahuApi.connectUrl();
        } else {
          rethrow;
        }
      }

      await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      setState(() {
        _bankConnecting = false;
        _webflowLaunched = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _bankConnecting = false;
        _bankConnectError =
            'Could not open Akahu connection page. ${_friendlyAuthError(err)}';
      });
    }
  }

  /// Attempts to re-authenticate using the credentials from the registration
  /// page. Returns true if a fresh token was obtained.
  Future<bool> _refreshBackendToken() async {
    final email = _emailCtrl.text.trim();
    final password = _authPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return false;

    try {
      final container = ProviderScope.containerOf(context);
      final authApi = container.read(authApiProvider);
      final tokenStore = container.read(tokenStoreProvider);
      final token = await authApi.login(email: email, password: password);
      await tokenStore.setToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Step 2: After the user returns from the browser, poll for accounts
  /// (retries a few times because the backend needs time to process the
  /// Akahu callback), then fetch transactions.
  Future<void> _handleWebflowVerify() async {
    if (_verifyingConnection) return;

    setState(() {
      _verifyingConnection = true;
      _bankConnectError = null;
    });

    try {
      // Ensure we have a valid token before polling
      await _refreshBackendToken();

      final container = ProviderScope.containerOf(context);
      final akahuApi = container.read(akahuApiProvider);

      // Poll for accounts - the backend may still be processing the callback
      List<Map<String, dynamic>> accounts = [];
      const maxAttempts = 6;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (!mounted) return;
        try {
          accounts = await akahuApi.accounts();
        } catch (_) {
          // Swallow individual poll errors; we'll surface a final one below
        }
        if (accounts.isNotEmpty) break;
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      if (accounts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _verifyingConnection = false;
          _bankConnectError =
              'No accounts found yet. Please make sure you completed the '
              'Akahu connection in your browser, then tap "I\'ve connected" '
              'again. It can take a moment to process.';
        });
        return;
      }

      // Store accounts in local DB (same as manual-token flow)
      await AccountRepository.upsertFromAkahu(accounts);

      // Pull transactions (may be empty initially - Akahu syncs asynchronously)
      List<Map<String, dynamic>> transactions = [];
      try {
        transactions = await akahuApi.transactions();
        if (transactions.isNotEmpty) {
          await TransactionRepository.upsertFromAkahu(transactions);
        }
      } catch (_) {
        // Transactions may not be ready yet - dashboard sync will pick them up
      }

      // Run the same post-processing that BankService.connect() does
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bank_connected', true);
      await prefs.remove('last_sync_at');
      await IncomeSettingsStore.detectAndSetIncomeType();
      await BudgetAnalysisService.identifyRecurringTransactions();

      if (!mounted) return;
      setState(() {
        _verifyingConnection = false;
        _bankConnected = true;
        _backendAccountCount = accounts.length;
        _backendTxnCount = transactions.length;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goToNextPage();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _verifyingConnection = false;
        _bankConnectError =
            'Verification failed. Make sure you completed the Akahu '
            'connection and try again.\n$err';
      });
    }
  }

  // ── Manual tokens (dev/test) ──────────────────────────────────────────────

  Future<void> _handleManualTokenConnect() async {
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

    // TODO: When backend auth is live, call:
    //   1. AuthApi.register() with email/password to get a token
    //   2. ProfileApi.onboarding() with the profile fields
    //   3. AkahuController.startConnect() instead of manual token entry
    // See lib/api/auth_api.dart, lib/api/profile_api.dart, lib/controllers/akahu_controller.dart
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
  final bool obscureText;

  const _StyledFormField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.suffixIcon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      obscureText: obscureText,
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
