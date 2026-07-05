import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;

class BIP39Service {
  /// Genera una frase semilla BIP39 de 12 o 24 palabras
  /// 12 palabras = 128 bits de entropia (recomendado)
  /// 24 palabras = 256 bits de entropia (maxima seguridad)
  static String generateSeedPhrase({int wordCount = 12}) {
    final strength = wordCount == 24 ? 256 : 128;
    return bip39.generateMnemonic(strength: strength);
  }

  /// Valida que una frase semilla cumpla con el estandar BIP39
  /// Verifica que todas las palabras esten en la lista oficial y que el checksum sea correcto
  static bool validateSeedPhrase(String phrase) {
    return bip39.validateMnemonic(phrase);
  }

  /// Divide la frase semilla en palabras individuales (util para UI de verificacion)
  static List<String> getWordList(String phrase) {
    return phrase.split(' ');
  }

  /// Convierte la frase semilla a 64 bytes de seed (BIP39)
  /// Este seed se usa como entrada para la derivacion de claves BIP32/BIP44
  static Uint8List mnemonicToSeed(String phrase) {
    return bip39.mnemonicToSeed(phrase);
  }
}
