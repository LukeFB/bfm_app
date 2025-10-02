import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text field for the users full name.
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 16),
            // Text field for the users email.
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 16),
            // Text field for the users password.
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            // Register button, that upon a successful register takes the user to the login screen.
            ElevatedButton(
              onPressed: () {
                // Toast message to confirm successful register.
                Fluttertoast.showToast(
                  msg: "Register successful!",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.white,
                  textColor: Colors.blue,
                );
                // Registration goes go back to login (need to make logic, this is skeleton)
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Register"),
            ),
            const SizedBox(height: 16),
            // Text button to take the user to the login screen.
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              // Text for button.
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}
