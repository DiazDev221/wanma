import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../state/app_state.dart';
import '../widgets/wanma_logo.dart';

/// Écran de déverrouillage par code PIN à 4 chiffres.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final List<String> _digits = <String>[];
  bool _checking = false;
  String? _error;
  int _failedAttempts = 0;
  int _lockoutRemaining = 0;
  Timer? _lockoutTimer;

  bool get _lockedOut => _lockoutRemaining > 0;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_checking || _lockedOut || _digits.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _digits.add(digit);
    });
    if (_digits.length == 4) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_checking || _lockedOut || _digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_checking) return;
    setState(() => _checking = true);
    final pin = _digits.join();
    final valid = await context.read<AppState>().unlock(pin);
    if (!mounted) return;

    if (valid) {
      setState(() {
        _checking = false;
        _digits.clear();
      });
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _checking = false;
      _digits.clear();
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _failedAttempts = 0;
        _lockoutRemaining = 30;
        _startLockout();
        _error = 'Trop de tentatives. Patientez 30 secondes.';
      } else {
        _error = 'Code incorrect. Réessayez.';
      }
    });
  }

  void _startLockout() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutRemaining--;
        if (_lockoutRemaining <= 0) {
          timer.cancel();
          _error = null;
          _lockoutRemaining = 0;
        } else {
          _error = 'Trop de tentatives. Patientez $_lockoutRemaining secondes.';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        color: AppColors.ivory,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[AppColors.ivory, AppColors.paper],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              const WanmaLogo(size: 64),
                              const SizedBox(height: 14),
                              const Text(
                                'Wanma',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Votre magasin, mieux géré',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: <Widget>[
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.cobaltSoft,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.cobalt,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Application verrouillée',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Saisissez votre code PIN à 4 chiffres',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List<Widget>.generate(4, (index) {
                                  final filled = index < _digits.length;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    width: filled ? 15 : 13,
                                    height: filled ? 15 : 13,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? AppColors.cobalt
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: filled
                                            ? AppColors.cobalt
                                            : AppColors.muted.withValues(
                                                alpha: 0.45,
                                              ),
                                        width: 1.5,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 22,
                                child: _checking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.cobalt,
                                        ),
                                      )
                                    : AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: Text(
                                          _error ?? '',
                                          key: ValueKey<String>(_error ?? ''),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.coral,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          _Keypad(
                            enabled: !_checking && !_lockedOut,
                            onDigit: _onDigit,
                            onBackspace: _onBackspace,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Votre code reste sur ce téléphone.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: Column(
        children: <Widget>[
          for (final row in <List<String>>[
            <String>['1', '2', '3'],
            <String>['4', '5', '6'],
            <String>['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  for (final digit in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _KeypadButton(
                          label: digit,
                          enabled: enabled,
                          onPressed: () => onDigit(digit),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                const Expanded(child: SizedBox()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _KeypadButton(
                      label: '0',
                      enabled: enabled,
                      onPressed: () => onDigit('0'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _KeypadButton(
                      icon: Icons.backspace_outlined,
                      enabled: enabled,
                      onPressed: onBackspace,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label ?? 'Effacer le dernier chiffre',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[AppTokens.cardShadow],
        ),
        child: Material(
          color: enabled ? Colors.white : AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        color: AppColors.ink.withValues(
                          alpha: enabled ? 0.72 : 0.3,
                        ),
                        size: 21,
                      )
                    : Text(
                        label ?? '',
                        style: TextStyle(
                          color: AppColors.ink.withValues(
                            alpha: enabled ? 1 : 0.3,
                          ),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
