import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bfm_app/auth/credential_store.dart';
import 'package:bfm_app/controllers/akahu_controller.dart';
import 'package:bfm_app/controllers/auth_controller.dart';
import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/services/dev_config.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/theme/buxly_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _credentialStore = CredentialStore();
  bool _loading = false;
  bool _credentialsLoaded = false;
  bool _devMenuExpanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final email = await _credentialStore.getEmail();
    final password = await _credentialStore.getPassword();
    if (!mounted) return;

    final hasBoth = email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;

    setState(() {
      if (email != null && email.isNotEmpty) _emailCtrl.text = email;
      if (password != null && password.isNotEmpty) {
        _passwordCtrl.text = password;
      }
      _credentialsLoaded = true;
    });

    if (hasBoth) _submit();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState != null && !formState.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await ref.read(authControllerProvider.notifier).login(
          email: email,
          password: password,
        );

    if (!mounted) return;

    if (ok) {
      await _credentialStore.save(email: email, password: password);
      if (!mounted) return;
      await _routeBasedOnBankStatus();
    } else {
      final authError = ref.read(authControllerProvider).error;
      setState(() {
        _loading = false;
        _error = _friendlyError(authError ?? 'Login failed');
      });
    }
  }

  Future<void> _routeBasedOnBankStatus() async {
    final alreadyOnboarded = await OnboardingStore().isComplete();

    if (alreadyOnboarded) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }

    final connected = await ref
        .read(akahuControllerProvider.notifier)
        .verifyConnected();

    if (!mounted) return;

    final startPage = connected
        ? OnboardingScreen.postBankConnectPage
        : OnboardingScreen.bankConnectPage;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          startPage: startPage,
          onCompleteRoute: '/dashboard',
        ),
      ),
      (_) => false,
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('401')) return 'Invalid email or password.';
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return raw.replaceAll('Exception: ', '');
  }

  void _handleGetStarted() {
    if (_loading) return;

    final hasCreds = _credentialsLoaded &&
        _emailCtrl.text.isNotEmpty &&
        _passwordCtrl.text.isNotEmpty;

    if (hasCreds) {
      _submit();
    } else {
      _showLoginSheet();
    }
  }

  void _showLoginSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sign in',
                  style: Theme.of(ctx).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email and password to continue.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'your@email.co.nz',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(ctx);
                            _submit();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(ctx);
                              _submit();
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Sign in'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5BBFBF), Color(0xFF72CBCB), Color(0xFF88D4E4)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: _buildHeroContent(),
              ),
            ),
            _buildBottomCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroContent() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -50,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/images/SVG/BUXLY LOGO_Horizontal_Wordmark_Ash White.svg',
                height: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Financial Health. Mental Wealth.',
                style: TextStyle(
                  fontFamily: BuxlyTheme.fontFamily,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              _buildFeatureRow('💚', 'Track your spending'),
              const SizedBox(height: 14),
              _buildFeatureRow('🎯', 'Set savings goals'),
              const SizedBox(height: 14),
              _buildFeatureRow('🤖', 'AI-powered coaching'),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(BuxlyRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 8),
                    Text(
                      'Made for New Zealanders 🥝',
                      style: TextStyle(
                        fontFamily: BuxlyTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(String emoji, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            fontFamily: BuxlyTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _handleGetStarted,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Get Started'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/onboarding'),
                  child: const Text('New here? Start onboarding'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BuxlyColors.hotPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(BuxlyRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: BuxlyColors.hotPink, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: BuxlyColors.hotPink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (kDevMode) ...[
                const SizedBox(height: 20),
                _buildDevMenu(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevMenu() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _devMenuExpanded = !_devMenuExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'View all screens',
                style: TextStyle(
                  fontFamily: BuxlyTheme.fontFamily,
                  fontSize: 14,
                  color: BuxlyColors.midGrey,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _devMenuExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: BuxlyColors.midGrey,
              ),
            ],
          ),
        ),
        if (_devMenuExpanded) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _devLink('Dashboard', '/dashboard'),
              _devLink('Onboarding', '/onboarding'),
              _devLink('Insights', '/insights'),
              _devLink('Budgets', '/budgets'),
              _devLink('Savings', '/savings'),
              _devLink('Chat', '/chat'),
              _devLink('Settings', '/settings'),
              _devLink('Debug', '/debug'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _devLink(String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BuxlyRadius.pill),
          color: BuxlyColors.offWhite,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: BuxlyTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: BuxlyColors.darkText,
          ),
        ),
      ),
    );
  }
}
