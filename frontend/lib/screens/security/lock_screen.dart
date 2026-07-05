// LockScreen: pantalla de bloqueo con PIN y biometria

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/security_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  /// Intenta desbloquear con PIN o biometria
  Future<void> _unlock() async {
    final sec = context.read<SecurityProvider>();

    // Si hay biometria disponible, intentar primero
    if (sec.biometricAvailable) {
      final ok = await sec.unlockWithBiometrics();
      if (ok) return;
    }

    // Sino, validar PIN
    if (!_formKey.currentState!.validate()) return;
    final valid = await sec.unlockWithPin(_pinCtrl.text.trim());
    if (!valid && mounted) {
      setState(() => _errorMsg = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = context.watch<SecurityProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 72, color: AppTheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Wallet Bloqueada',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tu PIN para desbloquear',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // Campo de PIN
                  TextFormField(
                    controller: _pinCtrl,
                    decoration: InputDecoration(
                      labelText: 'PIN de acceso',
                      prefixIcon: const Icon(Icons.pin),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
                    maxLength: 6,
                    onFieldSubmitted: (_) => _unlock(),
                    validator: (v) => v != null && v.length >= 4 ? null : 'PIN invalido',
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorMsg!, style: const TextStyle(color: AppTheme.error)),
                  ],
                  const SizedBox(height: 24),

                  // Boton desbloquear
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _unlock,
                      child: const Text('Desbloquear'),
                    ),
                  ),

                  // Boton biometrico (si disponible)
                  if (sec.biometricAvailable) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => sec.unlockWithBiometrics(),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Usar huella / Face ID'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
