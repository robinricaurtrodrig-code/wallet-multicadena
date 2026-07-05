// BiometricService: autenticacion por huella/Face ID

import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el dispositivo soporta autenticacion biometrica
  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los tipos biometricos disponibles (huella, Face ID, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Solicita autenticacion biometrica al usuario
  /// Retorna true si la autenticacion fue exitosa
  static Future<bool> authenticate({
    String reason = 'Autenticacion requerida para acceder a la wallet',
  }) async {
    try {
      return await _auth.authenticate(
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
