// SecurityProvider: gestiona bloqueo de pantalla, auto-logout y anti-phishing

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/storage/secure_storage.dart';
import '../services/biometric_service.dart';

class SecurityProvider extends ChangeNotifier {
  bool _isLocked = false;
  bool _biometricAvailable = false;
  int _lastActivity = DateTime.now().millisecondsSinceEpoch;
  String? _antiPhishingCode;
  Timer? _inactivityTimer;

  bool get isLocked => _isLocked;
  bool get biometricAvailable => _biometricAvailable;
  int get lastActivity => _lastActivity;
  String? get antiPhishingCode => _antiPhishingCode;
  bool get hasAntiPhishing => _antiPhishingCode != null && _antiPhishingCode!.isNotEmpty;

  SecurityProvider() {
    _init();
  }

  /// Carga preferencias de seguridad guardadas
  Future<void> _init() async {
    _biometricAvailable = await BiometricService.isAvailable();
    _antiPhishingCode = await SecureStorage.getAntiPhishingCode();
    final hasPin = await SecureStorage.hasPin();
    if (hasPin) {
      _isLocked = true;
    }
    notifyListeners();
  }

  /// Registra actividad del usuario (reinicia timer de auto-logout)
  void recordActivity() {
    _lastActivity = DateTime.now().millisecondsSinceEpoch;
    _startInactivityTimer();
  }

  /// Inicia el timer de cierre automatico por inactividad
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    SecureStorage.getAutoLogoutMinutes().then((minutes) {
      _inactivityTimer = Timer(Duration(minutes: minutes), () async {
        final hasPin = await SecureStorage.hasPin();
        if (_isLocked == false && hasPin) {
          _isLocked = true;
          notifyListeners();
        }
      });
    });
  }

  /// Intenta desbloquear con PIN
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

  /// Intenta desbloquear con biometria
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
  void lock() {
    _isLocked = true;
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  /// Configura el codigo anti-phishing
  Future<void> setAntiPhishingCode(String code) async {
    _antiPhishingCode = code;
    await SecureStorage.saveAntiPhishingCode(code);
    notifyListeners();
  }

  /// Configura el tiempo de auto-logout
  Future<void> setAutoLogoutMinutes(int minutes) async {
    await SecureStorage.saveAutoLogoutMinutes(minutes);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
