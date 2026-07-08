/// Servicio BIP39 para generar y validar frases semilla de 12 o 24 palabras.
/// Implementa el estandar BIP39 (Mnemonic code for generating deterministic keys)
/// usado para crear semillas a partir de las cuales se derivan claves HD (BIP32/BIP44).
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;

/// Servicio que encapsula las operaciones del estandar BIP39.
class BIP39Service {
  /// Genera una frase semilla BIP39 de 12 o 24 palabras.
  /// 12 palabras = 128 bits de entropia (recomendado para wallets personales).
  /// 24 palabras = 256 bits de entropia (maxima seguridad, recomendado para wallets institucionales).
  static String generateSeedPhrase({int wordCount = 12}) {
    final strength = wordCount == 24 ? 256 : 128;
    return bip39.generateMnemonic(strength: strength);
  }

  /// Valida que una frase semilla cumpla con el estandar BIP39.
  /// Verifica que todas las palabras esten en la lista oficial BIP39
  /// y que el checksum de entropia sea correcto.
  static bool validateSeedPhrase(String phrase) {
    return bip39.validateMnemonic(phrase);
  }

  /// Divide la frase semilla en palabras individuales (util para UI de verificacion).
  /// Permite mostrar la semilla en una cuadricula o lista verificable.
  static List<String> getWordList(String phrase) {
    return phrase.split(' ');
  }

  /// Convierte la frase semilla a 64 bytes de seed (BIP39).
  /// Aplica la funcion de derivacion PBKDF2 con la contrasena "mnemonic".
  /// Este seed se usa como entrada para la derivacion de claves BIP32/BIP44.
  static Uint8List mnemonicToSeed(String phrase) {
    return bip39.mnemonicToSeed(phrase);
  }
}
