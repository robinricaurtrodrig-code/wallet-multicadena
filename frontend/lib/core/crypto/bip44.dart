import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';

class BIP44Derivation {
  // Tipos de moneda segun BIP44 para cada red blockchain
  static const Map<String, String> coinTypes = {
    'solana': "501'",  // Solana usa curva Ed25519
    'bitcoin': "0'",   // Bitcoin usa curva secp256k1
    'bnb': "60'",      // BNB Chain (EVM) usa secp256k1, igual que Ethereum
  };

  /// Construye la ruta de derivacion BIP44: m/44'/coinType'/account'/change/addressIndex
  static String getDerivationPath(String network, {int account = 0, int change = 0, int addressIndex = 0}) {
    final coinType = coinTypes[network] ?? "0'";
    return "m/44'/$coinType/$account'/$change/$addressIndex";
  }

  // ============================================================
  // Derivacion de claves HD para Ed25519 (Solana)
  // Usa SLIP-0010 via ed25519_hd_key (compatible con web)
  // ============================================================

  /// Convierte una ruta BIP44 (con niveles no endurecidos) a SLIP-0010
  /// (todos endurecidos), ya que Ed25519 solo soporta derivacion endurecida.
  static String _makeAllHardened(String path) {
    final segments = path.split('/');
    return segments.map((s) {
      if (s == 'm') return s;
      return s.endsWith("'") ? s : "$s'";
    }).join('/');
  }

  static Future<Uint8List> _deriveEd25519Key(Uint8List seed, String path) async {
    final hardenedPath = _makeAllHardened(path);
    final derived = await ED25519_HD_KEY.derivePath(hardenedPath, seed);
    return Uint8List.fromList(derived.key);
  }

  static Future<Uint8List> _getEd25519PublicKey(Uint8List privateKey) async {
    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPairFromSeed(privateKey);
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  // ============================================================
  // Derivacion de claves privadas para cada red
  // ============================================================

  /// Deriva la clave privada de Solana usando la curva Ed25519
  static Future<Uint8List> deriveSolanaKey(Uint8List seed, {int account = 0}) async {
    final path = getDerivationPath('solana', account: account);
    return await _deriveEd25519Key(seed, path);
  }

  /// Deriva la clave privada de Bitcoin usando secp256k1 (BIP32)
  static bip32.BIP32 deriveBitcoinKey(Uint8List seed, {int account = 0}) {
    final path = getDerivationPath('bitcoin', account: account);
    final root = bip32.BIP32.fromSeed(seed);
    return root.derivePath(path);
  }

  /// Deriva la clave privada de BNB Chain usando secp256k1 (BIP32)
  static bip32.BIP32 deriveBNBKey(Uint8List seed, {int account = 0}) {
    final path = getDerivationPath('bnb', account: account);
    final root = bip32.BIP32.fromSeed(seed);
    return root.derivePath(path);
  }

  // ============================================================
  // Metodos para convertir semillas en direcciones publicas
  // Estos metodos son la entrada principal desde WalletProvider
  // ============================================================

  /// Deriva la direccion publica de Solana desde la semilla BIP39
  /// Formato: base58 de la clave publica Ed25519 (32 bytes)
  static Future<String> deriveSolanaAddress(Uint8List seed, {int account = 0}) async {
    final privateKeyBytes = await deriveSolanaKey(seed, account: account);
    final publicKeyBytes = await _getEd25519PublicKey(privateKeyBytes);
    return base58Encode(publicKeyBytes);
  }

  /// Deriva la direccion publica de Bitcoin desde la semilla BIP39
  /// Formato: bech32 P2WPKH nativa (bc1...)
  static String deriveBitcoinAddress(Uint8List seed, {int account = 0}) {
    final path = getDerivationPath('bitcoin', account: account);
    final root = bip32.BIP32.fromSeed(seed);
    final derivedKey = root.derivePath(path);

    // La propiedad .identifier de BIP32 contiene el HASH160 de la clave publica
    // HASH160 = RIPEMD160(SHA256(clave_publica_comprimida))
    final pubkeyHash = derivedKey.identifier;  // 20 bytes

    return generateP2PKHAddress(pubkeyHash);
  }

  /// Deriva la direccion publica de BNB Chain desde la semilla BIP39
  /// Formato: 0x + 20 bytes hex (compatible con Ethereum/EVM)
  static String deriveBNBAddress(Uint8List seed, {int account = 0}) {
    final path = getDerivationPath('bnb', account: account);
    final root = bip32.BIP32.fromSeed(seed);
    final derivedKey = root.derivePath(path);

    // La propiedad .publicKey de BIP32 retorna la clave publica sin comprimir
    // Formato: 0x04 + X (32 bytes) + Y (32 bytes) = 65 bytes total
    final publicKey = derivedKey.publicKey;

    // Para direcciones EVM se necesitan los ultimos 20 bytes del keccak256
    // de la clave publica SIN el prefijo 0x04
    final publicKeyWithoutPrefix = publicKey.sublist(1);  // 64 bytes

    // Calcular keccak256 de la clave publica (sin prefijo)
    final hash = keccak256(publicKeyWithoutPrefix);

    // Tomar los ultimos 20 bytes como direccion EVM
    final addressBytes = hash.sublist(12, 32);  // bytes 12-31 = 20 bytes

    // Convertir a hex con prefijo 0x
    return '0x${HEX.encode(addressBytes)}';
  }

  // ============================================================
  // Metodos de ayuda para conversion de direcciones
  // ============================================================

  /// Genera una direccion P2PKH legacy (1...) a partir del HASH160
  static String generateP2PKHAddress(Uint8List pubkeyHash) {
    final versionByte = Uint8List.fromList([0x00]);
    final versionedHash = Uint8List.fromList([...versionByte, ...pubkeyHash]);
    final checksum = sha256(sha256(versionedHash)).sublist(0, 4);
    final binaryAddress = Uint8List.fromList([...versionedHash, ...checksum]);
    return base58Encode(binaryAddress);
  }

  // ============================================================
  // Codificacion Base58
  // ============================================================

  static const String _base58Alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String base58Encode(Uint8List bytes) {
    BigInt value = BigInt.from(0);
    for (final byte in bytes) {
      value = (value << 8) + BigInt.from(byte);
    }

    String result = '';
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      value = value ~/ BigInt.from(58);
      result = _base58Alphabet[remainder] + result;
    }

    for (final byte in bytes) {
      if (byte == 0) {
        result = '1$result';
      } else {
        break;
      }
    }

    return result;
  }

  // ============================================================
  // Funciones de hash criptografico
  // ============================================================

  static Uint8List sha256(Uint8List data) {
    final hasher = SHA256Digest();
    return hasher.process(data);
  }

  static Uint8List ripemd160(Uint8List data) {
    final hasher = RIPEMD160Digest();
    return hasher.process(data);
  }

  static Uint8List keccak256(Uint8List data) {
    final hasher = KeccakDigest(256);
    return hasher.process(data);
  }
}
