/// Almacenamiento seguro de datos sensibles del usuario.
/// Usa flutter_secure_storage en dispositivos nativos (iOS Keychain / Android EncryptedSharedPreferences)
/// y SharedPreferences en web como fallback.
/// Almacena: frase semilla cifrada, hash del PIN, preferencia biometrica, direcciones, codigo anti-phishing
/// y tiempo de auto-logout. Cada usuario tiene un prefijo unico para aislar sus datos.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clase que maneja el almacenamiento seguro de datos de la wallet.
/// Todos los metodos son estaticos y multi-plataforma.
class SecureStorage {
  static final bool _isWeb = kIsWeb;

  /// Obtiene la instancia de SharedPreferences para la plataforma web.
  static Future<SharedPreferences> get _webStorage async {
    return SharedPreferences.getInstance();
  }

  /// Almacenamiento seguro nativo (iOS Keychain / Android EncryptedSharedPreferences).
  static const FlutterSecureStorage _nativeStorage = FlutterSecureStorage();

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

  // Claves completas con prefijo de usuario
  static String get _seedKey => '${_userPrefix}$_seedKeySuffix';
  static String get _pinHashKey => '${_userPrefix}$_pinHashKeySuffix';
  static String get _pinSaltKey => '${_userPrefix}$_pinSaltKeySuffix';
  static String get _biometricKey => '${_userPrefix}$_biometricKeySuffix';
  static String get _addressesKey => '${_userPrefix}$_addressesKeySuffix';
  static String get _antiPhishingKey => '${_userPrefix}$_antiPhishingKeySuffix';
  static String get _autoLogoutKey => '${_userPrefix}$_autoLogoutKeySuffix';

  /// Configura el prefijo de usuario (llamar al hacer login).
  /// Cada usuario tiene su propio espacio de claves en el almacenamiento.
  static void setUserId(String uid) {
    _userPrefix = '${uid}_';
  }

  /// Limpia el prefijo de usuario (llamar al hacer logout).
  static void clearUserId() {
    _userPrefix = '';
  }

  // ============================================================
  // Helpers de almacenamiento multi-plataforma
  // ============================================================

  /// Escribe un valor en el almacenamiento apropiado segun la plataforma.
  static Future<void> _write(String key, String value) async {
    if (_isWeb) {
      final prefs = await _webStorage;
      await prefs.setString(key, value);
    } else {
      await _nativeStorage.write(key: key, value: value);
    }
  }

  /// Lee un valor del almacenamiento apropiado segun la plataforma.
  static Future<String?> _read(String key) async {
    if (_isWeb) {
      final prefs = await _webStorage;
      return prefs.getString(key);
    } else {
      return await _nativeStorage.read(key: key);
    }
  }

  /// Verifica si una clave existe y tiene valor no vacio.
  static Future<bool> _has(String key) async {
    final value = await _read(key);
    return value != null && value.isNotEmpty;
  }

  /// Elimina una clave del almacenamiento.
  static Future<void> _delete(String key) async {
    if (_isWeb) {
      final prefs = await _webStorage;
      await prefs.remove(key);
    } else {
      await _nativeStorage.delete(key: key);
    }
  }

  /// Elimina TODAS las claves del almacenamiento.
  static Future<void> _deleteAll() async {
    if (_isWeb) {
      final prefs = await _webStorage;
      await prefs.clear();
    } else {
      await _nativeStorage.deleteAll();
    }
  }

  // ============================================================
  // Frase semilla cifrada
  // ============================================================

  /// Guarda la frase semilla cifrada con AES-256 en almacenamiento seguro.
  static Future<void> saveEncryptedSeed(String encryptedSeed) async {
    await _write(_seedKey, encryptedSeed);
  }

  /// Obtiene la frase semilla cifrada almacenada.
  static Future<String?> getEncryptedSeed() async {
    return await _read(_seedKey);
  }

  /// Verifica si existe una frase semilla guardada.
  static Future<bool> hasSeed() async {
    return await _has(_seedKey);
  }

  // ============================================================
  // Direcciones derivadas de las wallets
  // ============================================================

