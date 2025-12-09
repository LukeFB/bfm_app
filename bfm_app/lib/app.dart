import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart'; // Auth
        
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/transactions_screen.dart';
import 'package:bfm_app/screens/goals_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/settings_screen.dart';
import 'package:bfm_app/screens/bank_connect_screen.dart'; // BankConnect screen
import 'package:bfm_app/screens/debug_screen.dart'; // Debug

import 'package:bfm_app/screens/budget_build_screen.dart';
import 'package:bfm_app/screens/enter_pin_screen.dart';
import 'package:bfm_app/screens/set_pin_screen.dart';
import 'package:bfm_app/repositories/budget_repository.dart';
import 'package:bfm_app/services/pin_store.dart';
import 'package:bfm_app/utils/app_route_observer.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LockGate extends StatefulWidget {
  const LockGate({Key? key}) : super(key: key);

  @override
  State<LockGate> createState() => _LockGateState();
}

enum _LockStatus { initializing, idle, authenticating, routing }

class _LockGateState extends State<LockGate> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final PinStore _pinStore = PinStore();

  _LockStatus _status = _LockStatus.initializing;
  bool _deviceSecurityAvailable = false;
  bool _biometricHardwareDetected = false;
  bool _pinAvailable = false;
  bool _navigating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _status = _LockStatus.initializing;
      _errorMessage = null;
    });

    bool supported = false;
    bool hasBiometrics = false;
    try {
      supported = await _localAuth.isDeviceSupported();
      hasBiometrics = await _localAuth.canCheckBiometrics;
    } on PlatformException {
      supported = false;
      hasBiometrics = false;
    }

    final pinExists = await _pinStore.hasPin();
    if (!mounted) return;

    setState(() {
      _deviceSecurityAvailable = supported;
      _biometricHardwareDetected = hasBiometrics;
      _pinAvailable = pinExists;
      _status = _LockStatus.idle;
    });

    if (supported) {
      await _handleDeviceAuth(autoTriggered: true);
    }
  }

  Future<void> _handleDeviceAuth({bool autoTriggered = false}) async {
    if (!_deviceSecurityAvailable) {
      return;
    }

    setState(() {
      _status = _LockStatus.authenticating;
      if (!autoTriggered) {
        _errorMessage = null;
      }
    });

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock Bay Financial Mentors',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      if (didAuthenticate) {
        await _routeAfterAuth();
      } else {
        setState(() {
          _status = _LockStatus.idle;
          _errorMessage = 'Authentication was cancelled or failed.';
        });
      }
    } on PlatformException catch (err) {
      if (!mounted) return;
      final disableDeviceAuth = err.code == auth_error.notAvailable ||
          err.code == auth_error.passcodeNotSet;
      setState(() {
        _status = _LockStatus.idle;
        if (disableDeviceAuth) {
          _deviceSecurityAvailable = false;
        }
        _errorMessage = _friendlyAuthError(err);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = _LockStatus.idle;
        _errorMessage = 'Device authentication error. $err';
      });
    }
  }

  Future<void> _routeAfterAuth() async {
    if (_navigating) {
      return;
    }

    setState(() {
      _status = _LockStatus.routing;
      _errorMessage = null;
      _navigating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final connected = prefs.getBool('bank_connected') ?? false;

      String nextRoute;
      if (!connected) {
        nextRoute = '/bankconnect';
      } else {
        final budgets = await BudgetRepository.getAll();
        nextRoute = budgets.isEmpty ? '/budget/build' : '/dashboard';
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, nextRoute);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _navigating = false;
        _status = _LockStatus.idle;
        _errorMessage = 'Unable to open the app. $err';
      });
    }
  }

  Future<void> _launchPinEntry() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EnterPinScreen(pinStore: _pinStore),
      ),
    );

    if (result == true) {
      await _routeAfterAuth();
    }
  }

  Future<void> _launchPinSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SetPinScreen(pinStore: _pinStore),
      ),
    );

    if (result == true) {
      setState(() => _pinAvailable = true);
      await _routeAfterAuth();
    }
  }

  String _friendlyAuthError(PlatformException error) {
    switch (error.code) {
      case auth_error.notAvailable:
        return 'Device security is unavailable. Use the app PIN instead.';
      case auth_error.notEnrolled:
        return 'No biometrics are enrolled. Use your app PIN.';
      case auth_error.passcodeNotSet:
        return 'Set a device passcode to use biometrics, or create an app PIN.';
      case auth_error.lockedOut:
      case auth_error.permanentlyLockedOut:
        return 'Device security is locked. Use your app PIN.';
      default:
        return error.message ?? 'Authentication error. Try a different method.';
    }
  }

  bool get _showProgress =>
      _status == _LockStatus.initializing || _status == _LockStatus.authenticating;

  @override
  Widget build(BuildContext context) {
    final canShowActions =
        !_showProgress && _status != _LockStatus.routing;

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Login')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.black54),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock to continue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use device security when available, or fall back to your app PIN.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_showProgress || _status == _LockStatus.routing)
                    const CircularProgressIndicator()
                  else
                    const SizedBox(height: 4),
                  if (canShowActions) ...[
                    const SizedBox(height: 16),
                    _ActionColumn(
                      children: [
                        if (_deviceSecurityAvailable)
                          _LockGateActionCard(
                            title: _biometricHardwareDetected
                                ? 'Biometric unlock'
                                : 'Device PIN unlock',
                            description: _biometricHardwareDetected
                                ? 'Use Face ID / Touch ID.'
                                : 'Use your device passcode.',
                            buttonLabel: 'Use device security',
                            onPressed: _status == _LockStatus.authenticating
                                ? null
                                : () => _handleDeviceAuth(),
                          ),
                        if (_pinAvailable)
                          _LockGateActionCard(
                            title: 'App PIN',
                            description: 'Enter the PIN you created for this app.',
                            buttonLabel: 'Enter PIN',
                            onPressed: _launchPinEntry,
                          )
                        else
                          _LockGateActionCard(
                            title: 'Create an app PIN',
                            description:
                                'Recommended for emulators or devices without biometrics.',
                            buttonLabel: 'Create PIN',
                            onPressed: _launchPinSetup,
                          ),
                      ],
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: child,
          ),
      ],
    );
  }
}

class _LockGateActionCard extends StatelessWidget {
  const _LockGateActionCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      title: 'BFM App',
      theme: ThemeData(
        primaryColor: const Color(0xFF005494),
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: const Color(0xFFFF6934)),
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Roboto',
      ),
      home: const LockGate(), // Set the home to our LockGate
      routes: {
        '/bankconnect': (_) => const BankConnectScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/transaction': (_) => const TransactionsScreen(),
        '/goals': (_) => const GoalsScreen(),
        '/chat': (_) => const ChatScreen(),
        '/insights': (_) => const InsightsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/debug': (_) => const DebugScreen(), // Debug
        '/budget/build': (_) => const BudgetBuildScreen(),
        '/budget/edit': (_) => const BudgetBuildScreen(editMode: true),
      },
    );
  }
}
