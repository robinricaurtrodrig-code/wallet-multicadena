import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_multicadena/core/crypto/bip39.dart';
import 'package:wallet_multicadena/core/crypto/bip44.dart';
import 'package:wallet_multicadena/core/crypto/aes_encryption.dart';

void main() {
  group('BIP39Service - Frase semilla', () {
    test('generateSeedPhrase produce 12 palabras', () {
      final phrase = BIP39Service.generateSeedPhrase(wordCount: 12);
      final words = phrase.split(' ');
      expect(words.length, 12);
    });

    test('generateSeedPhrase produce 24 palabras', () {
      final phrase = BIP39Service.generateSeedPhrase(wordCount: 24);
      final words = phrase.split(' ');
      expect(words.length, 24);
    });

    test('generateSeedPhrase produce frases diferentes cada vez', () {
      final p1 = BIP39Service.generateSeedPhrase();
      final p2 = BIP39Service.generateSeedPhrase();
      expect(p1, isNot(p2));
    });

    test('validateSeedPhrase acepta frase valida', () {
      final phrase = BIP39Service.generateSeedPhrase();
      expect(BIP39Service.validateSeedPhrase(phrase), isTrue);
    });

    test('validateSeedPhrase rechaza frase invalida', () {
      expect(BIP39Service.validateSeedPhrase('palabra invalida xyz'), isFalse);
    });

    test('mnemonicToSeed produce 64 bytes', () {
      final phrase = BIP39Service.generateSeedPhrase();
      final seed = BIP39Service.mnemonicToSeed(phrase);
      expect(seed.length, 64);
    });

    test('mnemonicToSeed produce seed determinista', () {
      const phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final seed1 = BIP39Service.mnemonicToSeed(phrase);
      final seed2 = BIP39Service.mnemonicToSeed(phrase);
      expect(seed1, seed2);
    });

    test('getWordList divide frase en palabras', () {
      const phrase = 'hola mundo test wallet';
      final words = BIP39Service.getWordList(phrase);
      expect(words, ['hola', 'mundo', 'test', 'wallet']);
    });
  });

  group('BIP44Derivation - Rutas de derivacion', () {
    test('getDerivationPath solana', () {
      expect(BIP44Derivation.getDerivationPath('solana'), "m/44'/501'/0'/0/0");
    });

    test('getDerivationPath bitcoin', () {
      expect(BIP44Derivation.getDerivationPath('bitcoin'), "m/44'/0'/0'/0/0");
    });

    test('getDerivationPath bnb', () {
      expect(BIP44Derivation.getDerivationPath('bnb'), "m/44'/60'/0'/0/0");
    });

    test('getDerivationPath con parametros personalizados', () {
      final path = BIP44Derivation.getDerivationPath('bitcoin', account: 1, change: 2, addressIndex: 3);
      expect(path, "m/44'/0'/1'/2/3");
    });
  });

  group('BIP44Derivation - Base58', () {
    test('base58Encode codifica correctamente', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02]);
      final encoded = BIP44Derivation.base58Encode(bytes);
      expect(encoded, isA<String>());
      expect(encoded.isNotEmpty, isTrue);
    });

    test('base58Encode maneja bytes cero al inicio', () {
      final bytes = Uint8List.fromList([0x00, 0x00, 0x01]);
      final encoded = BIP44Derivation.base58Encode(bytes);
      expect(encoded.startsWith('11'), isTrue);
    });

    test('base58Encode arreglo vacio', () {
      final bytes = Uint8List.fromList([]);
      final encoded = BIP44Derivation.base58Encode(bytes);
      expect(encoded, '');
    });
  });

  group('BIP44Derivation - Funciones hash', () {
    test('sha256 produce 32 bytes', () {
      final input = Uint8List.fromList([104, 101, 108, 108, 111]); // "hello"
      final hash = BIP44Derivation.sha256(input);
      expect(hash.length, 32);
    });

    test('ripemd160 produce 20 bytes', () {
      final input = Uint8List.fromList([104, 101, 108, 108, 111]);
      final hash = BIP44Derivation.ripemd160(input);
      expect(hash.length, 20);
    });

    test('keccak256 produce 32 bytes', () {
      final input = Uint8List.fromList([104, 101, 108, 108, 111]);
      final hash = BIP44Derivation.keccak256(input);
      expect(hash.length, 32);
    });

    test('sha256 es determinista', () {
      final input = Uint8List.fromList([116, 101, 115, 116]);
      final h1 = BIP44Derivation.sha256(input);
      final h2 = BIP44Derivation.sha256(input);
      expect(h1, h2);
    });
  });

  group('BIP44Derivation - Direcciones', () {
    test('generateP2PKHAddress produce direccion base58 valida', () {
      final pubkeyHash = Uint8List.fromList(List.generate(20, (i) => i));
      final address = BIP44Derivation.generateP2PKHAddress(pubkeyHash);
      expect(address, isA<String>());
      expect(address.startsWith('1'), isTrue);
      expect(address.length, greaterThan(25));
    });

    test('deriveBNBAddress produce direccion 0x... de 42 caracteres', () async {
      final seed = Uint8List(64);
      final address = BIP44Derivation.deriveBNBAddress(seed);
      expect(address.startsWith('0x'), isTrue);
      expect(address.length, 42);
    });
  });

  group('AESEncryption - Cifrado y descifrado', () {
    const password = 'MiContrasenaSegura123!';
    const plaintext = 'frase semilla de prueba con doce palabras exactas';

    test('encrypt retorna string base64', () {
      final encrypted = AESEncryption.encrypt(plaintext, password);
      expect(encrypted, isA<String>());
      expect(encrypted.isNotEmpty, isTrue);
      // Verificar que sea base64 valido
      expect(() => base64.decode(encrypted), returnsNormally);
    });

    test('decrypt recupera el texto original', () {
      final encrypted = AESEncryption.encrypt(plaintext, password);
      final decrypted = AESEncryption.decrypt(encrypted, password);
      expect(decrypted, plaintext);
    });

    test('encrypt produce resultados diferentes cada vez (con salt aleatorio)', () {
      final e1 = AESEncryption.encrypt(plaintext, password);
      final e2 = AESEncryption.encrypt(plaintext, password);
      expect(e1, isNot(e2));
    });

    test('decrypt falla con contrasena incorrecta', () {
      final encrypted = AESEncryption.encrypt(plaintext, password);
      expect(
        () => AESEncryption.decrypt(encrypted, 'ContrasenaIncorrecta'),
        throwsA(isA<Exception>()),
      );
    });

    test('decrypt falla con ciphertext corrupto', () {
      final encrypted = AESEncryption.encrypt(plaintext, password);
      final bytes = base64.decode(encrypted);
      bytes[70] ^= 0xFF; // Corromper un byte del ciphertext
      final corrupted = base64.encode(bytes);
      expect(
        () => AESEncryption.decrypt(corrupted, password),
        throwsA(isA<Exception>()),
      );
    });

    test('cifra y descifra textos vacios', () {
      const empty = '';
      final encrypted = AESEncryption.encrypt(empty, password);
      final decrypted = AESEncryption.decrypt(encrypted, password);
      expect(decrypted, empty);
    });

    test('cifra y descifra textos largos', () {
      final longText = 'A' * 10000;
      final encrypted = AESEncryption.encrypt(longText, password);
      final decrypted = AESEncryption.decrypt(encrypted, password);
      expect(decrypted, longText);
    });

    test('cifra y descifra con diferentes contrasenas', () {
      const msg = 'mensaje secreto';
      final encrypted = AESEncryption.encrypt(msg, 'pass1');
      final decrypted = AESEncryption.decrypt(encrypted, 'pass1');
      expect(decrypted, msg);
    });

    test('cifrado con password especial (unicode)', () {
      const msg = 'datos sensibles';
      const unicodePass = 'clave_ñ_ü_áéíóú_👍';
      final encrypted = AESEncryption.encrypt(msg, unicodePass);
      final decrypted = AESEncryption.decrypt(encrypted, unicodePass);
      expect(decrypted, msg);
    });
  });
}