  /// Guarda las direcciones de las 3 redes (Solana, Bitcoin, BNB) en formato JSON.
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
    await _write(_addressesKey, addresses);
  }

  /// Obtiene las direcciones guardadas como mapa red -> direccion.
  static Future<Map<String, String>?> getAddresses() async {
    final raw = await _read(_addressesKey);
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

  /// Guarda el hash del PIN usando PBKDF2 con salt aleatorio.
  /// Nunca se almacena el PIN en texto plano.
  static Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _write(_pinHashKey, hash);
    await _write(_pinSaltKey, salt);
  }

  /// Verifica si el PIN ingresado es correcto comparando hashes.
  static Future<bool> verifyPin(String pin) async {
    final savedHash = await _read(_pinHashKey);
    final salt = await _read(_pinSaltKey);
    if (savedHash == null || salt == null) return false;
    return _hashPin(pin, salt) == savedHash;
  }

  /// Verifica si existe un PIN configurado.
  static Future<bool> hasPin() async {
    return await _has(_pinHashKey);
  }

  /// Genera un hash PBKDF2 del PIN con el salt proporcionado.
  /// Usa 100,000 iteraciones para dificultar ataques de fuerza bruta.
  static String _hashPin(String pin, String salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    pbkdf2.init(Pbkdf2Parameters(saltBytes, 100000, 32));
    final hash = pbkdf2.process(Uint8List.fromList(utf8.encode(pin)));
    return base64.encode(hash);
  }

  /// Genera un salt aleatorio de 16 bytes en base64 usando Random.secure().
  static String _generateSalt() {
    final random = Random.secure();
    return base64.encode(Uint8List.fromList(List.generate(16, (_) => random.nextInt(256))));
  }

  // ============================================================
  // Autenticacion biometrica
  // ============================================================

  /// Activa o desactiva la autenticacion biometrica (huella/Face ID).
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _write(_biometricKey, enabled.toString());
  }

  /// Indica si la autenticacion biometrica esta habilitada.
  static Future<bool> isBiometricEnabled() async {
    final value = await _read(_biometricKey);
    return value == 'true';
  }

  // ============================================================
  // Codigo anti-phishing: palabra/imagen que el usuario reconoce
  // ============================================================

  /// Guarda el codigo anti-phishing del usuario.
  /// El usuario configura esta palabra/imagen para verificar que la app es legitima.
  static Future<void> saveAntiPhishingCode(String code) async {
    await _write(_antiPhishingKey, code);
  }

  /// Obtiene el codigo anti-phishing guardado.
  static Future<String?> getAntiPhishingCode() async {
    return await _read(_antiPhishingKey);
  }

  /// Verifica si existe un codigo anti-phishing configurado.
  static Future<bool> hasAntiPhishingCode() async {
    return await _has(_antiPhishingKey);
  }

  // ============================================================
  // Auto-logout por inactividad (minutos)
  // ============================================================

  /// Guarda el tiempo de inactividad antes de bloquear la app (en minutos).
  static Future<void> saveAutoLogoutMinutes(int minutes) async {
    await _write(_autoLogoutKey, minutes.toString());
  }

  /// Obtiene el tiempo de inactividad configurado (default: 5 min).
  static Future<int> getAutoLogoutMinutes() async {
    final value = await _read(_autoLogoutKey);
    if (value == null) return 5;
    return int.tryParse(value) ?? 5;
  }

  // ============================================================
  // Limpieza
  // ============================================================

  /// Elimina SOLO los datos del usuario actual (con el prefijo activo).
  /// Conserva los datos de otros usuarios en el mismo dispositivo.
  static Future<void> clearUserData() async {
    await _delete(_seedKey);
    await _delete(_pinHashKey);
    await _delete(_pinSaltKey);
    await _delete(_biometricKey);
    await _delete(_addressesKey);
    await _delete(_antiPhishingKey);
    await _delete(_autoLogoutKey);
  }

  /// Elimina TODOS los datos almacenados (todos los usuarios).
  static Future<void> clearAll() async {
    await _deleteAll();
  }
}
