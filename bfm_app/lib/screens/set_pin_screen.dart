import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bfm_app/services/pin_store.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key, required this.pinStore});

  final PinStore pinStore;

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _pin = '';
  String? _firstPin;
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12, end: -12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(int digit) {
    if (_saving || _pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit.toString();
      _error = null;
    });
    if (_pin.length == _pinLength) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_saving || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      // First entry — save it and move to confirm phase.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }

    // Confirmation phase — check match.
    if (_pin != _firstPin) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _error = "PINs didn't match. Start over.";
        _pin = '';
        _firstPin = null;
        _confirming = false;
      });
      return;
    }

    // Match — save.
    setState(() => _saving = true);
    try {
      await widget.pinStore.setPin(_pin);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save PIN. Try again.';
        _pin = '';
        _firstPin = null;
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    final title = _confirming ? 'Confirm your PIN' : 'Create a PIN';
    final subtitle = _confirming
        ? 'Enter the same PIN again.'
        : 'Choose a 4-digit PIN to secure the app.';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              _confirming ? Icons.check_circle_outline : Icons.pin_outlined,
              size: 48,
              color: primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: _PinDots(
                filled: _pin.length,
                total: _pinLength,
                hasError: _error != null,
                accentColor: primary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 20,
              child: _error != null
                  ? Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const Spacer(flex: 1),
            _NumberPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              enabled: !_saving,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets (identical to enter_pin_screen) ──────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.filled,
    required this.total,
    this.hasError = false,
    required this.accentColor,
  });

  final int filled;
  final int total;
  final bool hasError;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        hasError ? Theme.of(context).colorScheme.error : accentColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 18 : 16,
          height: isFilled ? 18 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? activeColor : Colors.transparent,
            border: Border.all(
              color: isFilled ? activeColor : Colors.grey.shade400,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (final row in [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((d) => _PadButton(
                          label: '$d',
                          onTap: enabled ? () => onDigit(d) : null,
                        ))
                    .toList(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72, height: 72),
              _PadButton(
                label: '0',
                onTap: enabled ? () => onDigit(0) : null,
              ),
              _PadButton(
                icon: Icons.backspace_outlined,
                onTap: enabled ? onBackspace : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({this.label, this.icon, this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.grey.shade100,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  )
                : Icon(icon, size: 24, color: Colors.black54),
          ),
        ),
      ),
    );
  }
}
