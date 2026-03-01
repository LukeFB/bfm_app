import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bfm_app/auth/credential_store.dart';
import 'package:bfm_app/controllers/auth_controller.dart';

/// Lightweight sign-in screen shown when a returning user's session has
/// expired. Auto-fills saved credentials so the user can tap once to log in.
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
      if (password != null && password.isNotEmpty) _passwordCtrl.text = password;
      _credentialsLoaded = true;
    });

    if (hasBoth) _submit();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    final ok = await ref.read(authControllerProvider.notifier).login(
          email: email,
          password: password,
        );

    if (!mounted) return;

    if (ok) {
      await _credentialStore.save(email: email, password: password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } else {
      final authError = ref.read(authControllerProvider).error;
      setState(() {
        _loading = false;
        _error = _friendlyError(authError ?? 'Login failed');
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('401')) return 'Invalid email or password.';
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return raw.replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final hasSavedCredentials = _credentialsLoaded &&
        _emailCtrl.text.isNotEmpty &&
        _passwordCtrl.text.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_open_rounded,
                        size: 64, color: Color(0xFF005494)),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSavedCredentials
                          ? 'Signing you in…'
                          : 'Your session has expired. Please sign in again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
