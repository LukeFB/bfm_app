import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_store.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key, required this.pinStore});

  final PinStore pinStore;

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.pinStore.setPin(_pinController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = 'Failed to save PIN. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _validatePin(String? value) {
    final pin = value ?? '';
    if (pin.length < 4 || pin.length > 8) {
      return 'PIN must be 4-8 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set App PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create a backup PIN for devices without biometrics.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  hintText: 'Enter 4-8 digits',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                maxLength: 8,
                validator: _validatePin,
              ),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                maxLength: 8,
                validator: (value) {
                  final validation = _validatePin(value);
                  if (validation != null) {
                    return validation;
                  }
                  if (value != _pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _savePin,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

