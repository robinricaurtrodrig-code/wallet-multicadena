import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // Prefijo para claves por usuario (se asigna en login)
  static String _userPrefix = '';

  // Claves de almacenamiento (con prefijo de usuario)
  static const _seedKeySuffix = 'encrypted_seed_phrase';
  static const _pinHashKeySuffix = 'pin_hash';
  static const _pinSaltKeySuffix = 'pin_salt';
  static const _biometricKeySuffix = 'biometric_enabled';
  static const _addressesKeySuffix = 'wallet_addresses';
  static const _antiPhishingKeySuffix = 'anti_phishing_code';
  static const _autoLogoutKeySuffix = 'auto_logout_minutes';

  static String get _seedKey => '${_userPrefix}$_seedKeySuffix';
  static String get _pinHashKey => '${_userPrefix}$_pinHashKeySuffix';
  static String get _pinSaltKey => '${_userPrefix}$_pinSaltKeySuffix';
  static String get _biometricKey => '${_userPrefix}$_biometricKeySuffix';
  static String get _addressesKey => '${_userPrefix}$_addressesKeySuffix';
  static String get _antiPhishingKey => '${_userPrefix}$_antiPhishingKeySuffix';
  static String get _autoLogoutKey => '${_userPrefix}$_autoLogoutKeySuffix';

  /// Configura el prefijo de usuario (llamar al hacer login)
  static void setUserId(String uid) {
    _userPrefix = '${uid}_';
  }

  /// Limpia el prefijo de usuario (llamar al hacer logout)
  static void clearUserId() {
    _userPrefix = '';
  }

  // ============================================================
  // Frase semilla cifrada
  // ============================================================

  static Future<void> saveEncryptedSeed(String encryptedSeed) async {
    await _storage.write(key: _seedKey, value: encryptedSeed);
  }

  static Future<String?> getEncryptedSeed() async {
    return await _storage.read(key: _seedKey);
  }

  static Future<bool> hasSeed() async {
    final seed = await _storage.read(key: _seedKey);
    return seed != null && seed.isNotEmpty;
  }

  // ============================================================
  // Direcciones derivadas de las wallets
  // ============================================================

  /// Guarda las direcciones de las 3 redes en formato JSON
  static Future<void> saveAddresses({
    required String solana,
    required String bitcoin,
    required String bnb,
  }) async {
    final addresses = json.encode({
      'solana': solana,
      'bitcoin': bitcoin,
      'bnb': bnb,
    });
    await _storage.write(key: _addressesKey, value: addresses);
  }

  /// Obtiene las direcciones guardadas
  static Future<Map<String, String>?> getAddresses() async {
    final raw = await _storage.read(key: _addressesKey);
    if (raw == null) return null;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return {
      'solana': decoded['solana'] as String,
      'bitcoin': decoded['bitcoin'] as String,
      'bnb': decoded['bnb'] as String,
    };
  }

  // ============================================================
  // PIN de acceso (almacenado como hash PBKDF2, nunca en texto plano)
  // ============================================================

  /// Guarda el hash del PIN usando PBKDF2 con salt aleatorio
  static Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: salt);
  }

  /// Verifica si el PIN ingresado es correcto
  static Future<bool> verifyPin(String pin) async {
    final savedHash = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    if (savedHash == null || salt == null) return false;
    return _hashPin(pin, salt) == savedHash;
  }

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinHashKey);
    return pin != null && pin.isNotEmpty;
  }

  /// Genera un hash PBKDF2 del PIN con el salt proporcionado
  static String _hashPin(String pin, String salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    pbkdf2.init(Pbkdf2Parameters(saltBytes, 100000, 32));
    final hash = pbkdf2.process(Uint8List.fromList(utf8.encode(pin)));
    return base64.encode(hash);
  }

  /// Genera un salt aleatorio de 16 bytes en base64 usando Random.secure()
  static String _generateSalt() {
    final random = Random.secure();
    return base64.encode(Uint8List.fromList(List.generate(16, (_) => random.nextInt(256))));
  }

  // ============================================================
  // Autenticacion biometrica
  // ============================================================

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricKey);
    return value == 'true';
  }

  // ============================================================
  // Codigo anti-phishing: palabra/imagen que el usuario reconoce
  // ============================================================

  /// Guarda el codigo anti-phishing del usuario
  static Future<void> saveAntiPhishingCode(String code) async {
    await _storage.write(key: _antiPhishingKey, value: code);
  }

  /// Obtiene el codigo anti-phishing guardado
  static Future<String?> getAntiPhishingCode() async {
    return await _storage.read(key: _antiPhishingKey);
  }

  static Future<bool> hasAntiPhishingCode() async {
    final code = await _storage.read(key: _antiPhishingKey);
    return code != null && code.isNotEmpty;
  }

  // ============================================================
  // Auto-logout por inactividad (minutos)
  // ============================================================

  /// Guarda el tiempo de inactividad antes de bloquear (minutos)
  static Future<void> saveAutoLogoutMinutes(int minutes) async {
    await _storage.write(key: _autoLogoutKey, value: minutes.toString());
  }

  /// Obtiene el tiempo de inactividad configurado (default: 5 min)
  static Future<int> getAutoLogoutMinutes() async {
    final value = await _storage.read(key: _autoLogoutKey);
    if (value == null) return 5;
    return int.tryParse(value) ?? 5;
  }

  // ============================================================
  // Limpieza
  // ============================================================

  /// Elimina SOLO los datos del usuario actual
  static Future<void> clearUserData() async {
    await _storage.delete(key: _seedKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _addressesKey);
    await _storage.delete(key: _antiPhishingKey);
    await _storage.delete(key: _autoLogoutKey);
  }

  /// Elimina TODOS los datos almacenados
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
