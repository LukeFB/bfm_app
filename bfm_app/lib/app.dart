import 'package:flutter/material.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/screens/transactions_screen.dart';
import 'package:bfm_app/screens/goals_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/settings_screen.dart';
import 'package:bfm_app/screens/start_screen.dart';
import 'package:bfm_app/screens/login_screen.dart';
import 'package:bfm_app/screens/register_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BFM App',
      theme: ThemeData(
        primaryColor: const Color(0xFF005494),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFFF6934),
        ),
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Roboto',
      ),
      // Dashboard
      initialRoute: '/start',
      routes: {
        '/start': (_) => const StartScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/transaction': (_) => const TransactionsScreen(),
        '/goals': (_) => const GoalsScreen(),
        '/chat': (_) => const ChatScreen(),
        '/insights': (_) => const InsightsScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
