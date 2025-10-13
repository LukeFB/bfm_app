import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // Auth
        
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/transactions_screen.dart';
import 'package:bfm_app/screens/goals_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/settings_screen.dart';
import 'package:bfm_app/screens/bank_connect_screen.dart'; // BankConnect screen
import 'package:bfm_app/screens/debug_screen.dart'; // Debug

// ✅ NEW: Budget Build screen
import 'package:bfm_app/screens/budget_build_screen.dart';

// ✅ Used to decide if we should send a connected user to budget builder
import 'package:bfm_app/repositories/budget_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

class LockGate extends StatefulWidget {
  const LockGate({Key? key}) : super(key: key);

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _authenticating = false;
  String _error = "";

  Future<void> _authenticate() async {
    setState(() {
      _authenticating = true;
      _error = "";
    });

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock Bay Financial Mentors',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        final connected = prefs.getBool('bank_connected') ?? false;

        String nextRoute;
        if (!connected) {
          nextRoute = '/bankconnect';
        } else {
          // ✅ If bank connected but no budgets saved yet → go to builder
          final budgets = await BudgetRepository.getAll();
          nextRoute = budgets.isEmpty ? '/budget/build' : '/dashboard';
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, nextRoute);
      } else {
        setState(() => _error = "Authentication failed. Try again.");
      }
    } catch (e) {
      setState(() => _error = "Auth error: $e");
    }

    setState(() => _authenticating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Login")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.black54),
            const SizedBox(height: 20),
            _authenticating
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _authenticate,
                    child: const Text("Unlock with PIN"), // TODO: style login screen
                  ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
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

        // ✅ NEW: route to the Budget Build screen (post-bank-connect)
        '/budget/build': (_) => const BudgetBuildScreen(),
      },
    );
  }
}
