// SecurityProvider: gestiona bloqueo de pantalla, auto-logout y anti-phishing
// Proporciona la logica de seguridad del lado del cliente: bloqueo por PIN,
// desbloqueo biometrico, deteccion de inactividad con cierre automatico,
// y codigo anti-phishing para verificar la autenticidad de la app.

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/storage/secure_storage.dart';
import '../services/biometric_service.dart';

class SecurityProvider extends ChangeNotifier {
  // Indica si la pantalla esta bloqueada (requiere PIN o biometria)
  bool _isLocked = false;
  // Disponibilidad de biometria en el dispositivo (huella, rostro, etc.)
  bool _biometricAvailable = false;
  // Timestamp de la ultima interaccion del usuario (milisegundos desde epoch)
  int _lastActivity = DateTime.now().millisecondsSinceEpoch;
  // Codigo anti-phishing configurado por el usuario para identificar la app autentica
  String? _antiPhishingCode;
  // Timer que ejecuta el bloqueo automatico tras el tiempo de inactividad configurado
  Timer? _inactivityTimer;

  bool get isLocked => _isLocked;
  bool get biometricAvailable => _biometricAvailable;
  int get lastActivity => _lastActivity;
  String? get antiPhishingCode => _antiPhishingCode;
  bool get hasAntiPhishing => _antiPhishingCode != null && _antiPhishingCode!.isNotEmpty;

  /// Inicializa el provider cargando las preferencias de seguridad guardadas
  /// Revisa disponibilidad biometrica, codigo anti-phishing y PIN existente
  SecurityProvider() {
    _init();
  }

  /// Carga preferencias de seguridad guardadas al iniciar la app:
  /// - Disponibilidad de biometria
  /// - Codigo anti-phishing almacenado
  /// - Existencia de PIN (si hay PIN, la app inicia bloqueada)
  Future<void> _init() async {
    _biometricAvailable = await BiometricService.isAvailable();
    _antiPhishingCode = await SecureStorage.getAntiPhishingCode();
    final hasPin = await SecureStorage.hasPin();
    if (hasPin) {
      // Si hay PIN configurado, la pantalla comienza bloqueada
      _isLocked = true;
    }
    notifyListeners();
  }

  /// Registra actividad del usuario (reinicia timer de auto-logout)
  /// Debe llamarse en cada interaccion relevante del usuario con la app
  void recordActivity() {
    _lastActivity = DateTime.now().millisecondsSinceEpoch;
    // Reiniciar el timer de inactividad con la nueva marca de tiempo
    _startInactivityTimer();
  }

  /// Inicia el timer de cierre automatico por inactividad
  /// Lee los minutos configurados desde SecureStorage y programa el bloqueo
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    SecureStorage.getAutoLogoutMinutes().then((minutes) {
      _inactivityTimer = Timer(Duration(minutes: minutes), () async {
        final hasPin = await SecureStorage.hasPin();
        // Solo bloquear si hay PIN configurado y la app no esta ya bloqueada
        if (_isLocked == false && hasPin) {
          _isLocked = true;
          notifyListeners();
        }
      });
    });
  }

  /// Intenta desbloquear con PIN
  /// Verifica el PIN contra SecureStorage; retorna true si es correcto
  Future<bool> unlockWithPin(String pin) async {
    final valid = await SecureStorage.verifyPin(pin);
    if (valid) {
      _isLocked = false;
      recordActivity();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Intenta desbloquear con biometria (huella digital, Face ID, etc.)
  /// Usa BiometricService para autenticar al usuario
  Future<bool> unlockWithBiometrics() async {
    final success = await BiometricService.authenticate(
      reason: 'Desbloquea la wallet para continuar',
    );
    if (success) {
      _isLocked = false;
      recordActivity();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Bloquea la pantalla inmediatamente
  /// Cancela el timer de inactividad pendiente (si lo hay)
  void lock() {
    _isLocked = true;
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  /// Configura el codigo anti-phishing
  /// Almacena el codigo en SecureStorage para verificacion futura
  Future<void> setAntiPhishingCode(String code) async {
    _antiPhishingCode = code;
    await SecureStorage.saveAntiPhishingCode(code);
    notifyListeners();
  }

  /// Configura el tiempo de auto-logout en minutos
  /// Guarda el valor en SecureStorage y reinicia el timer de inactividad
  Future<void> setAutoLogoutMinutes(int minutes) async {
    await SecureStorage.saveAutoLogoutMinutes(minutes);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    // Cancelar timer para evitar fugas de memoria
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
