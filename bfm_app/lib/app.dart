import 'package:flutter/material.dart';
import 'package:bfm_app/screens/onboarding_screen.dart';
import 'package:bfm_app/screens/dashboard_screen.dart';
import 'package:bfm_app/screens/budget_screen.dart';
import 'package:bfm_app/screens/goals_screen.dart';
import 'package:bfm_app/screens/chat_screen.dart';
import 'package:bfm_app/screens/insights_screen.dart';
import 'package:bfm_app/screens/settings_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BFM App',
      theme: ThemeData(
        primaryColor: const Color(0xFF005494), // BFM blue
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFFF6934), // BFM orange
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5E1), // BFM beige
        fontFamily: 'Roboto',
        textTheme: TextTheme(
          displayLarge: TextStyle(fontFamily: 'Bree', fontSize: 24),
          bodyLarge: TextStyle(fontFamily: 'Roboto', fontSize: 16),
        ),
      ),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/budget': (_) => const BudgetScreen(),
        '/goals': (_) => const GoalsScreen(),
        '/chat': (_) => const ChatScreen(),
        '/insights': (_) => const InsightsScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
