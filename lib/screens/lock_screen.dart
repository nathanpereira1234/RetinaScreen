import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// The access gate shown when the app lock is on. Verifies a PIN (always
/// available) or biometric (when the device supports it), then unlocks.
///
/// The lock is an access control on the running app; it does NOT hold the
/// database key (that lives in the keystore and is fetched independently), so
/// forgetting the PIN never loses patient data.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _hasPin = false;
  bool _canBiometric = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final security = ref.read(securityServiceProvider);
    final hasPin = await security.hasPin();
    final canBio = await security.canUseBiometric();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _canBiometric = canBio;
      _busy = false;
    });
    if (hasPin && canBio) await _biometric();
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _biometric() async {
    final s = ref.read(stringsProvider);
    final ok = await ref.read(securityServiceProvider).authenticateBiometric(
          s.unlock,
        );
    if (ok && mounted) ref.read(lockControllerProvider.notifier).unlock();
  }

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    final security = ref.read(securityServiceProvider);
    final pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = s.enterPin);
      return;
    }
    if (_hasPin) {
      if (await security.verifyPin(pin)) {
        if (mounted) ref.read(lockControllerProvider.notifier).unlock();
      } else {
        setState(() => _error = s.wrongPin);
      }
      return;
    }
    // First-time PIN setup.
    if (pin != _confirm.text.trim()) {
      setState(() => _error = s.pinsDoNotMatch);
      return;
    }
    await security.setPin(pin);
    if (mounted) ref.read(lockControllerProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: _busy
              ? const CircularProgressIndicator(color: Colors.white)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 64, color: Colors.white),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _hasPin ? s.enterPin : s.setPin,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PinField(controller: _pin, label: s.enterPin),
                      if (!_hasPin) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PinField(controller: _confirm, label: s.confirmPin),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: _submit,
                          child: Text(s.unlock),
                        ),
                      ),
                      if (_hasPin && _canBiometric) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: _biometric,
                          icon: const Icon(Icons.fingerprint,
                              color: Colors.white),
                          label: Text(
                            s.useBiometric,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        const LengthLimitingTextInputFormatter(8),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, letterSpacing: 8),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white24,
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white70),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.sm)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
