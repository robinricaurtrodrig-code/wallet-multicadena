// SecuritySettingsScreen: configuracion de PIN, biometria, anti-phishing y auto-logout

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/security_provider.dart';
import '../../services/biometric_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _phishingCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  int _autoLogoutMinutes = 5;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final minutes = await SecureStorage.getAutoLogoutMinutes();
    final code = await SecureStorage.getAntiPhishingCode();
    final bio = await SecureStorage.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _autoLogoutMinutes = minutes;
        _phishingCtrl.text = code ?? '';
        _biometricEnabled = bio;
      });
    }
  }

  /// Guarda el codigo anti-phishing
  Future<void> _savePhishingCode() async {
    final sec = context.read<SecurityProvider>();
    await sec.setAntiPhishingCode(_phishingCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo anti-phishing guardado')),
      );
    }
  }

  /// Cambia el PIN de acceso
  Future<void> _changePin() async {
    if (_newPinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener al menos 4 digitos')),
      );
      return;
    }
    if (_newPinCtrl.text != _confirmPinCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los PIN no coinciden')),
      );
      return;
    }
    await SecureStorage.savePin(_newPinCtrl.text);
    _newPinCtrl.clear();
    _confirmPinCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado correctamente')),
      );
    }
  }

  /// Alterna autenticacion biometrica
  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      final ok = await BiometricService.authenticate(
        reason: 'Verifica tu identidad para habilitar biometria',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo verificar la identidad')),
        );
        return;
      }
    }
    await SecureStorage.setBiometricEnabled(enabled);
    setState(() => _biometricEnabled = enabled);
  }

  /// Cambia el tiempo de auto-logout
  Future<void> _setAutoLogout(int minutes) async {
    final sec = context.read<SecurityProvider>();
    await sec.setAutoLogoutMinutes(minutes);
    setState(() => _autoLogoutMinutes = minutes);
  }

  @override
  void dispose() {
    _phishingCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Seccion: Cambiar PIN
          const Icon(Icons.lock_outline, size: 48, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Seguridad Avanzada',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),

          Text('Cambiar PIN', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Nuevo PIN',
              prefixIcon: Icon(Icons.pin),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
          ),
          TextFormField(
            controller: _confirmPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Confirmar PIN',
              prefixIcon: Icon(Icons.pin),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _changePin,
            child: const Text('Actualizar PIN'),
          ),
          const Divider(height: 48),

          // Seccion: Biometria
          Text('Autenticacion Biometrica',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: BiometricService.isAvailable(),
            builder: (context, snapshot) {
              final available = snapshot.data ?? false;
              return SwitchListTile(
                title: const Text('Huella / Face ID'),
                subtitle: Text(available
                    ? 'Desbloquea con tu huella o rostro'
                    : 'No disponible en este dispositivo'),
                value: _biometricEnabled && available,
                onChanged: available ? _toggleBiometric : null,
              );
            },
          ),
          const Divider(height: 48),

          // Seccion: Auto-logout
          Text('Cierre Automatico',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Bloquear la app despues de inactividad:',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _autoLogoutMinutes,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.timer)),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 minuto')),
              DropdownMenuItem(value: 5, child: Text('5 minutos')),
              DropdownMenuItem(value: 15, child: Text('15 minutos')),
              DropdownMenuItem(value: 30, child: Text('30 minutos')),
              DropdownMenuItem(value: 60, child: Text('1 hora')),
            ],
            onChanged: (v) {
              if (v != null) _setAutoLogout(v);
            },
          ),
          const Divider(height: 48),

          // Seccion: Anti-phishing
          Text('Codigo Anti-Phishing',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Elige una palabra o frase que solo tu reconozcas. '
            'La veras en pantallas sensibles para confirmar que es la app legitima.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phishingCtrl,
            decoration: const InputDecoration(
              labelText: 'Tu codigo personal',
              hintText: 'Ej: LunaAzul2024',
              prefixIcon: Icon(Icons.verified_user),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _savePhishingCode,
            child: const Text('Guardar Codigo'),
          ),
          const Divider(height: 48),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: const Text('Cerrar Sesion', style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Cerrar Sesion'),
        content: const Text('¿Estas seguro de que quieres cerrar sesion?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesion', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
        (route) => false,
      );
    }
  }
}
