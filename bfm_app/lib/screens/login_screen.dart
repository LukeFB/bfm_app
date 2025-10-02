import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text field for the email prompt.
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 32),
            // Text field for the password prompt.
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            // Login button.
            ElevatedButton(
              onPressed: () {
                // For now there's no backend, push login always.
                Navigator.pushReplacementNamed(context, '/dashboard');
              },
              child: const Text("Login"),
            ),
            const SizedBox(height: 16),
            // Register button.
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              // Register button text.
              child: const Text("Don’t have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
