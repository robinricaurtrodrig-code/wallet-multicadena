// DAppService: firma mensajes con claves de Solana, Bitcoin y BNB

import 'dart:typed_data';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';

class DAppService {
  /// Firma mensaje con Ed25519 (Solana), retorna base64
  static Future<String> signSolanaMessage({
    required Uint8List privateKey,
    required String message,
  }) async {
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final hash = _sha512(privateKey);
    final publicKey = SimplePublicKey(
      Uint8List.fromList(hash.sublist(32)),
      type: KeyPairType.ed25519,
    );
    final keyPair = SimpleKeyPairData(
      privateKey,
      publicKey: publicKey,
      type: KeyPairType.ed25519,
    );
    final ed25519 = Ed25519();
    final sig = await ed25519.sign(msgBytes, keyPair: keyPair);
    return base64.encode(Uint8List.fromList(sig.bytes));
  }

  /// Firma mensaje con personal_sign de Ethereum (BNB), retorna hex
  static String signBnbMessage({
    required Uint8List privateKey,
    required String message,
  }) {
    final credentials = EthPrivateKey.fromHex(HEX.encode(privateKey));
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final sig = credentials.signPersonalMessageToUint8List(msgBytes);
    return '0x${HEX.encode(sig)}';
  }

  /// Firma mensaje con ECDSA (Bitcoin), retorna hex
  static String signBitcoinMessage({
    required bip32.BIP32 key,
    required String message,
  }) {
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final hash = _doubleSha256(msgBytes);
    final sig = key.sign(hash);
    return HEX.encode(sig);
  }

  static Uint8List _sha256(Uint8List data) {
    final hasher = SHA256Digest();
    return hasher.process(data);
  }

  static Uint8List _sha512(Uint8List data) {
    final hasher = SHA512Digest();
    return hasher.process(data);
  }

  static Uint8List _doubleSha256(Uint8List data) {
    return _sha256(_sha256(data));
  }
}
