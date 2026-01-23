/// ---------------------------------------------------------------------------
/// File: lib/screens/onboarding_screen.dart
/// Author: Luke Fraser-Brown
///
/// Purpose:
///   - Guides new Moni users through an optional onboarding questionnaire right
///     after they unlock the app for the first time (before bank connect).
///   - Captures lightweight demographic context, explains data privacy, and
///     teaches the core screens so people know what to expect.
/// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/services/bank_service.dart';
import 'package:bfm_app/services/onboarding_store.dart';

class OnboardingScreen extends StatefulWidget {
  final String onCompleteRoute;

  const OnboardingScreen({super.key, this.onCompleteRoute = '/budget/build'});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _ageCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _referrerCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _situationCtrl = TextEditingController();
  final _bankAppTokenCtrl = TextEditingController();
  final _bankUserTokenCtrl = TextEditingController();
  final OnboardingStore _store = OnboardingStore();

  int _currentPage = 0;
  bool _saving = false;
  bool _loadingTriggered = false;
  bool _bankConnecting = false;
  bool _bankConnected = false;
  String? _bankConnectError;

  @override
  void initState() {
    super.initState();
    _hydrateBankStatus();
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
    _ageCtrl.dispose();
    _genderCtrl.dispose();
    _locationCtrl.dispose();
    _referrerCtrl.dispose();
    _reasonCtrl.dispose();
    _situationCtrl.dispose();
    _bankAppTokenCtrl.dispose();
    _bankUserTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final totalPages = pages.length;
    final lastPageIndex = totalPages - 1;
    final bankConnectIndex = totalPages >= 2 ? totalPages - 2 : 0;
    final isLastPage = _currentPage >= lastPageIndex;
    final isLoadingPage = _currentPage == lastPageIndex;
    final isBankConnectPage = _currentPage == bankConnectIndex;
    final isProcessing = _saving || _bankConnecting;
    final nextLabel = isLoadingPage
        ? 'Start using Moni'
        : isBankConnectPage
        ? (_bankConnected ? 'Continue' : 'Connect bank')
        : 'Next';
    final nextIcon = isLoadingPage
        ? Icons.rocket_launch
        : isBankConnectPage
        ? Icons.link
        : Icons.arrow_forward;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to Moni'),
        actions: const [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressDots(currentIndex: _currentPage, total: totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  if (index == lastPageIndex) {
                    _startFakeLoading();
                  }
                },
                children: pages,
              ),
            ),
            if (!isLoadingPage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      onPressed: isProcessing || _currentPage == 0
                          ? null
                          : () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: Icon(nextIcon),
                      label: Text(nextLabel),
                      onPressed: isProcessing
                          ? null
                          : () => _handleNext(isLastPage, bankConnectIndex),
                    ),
                  ],
                ),
              ),
            if (isProcessing) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    final questionSteps = _questionSteps();
    final questionPages = questionSteps.map(_buildQuestionPage).toList();
    final loadingPage = _buildLoadingPage(context);
    final bankConnectPage = _buildBankConnectPage(context);
    return [
      ...questionPages,
      _buildPrivacyPage(context),
      bankConnectPage,
      loadingPage,
    ];
  }

  List<_QuestionStep> _questionSteps() {
    return [
      _QuestionStep(
        title: 'Tell us about yourself',
        description:
            'Age, gender, and location help us tailor tips to your life stage.',
        groupedFields: [
          _FieldConfig(
            controller: _ageCtrl,
            label: 'Age',
            keyboardType: TextInputType.number,
          ),
          _FieldConfig(
            controller: _genderCtrl,
            label: 'Gender',
          ),
          _FieldConfig(
            controller: _locationCtrl,
            label: 'Location',
            hint: 'City or region',
          ),
        ],
        showInfo: false,
      ),
      _QuestionStep(
        title: 'Who pointed you to Moni?',
        description: 'Helps us thank the right people and understand reach.',
        fieldLabel: 'Referrer',
        controller: _referrerCtrl,
        showInfo: false,
      ),
      _QuestionStep(
        title:
            'Tell us a little about your situation and why you want to use Moni',
        description:
            'Helps the coach focus advice on what matters most to you.',
        controller: _reasonCtrl,
        fieldLabel: 'Share anything helpful',
        hint:
            'I’m studying full-time, supporting whānau, and want to stay on top of weekly spending…',
        maxLines: 6,
      ),
    ];
  }

  Widget _buildQuestionPage(_QuestionStep step) {
    return _OnboardingPageShell(
      title: step.title,
      description: step.description,
      child: Column(
        children: [
          if (step.groupedFields != null)
            Column(
              children: [
                for (final field in step.groupedFields!) ...[
                  _LabeledField(
                    controller: field.controller,
                    label: field.label,
                    hint: field.hint,
                    maxLines: field.maxLines,
                    keyboardType: field.keyboardType,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            )
          else
            _LabeledField(
              controller: step.controller!,
              label: step.fieldLabel ?? '',
              hint: step.hint,
              maxLines: step.maxLines,
              keyboardType: step.keyboardType,
            ),
          if (step.showInfo) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              icon: Icons.info_outline,
              message:
                  step.infoMessage ??
                  'All user data is kept on device and is optional.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyPage(BuildContext context) {
    return const _OnboardingPageShell(
      title: 'Your data, protected',
      description:
          'Moni keeps budgeting data on your device. We only send anonymous analytics '
          'events to improve the experience.',
      child: Column(
        children: [
          _PrivacyPoint(
            icon: Icons.shield_outlined,
            title: 'Local-first storage',
            copy:
                'Budgets, transactions, and onboarding answers never leave your phone.',
          ),
          _PrivacyPoint(
            icon: Icons.analytics_outlined,
            title: 'Minimal analytics',
            copy:
                'We collect lightweight usage metrics (no personal data) so we know which features to improve.',
          ),
        ],
      ),
    );
  }

  Widget _buildBankConnectPage(BuildContext context) {
    final theme = Theme.of(context);
    return _OnboardingPageShell(
      title: 'Connect your bank',
      description:
          'Paste the Akahu tokens we shared so Moni can securely pull your transactions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bankConnected)
            const _InfoBanner(
              icon: Icons.check_circle_outline,
              message:
                  'Your bank is already connected. Tap Continue to keep going.',
            )
          else ...[
            const Text(
              'These tokens only ever talk to Akahu so we can fetch your data for budgeting.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bankAppTokenCtrl,
              enabled: !_bankConnecting,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'App Token (X-Akahu-Id)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bankUserTokenCtrl,
              enabled: !_bankConnecting,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'User Token (Bearer)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We store them securely on your device and you can update them later in Settings.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_bankConnectError != null) ...[
            const SizedBox(height: 16),
            Text(
              _bankConnectError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingPage(BuildContext context) {
    return _OnboardingPageShell(
      title: 'Almost there...',
      description:
          'One moment while Moni calculates where your money’s going so we can tee up your budget builder.',
      child: const _LoadingCard(),
    );
  }

  void _handleNext(bool isLastPage, int bankConnectIndex) {
    if (_currentPage == bankConnectIndex) {
      if (_bankConnected) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        _handleBankConnect();
      }
      return;
    }

    if (isLastPage) {
      _startFakeLoading();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleBankConnect() async {
    if (_bankConnecting) return;

    final appToken = _bankAppTokenCtrl.text.trim();
    final userToken = _bankUserTokenCtrl.text.trim();

    if (appToken.isEmpty || userToken.isEmpty) {
      setState(() {
        _bankConnectError = 'Enter both tokens to continue.';
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
      if (!mounted) {
        return;
      }
      setState(() {
        _bankConnecting = false;
        _bankConnected = true;
      });
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bankConnecting = false;
        _bankConnectError = err is ArgumentError
            ? err.message ?? 'Unable to connect. Check your tokens.'
            : 'Unable to connect. Double-check your tokens and try again.';
      });
    }
  }

  void _startFakeLoading() {
    if (_loadingTriggered || _saving) return;
    setState(() => _loadingTriggered = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _completeOnboarding();
      }
    });
  }

  Future<void> _completeOnboarding({bool skipAnswers = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final response = OnboardingResponse(
      age: _valueOrNull(_ageCtrl.text, skipAnswers),
      gender: _valueOrNull(_genderCtrl.text, skipAnswers),
      location: _valueOrNull(_locationCtrl.text, skipAnswers),
      referrer: _valueOrNull(_referrerCtrl.text, skipAnswers),
      mainReason: _valueOrNull(_reasonCtrl.text, skipAnswers),
      situation: _valueOrNull(_situationCtrl.text, skipAnswers),
    );

    await _store.saveResponse(response);

    if (!mounted) return;
    setState(() => _saving = false);
    final route = widget.onCompleteRoute;
    Navigator.pushReplacementNamed(context, route);
  }

  String? _valueOrNull(String text, bool skip) {
    if (skip) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _OnboardingPageShell extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _OnboardingPageShell({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _LabeledField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          helperText: 'Optional',
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _InfoBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;

  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
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
                Text(copy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionStep {
  final String title;
  final String description;
  final String? fieldLabel;
  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? infoMessage;
  final List<_FieldConfig>? groupedFields;
  final bool showInfo;

  const _QuestionStep({
    required this.title,
    required this.description,
    this.fieldLabel,
    this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.infoMessage,
    this.groupedFields,
    this.showInfo = true,
  });
}

class _FieldConfig {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FieldConfig({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'One moment as Moni calculates where your money’s going…',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int currentIndex;
  final int total;

  const _ProgressDots({required this.currentIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == currentIndex ? 24 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == currentIndex
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}
