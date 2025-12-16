/// ---------------------------------------------------------------------------
/// File: lib/screens/enter_pin_screen.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - LockGate when the user chooses the app PIN fallback.
///
/// Purpose:
///   - Collects the stored app PIN, validates it locally, and returns `true`
///     when the PIN matches.
///
/// Inputs:
///   - `PinStore` instance injected from the caller.
///
/// Outputs:
///   - `Navigator.pop(true)` on success, otherwise shows inline errors.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_store.dart';

/// PIN entry modal for unlocking the app without biometrics.
class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key, required this.pinStore});

  final PinStore pinStore;

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

/// Manages the PIN form, validation, and verification state.
class _EnterPinScreenState extends State<EnterPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();

  bool _verifying = false;
  String? _error;

  /// Cleans up the text controller.
  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Validates the form, calls the PinStore, and closes the sheet on success.
  Future<void> _verifyPin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final result = await widget.pinStore.verifyPin(_pinController.text);
    if (!mounted) return;

    if (result) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _verifying = false;
      });
    }
  }

  /// Ensures the PIN length is between 4 and 8 digits inclusive.
  String? _validatePin(String? value) {
    final pin = value ?? '';
    if (pin.length < 4 || pin.length > 8) {
      return 'Enter 4-8 digits';
    }
    return null;
  }

  /// Renders the PIN input field, inline errors, and submission button.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enter App PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Unlock using your app PIN.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  hintText: 'Enter PIN',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                maxLength: 8,
                validator: _validatePin,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _verifying ? null : _verifyPin,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

