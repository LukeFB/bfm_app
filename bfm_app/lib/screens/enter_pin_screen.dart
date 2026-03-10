import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bfm_app/services/pin_store.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key, required this.pinStore});

  final PinStore pinStore;

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _pin = '';
  bool _verifying = false;
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
    if (_verifying || _pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit.toString();
      _error = null;
    });
    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _verifying = true);

    try {
      final ok = await widget.pinStore.verifyPin(_pin);
      if (!mounted) return;

      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      } else {
        HapticFeedback.heavyImpact();
        _shakeController.forward(from: 0);
        final attempts = await widget.pinStore.getFailedAttempts();
        final remaining = PinStore.maxAttemptsBeforeWipe - attempts;
        setState(() {
          _error = remaining <= 5
              ? 'Wrong PIN. $remaining attempts remaining.'
              : 'Wrong PIN. Try again.';
          _pin = '';
          _verifying = false;
        });
      }
    } on PinLockedException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = e.toString();
        _pin = '';
        _verifying = false;
      });
    } on PinWipedException {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.lock_rounded, size: 48, color: primary),
            const SizedBox(height: 20),
            Text(
              'Enter your PIN',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
              enabled: !_verifying,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

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
    final activeColor = hasError ? Theme.of(context).colorScheme.error : accentColor;
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
