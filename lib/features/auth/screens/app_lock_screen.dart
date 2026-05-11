import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/app_lock_service.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — App Lock Screen
///
/// Full-screen lock overlay shown when app lock is enabled.
/// Supports biometric authentication + 4-digit PIN fallback.
/// Follows the Lumina Focus design system.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: UI for the App Lock screen, handling biometric and PIN entry.
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final AppLockService _lockService = AppLockService();
  String _pin = '';
  bool _hasError = false;
  bool _biometricAvailable = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _checkBiometric();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await _lockService.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
    if (available) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final success = await _lockService.authenticateWithBiometrics();
    if (success && mounted) widget.onUnlocked();
  }

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _pin += digit;
      _hasError = false;
    });

    if (_pin.length == 4) _verifyPin();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _verifyPin() async {
    final success = await _lockService.verifyPin(_pin);
    if (success) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _pin = '';
      });
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── App logo ──
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.tertiary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'NoteFlow is Locked',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your PIN to continue',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 40),

            // ── PIN dots ──
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final dx =
                    _shakeAnimation.value *
                    10 *
                    ((_shakeController.value * 8).round().isEven ? 1 : -1);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 16 : 14,
                    height: filled ? 16 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? cs.error
                          : filled
                          ? cs.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _hasError
                            ? cs.error
                            : filled
                            ? cs.primary
                            : cs.outlineVariant,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_hasError) ...[
              const SizedBox(height: 16),
              Text(
                'Incorrect PIN. Try again.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(flex: 1),

            if (_biometricAvailable) ...[
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint_rounded, size: 24),
                label: Text(
                  'Use Fingerprint',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── Number pad ──
            _NumPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Number Pad
/// ──────────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _NumPad({
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _row(['1', '2', '3'], cs),
          const SizedBox(height: 12),
          _row(['4', '5', '6'], cs),
          const SizedBox(height: 12),
          _row(['7', '8', '9'], cs),
          const SizedBox(height: 12),
          Row(
            children: [
              // Empty space where biometric used to be
              const Expanded(
                child: SizedBox(),
              ),
              const SizedBox(width: 12),
              // Zero
              Expanded(
                child: _PadButton(
                  child: Text(
                    '0',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  onTap: () => onDigit('0'),
                ),
              ),
              const SizedBox(width: 12),
              // Backspace
              Expanded(
                child: _PadButton(
                  onTap: onBackspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> digits, ColorScheme cs) {
    return Row(
      children: digits.asMap().entries.map((entry) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: entry.key == 0 ? 0 : 6,
              right: entry.key == 2 ? 0 : 6,
            ),
            child: _PadButton(
              child: Text(
                entry.value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              onTap: () => onDigit(entry.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PadButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(height: 60, child: Center(child: child)),
      ),
    );
  }
}
