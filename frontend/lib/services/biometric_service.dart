// BiometricService: autenticacion por huella/Face ID

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final bool _isWeb = kIsWeb;

  /// Verifica si el dispositivo soporta autenticacion biometrica
  static Future<bool> isAvailable() async {
    if (_isWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los tipos biometricos disponibles (huella, Face ID, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (_isWeb) return [];
    try {
      final auth = LocalAuthentication();
      return await auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Solicita autenticacion biometrica al usuario
  /// Retorna true si la autenticacion fue exitosa
  static Future<bool> authenticate({
    String reason = 'Autenticacion requerida para acceder a la wallet',
  }) async {
    if (_isWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
