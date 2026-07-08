/// Servicio de autenticacion biometrica (huella dactilar / Face ID).
/// Permite verificar si el dispositivo soporta biometria, listar los tipos disponibles
/// y solicitar autenticacion biomentrica al usuario.
/// No disponible en plataforma web.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Clase que maneja la autenticacion biometrica del dispositivo.
class BiometricService {
  static final bool _isWeb = kIsWeb;

  /// Verifica si el dispositivo soporta autenticacion biometrica.
  /// Retorna false en web o si ocurre algun error.
  static Future<bool> isAvailable() async {
    if (_isWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los tipos biometricos disponibles (huella, Face ID, iris, etc.).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (_isWeb) return [];
    try {
      final auth = LocalAuthentication();
      return await auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Solicita autenticacion biometrica al usuario.
  /// Muestra un dialogo nativo con el motivo especificado.
  /// Retorna true si la autenticacion fue exitosa.
  /// Usa stickyAuth para mantener la sesion biometrica, y biometricOnly
  /// para evitar que el usuario use el PIN del dispositivo como alternativa.
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
