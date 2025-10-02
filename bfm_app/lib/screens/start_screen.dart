import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main screen container,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //Styling the logo
              const FlutterLogo(size: 120),
              const SizedBox(height: 40),
              // Login Button.
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text("Login"),
              ),
              const SizedBox(height: 16),
              // Register Button.
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
