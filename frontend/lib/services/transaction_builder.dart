/// Constructor y firmante de transacciones para Solana, Bitcoin y BNB Chain.
/// Implementa la serializacion y firma de transacciones para las tres redes,
/// incluyendo SystemProgram.transfer (Solana), transacciones legacy P2PKH (Bitcoin)
/// y transacciones EVM estandar (BNB Chain).
import 'dart:typed_data';
import 'dart:convert';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:cryptography/cryptography.dart';

/// Clase que construye y firma transacciones para las redes soportadas.
class TransactionBuilder {

  /// Construye y firma una transaccion Solana (SystemProgram.transfer).
  /// Serializa el mensaje segun el formato de Solana (bincode) y lo firma con Ed25519.
  /// Retorna la transaccion completa en base64.
  static Future<String> buildAndSignSolana({
    required Uint8List privateKey,
    required String fromAddress,
    required String toAddress,
    required double amount,
    required String recentBlockhash,
  }) async {
    final fromPubkey = _decodeBase58(fromAddress);
    final toPubkey = _decodeBase58(toAddress);
    final blockhashBytes = _decodeBase58(recentBlockhash);
    final lamports = (amount * 1e9).toInt();
    final systemProgram = _decodeBase58('11111111111111111111111111111111');

    // Construir el mensaje de la transaccion con header, cuentas, blockhash e instruccion
    final accountKeys = [fromPubkey, toPubkey, systemProgram];
    final header = Uint8List.fromList([1, 0, 1]);
    final instructionData = Uint8List.fromList([2, 0, 0, 0, ..._int64ToLEBytes(lamports)]);
    final instruction = _encodeInstruction(2, [0, 1], instructionData);

    final msgBuilder = BytesBuilder();
    msgBuilder.add(header);
    msgBuilder.add(_encodeCompactArray(accountKeys));
    msgBuilder.add(blockhashBytes);
    msgBuilder.add(_encodeCompactArray([instruction]));
    final message = msgBuilder.toBytes();

    // Derivar clave publica y firmar con Ed25519
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
    final signature = await ed25519.sign(message, keyPair: keyPair);

    // Serializar: firma compacta + mensaje
    final serializedBuilder = BytesBuilder();
    serializedBuilder.add(_encodeCompactArray([Uint8List.fromList(signature.bytes)]));
    serializedBuilder.add(message);
    return base64.encode(serializedBuilder.toBytes());
  }

  /// Construye y firma una transaccion BNB/BSC usando web3dart.
  /// Usa el formato de transaccion estandar de Ethereum.
  /// Retorna la transaccion codificada en RLP + firma, en hex con prefijo 0x.
  static Future<String> buildAndSignBnb({
    required Uint8List privateKey,
    required String toAddress,
    required double amount,
    required String nonceHex,
    required int chainId,
    required int gasLimit,
    required int gasPriceWei,
  }) async {
    final credentials = EthPrivateKey.fromHex(HEX.encode(privateKey));
    final amountWei = BigInt.from((amount * 1e18).round());

    final transaction = Transaction(
      to: EthereumAddress.fromHex(toAddress),
      gasPrice: EtherAmount.inWei(BigInt.from(gasPriceWei)),
      maxGas: gasLimit,
      value: EtherAmount.inWei(amountWei),
      nonce: int.parse(nonceHex, radix: 16),
      data: Uint8List(0),
    );

    final encoded = signTransactionRaw(transaction, credentials, chainId: chainId);
    return '0x${HEX.encode(encoded)}';
  }

