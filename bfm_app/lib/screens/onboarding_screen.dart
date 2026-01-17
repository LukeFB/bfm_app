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

import 'package:bfm_app/models/onboarding_response.dart';
import 'package:bfm_app/services/onboarding_store.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

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
  final OnboardingStore _store = OnboardingStore();

  int _currentPage = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _ageCtrl.dispose();
    _genderCtrl.dispose();
    _locationCtrl.dispose();
    _referrerCtrl.dispose();
    _reasonCtrl.dispose();
    _situationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final totalPages = pages.length;
    final isLastPage = _currentPage >= totalPages - 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to Moni'),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => _completeOnboarding(skipAnswers: true),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressDots(currentIndex: _currentPage, total: totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    onPressed: _saving || _currentPage == 0
                        ? null
                        : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(
                      isLastPage ? Icons.rocket_launch : Icons.arrow_forward,
                    ),
                    label: Text(isLastPage ? 'Start using Moni' : 'Next'),
                    onPressed: _saving
                        ? null
                        : () => _handleNext(totalPages, isLastPage),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    final questionSteps = _questionSteps();
    final questionPages = questionSteps.map(_buildQuestionPage).toList();
    return [
      ...questionPages,
      _buildPrivacyPage(context),
      _buildFeatureTourPage(context),
      _buildNextStepsPage(context),
    ];
  }

  List<_QuestionStep> _questionSteps() {
    return [
      _QuestionStep(
        title: 'How old are you?',
        description: 'Optional. Helps us tailor nudges to your life stage.',
        fieldLabel: 'Age',
        controller: _ageCtrl,
        hint: 'e.g. 29',
        keyboardType: TextInputType.number,
        infoMessage:
            'Sharing your age keeps tips relevant, but you can skip anytime.',
      ),
      _QuestionStep(
        title: 'How do you describe your gender?',
        description: 'Use whatever language feels right or leave it blank.',
        fieldLabel: 'Gender',
        controller: _genderCtrl,
        hint: 'Woman, non-binary, masculine, prefer not to say…',
      ),
      _QuestionStep(
        title: 'Where are you based?',
        description:
            'Knowing your city/region helps us reference local services.',
        fieldLabel: 'Location',
        controller: _locationCtrl,
        hint: 'City or region',
      ),
      _QuestionStep(
        title: 'Who pointed you to Moni?',
        description: 'Helps us thank the right people and understand reach.',
        fieldLabel: 'Referrer',
        controller: _referrerCtrl,
        hint: 'Friend, mentor, social media…',
      ),
      _QuestionStep(
        title: 'Why do you want to use Moni?',
        description: 'Describe your main goal so we can focus the coaching.',
        fieldLabel: 'Main reason',
        controller: _reasonCtrl,
        hint: 'I want to get ahead with weekly spending…',
        maxLines: 3,
      ),
      _QuestionStep(
        title: 'Tell us about your situation',
        description:
            'Any context about studies, whānau support, or money stress.',
        fieldLabel: 'Your situation',
        controller: _situationCtrl,
        hint: 'I’m studying full-time, working 10h/week, supporting whānau…',
        maxLines: 4,
      ),
    ];
  }

  Widget _buildQuestionPage(_QuestionStep step) {
    return _OnboardingPageShell(
      title: step.title,
      description: step.description,
      child: Column(
        children: [
          _LabeledField(
            controller: step.controller,
            label: step.fieldLabel,
            hint: step.hint,
            maxLines: step.maxLines,
            keyboardType: step.keyboardType,
          ),
          const SizedBox(height: 12),
          _InfoBanner(
            icon: Icons.info_outline,
            message:
                step.infoMessage ??
                'These answers stay on your device to personalise coaching. '
                    'You can skip or change them later.',
          ),
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

  Widget _buildFeatureTourPage(BuildContext context) {
    final features = [
      const _FeatureCard(
        icon: Icons.category_outlined,
        title: 'Budget builder',
        copy:
            'Review Moni’s suggested categories, toggle the ones you need, and edit weekly limits before saving.',
      ),
      const _FeatureCard(
        icon: Icons.dashboard_customize_outlined,
        title: 'Dashboard & insights',
        copy:
            'See weekly spend, alerts, and tips surfaced from your transactions to stay on track.',
      ),
      const _FeatureCard(
        icon: Icons.swap_horiz_outlined,
        title: 'Transactions',
        copy:
            'Browse every transaction, tidy uncategorised rows, and spot recurring expenses.',
      ),
      const _FeatureCard(
        icon: Icons.flag_outlined,
        title: 'Goals & recurring plans',
        copy:
            'Set savings goals and convert recurring bills into budget lines so they never surprise you.',
      ),
      const _FeatureCard(
        icon: Icons.chat_bubble_outline,
        title: 'Coach & chat',
        copy:
            'Use the built-in coach to ask questions about your money trends or get nudges when things drift.',
      ),
    ];

    return _OnboardingPageShell(
      title: 'Here’s how the app flows',
      description:
          'Take a quick tour so you know what each tab does. You can revisit this guide from Settings later.',
      child: Column(
        children: [
          for (final feature in features) ...[
            feature,
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildNextStepsPage(BuildContext context) {
    const steps = [
      _NextStep(
        title: 'Connect your bank',
        copy:
            'Securely link accounts so Moni can analyse the last 90 days of spending.',
      ),
      _NextStep(
        title: 'Build your budget',
        copy: 'Select categories, edit limits, and save your weekly plan.',
      ),
      _NextStep(
        title: 'Stay on top of it',
        copy:
            'Check the dashboard, insights, and chat coach whenever you need a pulse check.',
      ),
    ];

    return _OnboardingPageShell(
      title: 'Ready to get started?',
      description:
          'Here’s what happens next. You can always adjust budgets or revisit onboarding later in Settings.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(step.copy),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const _InfoBanner(
            icon: Icons.school_outlined,
            message:
                'Need a refresher later? Screenshot this checklist or replay onboarding after clearing local app data.',
          ),
        ],
      ),
    );
  }

  void _handleNext(int totalPages, bool isLastPage) {
    if (isLastPage) {
      _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
    Navigator.pushReplacementNamed(context, '/bankconnect');
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(copy),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionStep {
  final String title;
  final String description;
  final String fieldLabel;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? infoMessage;

  const _QuestionStep({
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.infoMessage,
  });
}

class _NextStep {
  final String title;
  final String copy;
  const _NextStep({required this.title, required this.copy});
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
