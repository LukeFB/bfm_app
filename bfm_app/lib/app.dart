/// ---------------------------------------------------------------------------
/// File: lib/app.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `lib/main.dart` via `runApp(const MyApp())` during app bootstrap.
///
/// Purpose:
///   - Hosts `MyApp`, the shared Material shell that wires named routes.
///   - Provides `LockGate`, the biometric/PIN guard that decides when a user
///     gets routed into the rest of the app.
///
/// Inputs:
///   - `LocalAuthentication`, `SharedPreferences`, and `PinStore` state at
///     runtime plus repository reads for saved budgets.
///
/// Outputs:
///   - Pushes a named route based on auth, exposing dashboard/budget/chat/etc.
///   - Emits top-level widgets used by every other screen once unlocked.
///
/// Notes:
///   - Keep asynchronous auth work guarded with `_navigating` so we only route
///     once per unlock attempt.
///   - This file owns user entry and should stay side-effect free outside UI
///     and routing so tests can stub the dependencies.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:local_auth/error_codes.dart' as auth_error;
// import 'package:local_auth/local_auth.dart'; // Auth

import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/transactions_screen.dart';
import 'package:bfm_app/screens/goals_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/settings_screen.dart';
import 'package:bfm_app/screens/bank_connect_screen.dart'; // BankConnect screen
import 'package:bfm_app/screens/debug_screen.dart'; // Debug
import 'package:bfm_app/screens/debug_api_screen.dart'; // Backend API debug
import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/widgets/main_shell.dart'; // Swipeable navigation shell

import 'package:bfm_app/screens/budget_build_screen.dart';
import 'package:bfm_app/screens/budget_recurring_screen.dart';
import 'package:bfm_app/screens/budgets_screen.dart';
import 'package:bfm_app/screens/subscriptions_screen.dart';
import 'package:bfm_app/screens/enter_pin_screen.dart';
import 'package:bfm_app/screens/savings_screen.dart';
import 'package:bfm_app/screens/set_pin_screen.dart';

import 'package:bfm_app/services/pin_store.dart';
import 'package:bfm_app/utils/app_route_observer.dart';


import 'package:bfm_app/screens/login_screen.dart';
import 'package:bfm_app/services/onboarding_store.dart';
import 'package:bfm_app/controllers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root gate widget that blocks the navigation stack until a user completes
/// biometrics or PIN auth. Owned by `MyApp` and pushed right after launch.
class LockGate extends StatefulWidget {
  const LockGate({Key? key}) : super(key: key);

  /// Creates the mutable state that carries all auth + routing logic.
  @override
  State<LockGate> createState() => _LockGateState();
}

/// Internal lifecycle states so we can drive the UI copy and spinners.
enum _LockStatus { initializing, idle, routing }

/// Handles auth orchestration plus the conditional routing side effects.
class _LockGateState extends State<LockGate> {
  final PinStore _pinStore = PinStore();

  _LockStatus _status = _LockStatus.initializing;
  bool _navigating = false;
  String? _errorMessage;

  /// Kicks off detection for biometrics + stored PIN as soon as the widget
  /// mounts so the splash state can show a spinner instead of stale data.
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Checks PIN state and either skips straight past (grace period), or
  /// immediately pushes the enter / create PIN screen — no intermediate
  /// landing page required.
  Future<void> _bootstrap() async {
    setState(() {
      _status = _LockStatus.initializing;
      _errorMessage = null;
    });

    final pinExists = await _pinStore.hasPin();
    if (!mounted) return;

    setState(() => _status = _LockStatus.idle);

    if (pinExists && await _pinStore.isWithinGracePeriod()) {
      await _routeAfterAuth();
      return;
    }

    // Go straight to the appropriate PIN screen.
    if (pinExists) {
      _launchPinEntry();
    } else {
      _launchPinSetup();
    }
  }

  /// Looks at persisted state (onboarding flag + backend token) to decide
  /// which named route to push after auth. Guarded by `_navigating` so
  /// multiple async calls cannot accidentally stack navigations.
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
      final onboardingComplete = await OnboardingStore().isComplete();

      if (!onboardingComplete) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      }

      // Onboarding done – validate the stored backend session.
      final container = ProviderScope.containerOf(context);
      final status = await container
          .read(authControllerProvider.notifier)
          .tryRestoreSession();

      if (!mounted) return;

      switch (status) {
        case SessionStatus.valid:
        case SessionStatus.networkError:
          // Valid token or offline – head to the dashboard.
          Navigator.pushReplacementNamed(context, '/dashboard');
        case SessionStatus.expired:
        case SessionStatus.noToken:
          // Token missing or expired – prompt for re-login.
          Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _navigating = false;
        _status = _LockStatus.idle;
        _errorMessage = 'Unable to open the app. $err';
      });
    }
  }

  /// Opens the PIN entry modal flow and only re-runs routing when a user
  /// successfully authenticates. Keeps the navigation result typed as bool.
  Future<void> _launchPinEntry() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EnterPinScreen(pinStore: _pinStore),
      ),
    );

    if (result == true) {
      await _pinStore.recordAuthSuccess();
      await _routeAfterAuth();
    }
  }

  /// Opens the PIN setup modal flow. If the user creates a PIN we flag the
  /// state immediately and re-route so the rest of the app can open.
  Future<void> _launchPinSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SetPinScreen(pinStore: _pinStore),
      ),
    );

    if (result == true) {
      await _pinStore.recordAuthSuccess();
      await _routeAfterAuth();
    }
  }

  /// The build now only shows a minimal splash / loading indicator because
  /// `_bootstrap` immediately pushes to the PIN screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status == _LockStatus.initializing ||
                _status == _LockStatus.routing)
              const CircularProgressIndicator(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _bootstrap,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Root MaterialApp shell wired up by `main.dart`. Handles theming, route
/// wiring, and navigator observers for analytics.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  /// Creates the MaterialApp with all named routes so every screen can navigate
  /// by string. Keep this minimal—expensive work should stay in services.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
      title: 'BFM App',
      theme: ThemeData(
        primaryColor: const Color(0xFF005494),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFFF6934),
        ),
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Roboto',
      ),
      home: const LockGate(), // Set the home to our LockGate
      routes: {
        '/login': (_) => const LoginScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        // TODO: BankConnectScreen kept for dev/debug only (manual token entry)
        '/bankconnect': (_) => const BankConnectScreen(),
        // Main navigation shell with swipeable screens
        // Order: Insights(0), Budget(1), Dashboard(2), Savings(3), Chat(4)
        '/dashboard': (_) => const MainShell(initialPage: 2),
        '/insights': (_) => const MainShell(initialPage: 0),
        '/budgets': (_) => const MainShell(initialPage: 1),
        '/savings': (_) => const MainShell(initialPage: 3),
        '/chat': (_) => const MainShell(initialPage: 4),
        // Standalone screens (not in swipe navigation)
        '/transaction': (_) => const TransactionsScreen(),
        '/goals': (_) => const GoalsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/debug': (_) => const DebugScreen(),
        '/debug-api': (_) => const DebugApiScreen(),
        '/subscriptions': (_) => const SubscriptionsScreen(),
        '/subscriptions/edit': (_) => const SubscriptionsScreen(editMode: true),
        '/budget/build': (_) => const BudgetBuildScreen(),
        '/budget/edit': (_) => const BudgetBuildScreen(editMode: true),
        '/alerts/manage': (_) => const BudgetRecurringScreen(),
      },
    );
  }
}