  /// Construye y firma una transaccion Bitcoin legacy (P2PKH).
  /// Itera sobre los UTXOs, construye el pre-image para cada input,
  /// firma con ECDSA y serializa la transaccion raw en hex.
  static Future<String> buildAndSignBitcoin({
    required bip32.BIP32 key,
    required List<Map<String, dynamic>> utxos,
    required String toAddress,
    required int toAmountSats,
    required String changeAddress,
    required int changeSats,
  }) async {
    final txVersion = Uint8List.fromList([0x01, 0x00, 0x00, 0x00]);
    final lockTime = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
    final toHash160 = _addressToHash160(toAddress);
    final changeHash160 = _addressToHash160(changeAddress);

    // Preparar inputs desde UTXOs
    final inputs = <Map<String, dynamic>>[];
    for (final utxo in utxos) {
      inputs.add({
        'txid': utxo['txid'] as String,
        'vout': utxo['vout'] as int,
        'script_pub_key': HEX.decode(utxo['script_pub_key'] as String),
      });
    }

    // Preparar outputs: destino y cambio (si aplica)
    final outputs = <Map<String, dynamic>>[];
    outputs.add({'script': _p2pkhScript(toHash160), 'value': toAmountSats});
    if (changeSats > 0) {
      outputs.add({'script': _p2pkhScript(changeHash160), 'value': changeSats});
    }

    // Firmar cada input con SIGHASH_ALL
    for (var i = 0; i < inputs.length; i++) {
      final inp = inputs[i];
      final scriptPubKey = inp['script_pub_key'] as Uint8List;

      final preImageBuilder = BytesBuilder();
      preImageBuilder.add(txVersion);

      // Construir el pre-image para SIGHASH_ALL: scriptPubKey solo en el input actual
      final inputsData = <Uint8List>[];
      for (var j = 0; j < inputs.length; j++) {
        final inpJ = inputs[j];
        final txidBytes = _hexToBytesLE(inpJ['txid'] as String);
        final voutBytes = _int32LE(inpJ['vout'] as int);
        if (j == i) {
          // Input actual: incluir scriptPubKey completo
          final b = BytesBuilder();
          b.add(txidBytes);
          b.add(voutBytes);
          b.add(_encodeVarInt(scriptPubKey.length));
          b.add(scriptPubKey);
          b.add(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
          inputsData.add(b.toBytes());
        } else {
          // Otros inputs: script vacio
          final b = BytesBuilder();
          b.add(txidBytes);
          b.add(voutBytes);
          b.add(Uint8List.fromList([0x00]));
          b.add(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
          inputsData.add(b.toBytes());
        }
      }

      preImageBuilder.add(_encodeVarInt(inputsData.length));
      for (final inpData in inputsData) {
        preImageBuilder.add(inpData);
      }

      preImageBuilder.add(_encodeVarInt(outputs.length));
      for (final out in outputs) {
        final outScript = out['script'] as Uint8List;
        preImageBuilder.add(_int64ToLEBytes(out['value'] as int));
        preImageBuilder.add(_encodeVarInt(outScript.length));
        preImageBuilder.add(outScript);
      }

      preImageBuilder.add(lockTime);
      preImageBuilder.add(Uint8List.fromList([0x01, 0x00, 0x00, 0x00]));

      // Calcular hash del pre-image y firmar
      final hash = _doubleSha256(preImageBuilder.toBytes());
      final sig = key.sign(hash);
      final derSig = _encodeDerSignature(sig);
      final pubkey = key.publicKey;

      // Construir scriptSig con la firma DER y la clave publica
      final scriptSigBuilder = BytesBuilder();
      scriptSigBuilder.add(_encodeVarInt(derSig.length));
      scriptSigBuilder.add(derSig);
      scriptSigBuilder.add(_encodeVarInt(pubkey.length));
      scriptSigBuilder.add(pubkey);
      inp['script_sig'] = scriptSigBuilder.toBytes();
    }

    // Serializar la transaccion raw completa
    final rawTxBuilder = BytesBuilder();
    rawTxBuilder.add(txVersion);

    rawTxBuilder.add(_encodeVarInt(inputs.length));
    for (final inp in inputs) {
      rawTxBuilder.add(_hexToBytesLE(inp['txid'] as String));
      rawTxBuilder.add(_int32LE(inp['vout'] as int));
      final scriptSig = inp['script_sig'] as Uint8List;
      rawTxBuilder.add(_encodeVarInt(scriptSig.length));
      rawTxBuilder.add(scriptSig);
      rawTxBuilder.add(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
    }

    rawTxBuilder.add(_encodeVarInt(outputs.length));
    for (final out in outputs) {
      final outScript = out['script'] as Uint8List;
      rawTxBuilder.add(_int64ToLEBytes(out['value'] as int));
      rawTxBuilder.add(_encodeVarInt(outScript.length));
      rawTxBuilder.add(outScript);
    }

    rawTxBuilder.add(lockTime);
    return HEX.encode(rawTxBuilder.toBytes());
  }

  // ============================================================
  // Funciones auxiliares de serializacion
  // ============================================================

  /// Codifica arreglo con longitud compacta (formato Solana bincode).
  static Uint8List _encodeCompactArray(List<Uint8List> items) {
    final builder = BytesBuilder();
    builder.add(_compactU16Length(items.length));
    for (final item in items) {
      builder.add(item);
    }
    return builder.toBytes();
  }

  /// Compact-u16 de Solana: 1 byte si < 128, 2 bytes si >= 128.
  static Uint8List _compactU16Length(int value) {
    if (value < 128) return Uint8List.fromList([value]);
    return Uint8List.fromList([(value & 0x7F) | 0x80, (value >> 7) & 0x7F]);
  }

  /// Codifica instruccion Solana: programIndex + cuentas + datos (SystemProgram.transfer).
  static Uint8List _encodeInstruction(int programIndex, List<int> accounts, Uint8List data) {
    final builder = BytesBuilder();
    builder.add(Uint8List.fromList([programIndex]));
    builder.add(_compactU16Length(accounts.length));
    for (final acc in accounts) {
      builder.add(Uint8List.fromList([acc]));
    }
    builder.add(_compactU16Length(data.length));
    builder.add(data);
    return builder.toBytes();
  }

  /// Convierte int64 a bytes little-endian (para montos en lamports/satoshis).
  static Uint8List _int64ToLEBytes(int value) {
    final bytes = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Convierte int32 a bytes little-endian (para vout de Bitcoin).
  static Uint8List _int32LE(int value) {
    return Uint8List.fromList([
      value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF,
    ]);
  }

  /// SHA-256 con PointyCastle.
  static Uint8List _sha256(Uint8List data) {
    final hasher = SHA256Digest();
    return hasher.process(data);
  }

  /// SHA-512 con PointyCastle (para derivar clave publica Ed25519).
  static Uint8List _sha512(Uint8List data) {
    final hasher = SHA512Digest();
    return hasher.process(data);
  }

  /// Double SHA-256 (sighash de Bitcoin y checksums).
  static Uint8List _doubleSha256(Uint8List data) {
    return _sha256(_sha256(data));
  }

  /// Decodifica base58 a bytes (direcciones Solana y Bitcoin legacy).
  static Uint8List _decodeBase58(String input) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    BigInt value = BigInt.zero;
    for (var i = 0; i < input.length; i++) {
      value = value * BigInt.from(58) + BigInt.from(alphabet.indexOf(input[i]));
    }
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.insert(0, (value % BigInt.from(256)).toInt());
      value = value ~/ BigInt.from(256);
    }
    // Preservar bytes cero al inicio (se codifican como '1')
    for (var i = 0; i < input.length; i++) {
      if (input[i] == '1') {
        bytes.insert(0, 0);
      } else {
        break;
      }
    }
    return Uint8List.fromList(bytes);
  }

  /// VarInt de Bitcoin: longitud variable segun magnitud.
  /// - < 0xFD: 1 byte
  /// - <= 0xFFFF: 0xFD + 2 bytes
  /// - <= 0xFFFFFFFF: 0xFE + 4 bytes
  /// - > 0xFFFFFFFF: 0xFF + 8 bytes
  static Uint8List _encodeVarInt(int value) {
    if (value < 0xFD) return Uint8List.fromList([value & 0xFF]);
    if (value <= 0xFFFF) return Uint8List.fromList([0xFD, value & 0xFF, (value >> 8) & 0xFF]);
    if (value <= 0xFFFFFFFF) {
      return Uint8List.fromList([0xFE, value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF]);
    }
    final bytes = Uint8List(9);
    bytes[0] = 0xFF;
    for (var i = 0; i < 8; i++) {
      bytes[i + 1] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }

  /// Script P2PKH: OP_DUP OP_HASH160 <hash160> OP_EQUALVERIFY OP_CHECKSIG.
  static Uint8List _p2pkhScript(Uint8List pubkeyHash) {
    return Uint8List.fromList([0x76, 0xA9, 0x14, ...pubkeyHash, 0x88, 0xAC]);
  }

  /// Convierte direccion Bitcoin base58 a hash160 (RIPEMD160 de SHA256).
  /// Si la direccion es de 25 bytes (version+hash+checksum), extrae los bytes 1-21.
  static Uint8List _addressToHash160(String address) {
    final decoded = _decodeBase58(address);
    if (decoded.length == 25) {
      return decoded.sublist(1, 21);
    }
    final sha = _sha256(Uint8List.fromList(address.codeUnits));
    final hasher = RIPEMD160Digest();
    return hasher.process(sha);
  }

  /// Convierte hex a bytes little-endian (txid de Bitcoin en inputs).
  static Uint8List _hexToBytesLE(String hex) {
    final bytes = HEX.decode(hex);
    return Uint8List.fromList(bytes.reversed.toList());
  }

  /// Codifica firma ECDSA en DER + SIGHASH_ALL: 0x30 + len + r + s + 0x01.
  static Uint8List _encodeDerSignature(Uint8List sig) {
    final rLen = sig.length ~/ 2;
    final r = _encodeDerInt(sig.sublist(0, rLen));
    final s = _encodeDerInt(sig.sublist(rLen));
    final builder = BytesBuilder();
    builder.add(Uint8List.fromList([0x30]));
    builder.add(_encodeVarInt(r.length + s.length));
    builder.add(r);
    builder.add(s);
    builder.add(Uint8List.fromList([0x01]));
    return builder.toBytes();
  }

  /// Codifica entero en DER: 0x02 + length + bytes, con padding si MSB=1.
  /// Recorta ceros a la izquierda y anade un byte 0x00 si el MSB es 1.
  static Uint8List _encodeDerInt(Uint8List bytes) {
    int i = 0;
    while (i < bytes.length && bytes[i] == 0) {
      i++;
    }
    var trimmed = bytes.sublist(i);
    if (trimmed.isEmpty) {
      trimmed = Uint8List.fromList([0]);
    }
    if ((trimmed[0] & 0x80) != 0) {
      trimmed = Uint8List.fromList([0x00, ...trimmed]);
    }
    final builder = BytesBuilder();
    builder.add(Uint8List.fromList([0x02]));
    builder.add(_encodeVarInt(trimmed.length));
    builder.add(trimmed);
    return builder.toBytes();
  }
}
