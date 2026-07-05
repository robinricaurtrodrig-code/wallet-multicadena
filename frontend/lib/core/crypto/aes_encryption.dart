import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';

class AESEncryption {
  static const int keyLength = 32; // AES-256
  static const int ivLength = 16;  // 128 bits para CBC
  static const int pbkdf2Iterations = 600000; // Iteraciones PBKDF2 (OWASP 2024)

  /// Deriva una clave AES-256 a partir de una contrasena usando PBKDF2-HMAC-SHA256
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, pbkdf2Iterations, keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Genera bytes aleatorios criptograficamente seguros usando Random.secure()
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  /// Calcula HMAC-SHA256 para autenticar el cifrado (encrypt-then-MAC)
  static Uint8List _computeHmac(Uint8List key, Uint8List data) {
    final hmac = HMac(SHA256Digest(), 64);
    hmac.init(KeyParameter(key));
    return hmac.process(data);
  }

  /// Cifra un texto plano con AES-256-CBC + HMAC-SHA256
  /// Retorna: salt (16) + iv (16) + hmac (32) + ciphertext en base64
  static String encrypt(String plaintext, String password) {
    final salt = _generateRandomBytes(16);
    final iv = _generateRandomBytes(ivLength);
    final key = _deriveKey(password, salt);

    // Cifrar con AES-256 en modo CBC
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));

    final paddedData = _pad(utf8.encode(plaintext));
    final encrypted = Uint8List(paddedData.length);
    var offset = 0;
    while (offset < paddedData.length) {
      offset += cipher.processBlock(paddedData, offset, encrypted, offset);
    }

    // Calcular HMAC del ciphertext (encrypt-then-MAC)
    final hmac = _computeHmac(key, encrypted);

    // Empaquetar: salt + iv + hmac + encrypted
    final result = BytesBuilder()
      ..add(salt)
      ..add(iv)
      ..add(hmac)
      ..add(encrypted);
    return base64.encode(result.toBytes());
  }

  /// Descifra un texto cifrado con AES-256-CBC + HMAC-SHA256
  static String decrypt(String ciphertext, String password) {
    final data = base64.decode(ciphertext);
    final salt = data.sublist(0, 16);
    final iv = data.sublist(16, 32);
    final hmac = data.sublist(32, 64);
    final encrypted = data.sublist(64);
    final key = _deriveKey(password, salt);

    // Verificar HMAC primero (integrity check)
    final expectedHmac = _computeHmac(key, encrypted);
    if (!_constantTimeEquals(hmac, expectedHmac)) {
      throw Exception('Integridad comprometida: el ciphertext fue modificado');
    }

    // Descifrar con AES-256 en modo CBC
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));

    final decrypted = Uint8List(encrypted.length);
    var offset = 0;
    while (offset < encrypted.length) {
      offset += cipher.processBlock(encrypted, offset, decrypted, offset);
    }

    final unpadded = _unpad(decrypted);
    return utf8.decode(unpadded);
  }

  /// Comparacion en tiempo constante para evitar timing attacks
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Padding PKCS7: cada byte de relleno es igual al numero de bytes de relleno
  static Uint8List _pad(Uint8List data) {
    final padLength = 16 - (data.length % 16);
    final padded = Uint8List(data.length + padLength);
    padded.setAll(0, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  /// Remueve el padding PKCS7
  static Uint8List _unpad(Uint8List data) {
    final padLength = data.last;
    if (padLength < 1 || padLength > 16) {
      throw Exception('Padding invalido');
    }
    return data.sublist(0, data.length - padLength);
  }
}
