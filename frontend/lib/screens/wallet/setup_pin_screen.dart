import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../core/storage/secure_storage.dart';
import '../../services/biometric_service.dart';
import '../../config/theme.dart';
import '../home/home_screen.dart';

/// Pantalla de configuracion del PIN de acceso
/// Se muestra despues de crear o importar una wallet exitosamente
/// El usuario puede configurar un PIN numerico y/o habilitar autenticacion biometrica
class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _biometricEnabled = false;
  bool _skipPin = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Guarda la wallet con todas las configuraciones y navega al Home
  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final wallet = context.read<WalletProvider>();
    final seedPhrase = wallet.seedPhrase;

    if (seedPhrase == null || seedPhrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay frase semilla disponible')),
      );
      return;
    }

    try {
      // Guardar la wallet con la contrasena ingresada
      await wallet.saveWallet(seedPhrase, _passwordCtrl.text);

      // Si el usuario configuro un PIN, guardarlo de forma segura (hasheado)
      if (!_skipPin && _pinCtrl.text.isNotEmpty) {
        await SecureStorage.savePin(_pinCtrl.text);
      }

      // Guardar preferencia biometrica si la habilito
      if (_biometricEnabled) {
        await SecureStorage.setBiometricEnabled(true);
      }



      // Navegar a la pantalla principal (home)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Seguridad')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono y titulo de la pantalla
                const Icon(Icons.lock_outline, size: 48, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Protege tu wallet',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configura medidas de seguridad adicionales para proteger tus activos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Campo de contrasena para cifrar la frase semilla
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena de cifrado',
                    hintText: 'Usada para cifrar tu seed phrase localmente',
                    prefixIcon: Icon(Icons.key),
                  ),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 6 ? null : 'Minimo 6 caracteres',
                ),
                const SizedBox(height: 16),

                // Campo de PIN numerico
                TextFormField(
                  controller: _pinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PIN de acceso (opcional)',
                    hintText: '4-6 digitos numericos',
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: _skipPin ? null : (v) {
                    if (_skipPin) return null;
                    if (v != null && v.isNotEmpty && v.length < 4) return 'Minimo 4 digitos';
                    return null;
                  },
                ),

                // Confirmacion del PIN
                TextFormField(
                  controller: _confirmPinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar PIN',
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (v) {
                    if (_skipPin && _pinCtrl.text.isEmpty) return null;
                    if (v != _pinCtrl.text) return 'Los PIN no coinciden';
                    return null;
                  },
                ),

                // Opcion para omitir el PIN
                CheckboxListTile(
                  value: _skipPin,
                  onChanged: (v) {
                    setState(() => _skipPin = v ?? false);
                    if (v == true) {
                      _pinCtrl.clear();
                      _confirmPinCtrl.clear();
                    }
                  },
                  title: const Text('Omitir PIN (solo contrasena)'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                // Opcion para habilitar autenticacion biometrica
                FutureBuilder<bool>(
                  future: BiometricService.isAvailable(),
                  builder: (context, snapshot) {
                    final available = snapshot.data ?? false;
                    return CheckboxListTile(
                      value: _biometricEnabled,
                      onChanged: available
                          ? (v) {
                              setState(() => _biometricEnabled = v ?? false);
                              if (v == true) {
                                BiometricService.authenticate(
                                  reason: 'Verifica tu identidad para habilitar biometria',
                                );
                              }
                            }
                          : null,
                      title: const Text('Habilitar autenticacion biometrica (huella/Face ID)'),
                      subtitle: Text(available
                          ? 'Usa tu huella o Face ID para acceder'
                          : 'No disponible en este dispositivo'),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Boton para finalizar la configuracion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _finishSetup,
                    child: const Text('Finalizar configuracion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
