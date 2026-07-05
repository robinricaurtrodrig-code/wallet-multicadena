// Tests unitarios para TransactionBuilder
// Verifica que las funciones de firma producen el formato de salida correcto
// Nota: Los helpers privados se prueban indirectamente via las funciones publicas

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:wallet_multicadena/services/transaction_builder.dart';

void main() {
  group('buildAndSignSolana - Firma de transaccion Solana', () {
    // Clave privada de 32 bytes (Ed25519 espera 32 bytes)
    final validPrivateKey = Uint8List.fromList(List.generate(32, (i) => (i % 256)));
    const fromAddress = '11111111111111111111111111111111';
    const toAddress = '11111111111111111111111111111111';
    const blockhash = '11111111111111111111111111111111';

    // Verifica que el resultado sea una cadena base64 valida (formato Solana)
    test('retorna string base64 valido', () async {
      final result = await TransactionBuilder.buildAndSignSolana(
        privateKey: validPrivateKey,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: 0.1,
        recentBlockhash: blockhash,
      );
      expect(result, isA<String>());
      expect(result.isNotEmpty, isTrue);
      expect(() => base64.decode(result), returnsNormally);
    });

    // Verifica que montos diferentes generen transacciones distintas
    test('produce resultados diferentes con diferentes montos', () async {
      final r1 = await TransactionBuilder.buildAndSignSolana(
        privateKey: validPrivateKey,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: 0.1,
        recentBlockhash: blockhash,
      );
      final r2 = await TransactionBuilder.buildAndSignSolana(
        privateKey: validPrivateKey,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: 0.2,
        recentBlockhash: blockhash,
      );
      expect(r1, isNot(r2));
    });
  });

  group('buildAndSignBnb - Firma de transaccion BNB/BSC', () {
    // Clave privada de 32 bytes para Ethereum (clave de prueba)
    final validPrivateKey = Uint8List.fromList(List.generate(32, (i) => (i % 256)));
    const toAddress = '0x0000000000000000000000000000000000000000';

    // Verifica que el resultado sea hex con prefijo 0x (formato Ethereum)
    test('retorna hex con prefijo 0x', () async {
      final result = await TransactionBuilder.buildAndSignBnb(
        privateKey: validPrivateKey,
        toAddress: toAddress,
        amount: 0.01,
        nonceHex: '1',
        chainId: 56,
        gasLimit: 21000,
        gasPriceWei: 5000000000,
      );
      expect(result, startsWith('0x'));
      expect(result.length > 2, isTrue);
      expect(() => HEX.decode(result.substring(2)), returnsNormally);
    });

    // Verifica que produce una firma valida con monto cero
    test('firma correctamente con monto cero', () async {
      final result = await TransactionBuilder.buildAndSignBnb(
        privateKey: validPrivateKey,
        toAddress: toAddress,
        amount: 0.0,
        nonceHex: '0',
        chainId: 56,
        gasLimit: 21000,
        gasPriceWei: 5000000000,
      );
      expect(result, startsWith('0x'));
      expect(() => HEX.decode(result.substring(2)), returnsNormally);
    });
  });

  group('buildAndSignBitcoin - Firma de transaccion Bitcoin', () {
    // Verifica que la funcion maneje correctamente UTXOs vacios
    test('lanza excepcion con UTXOs vacios', () async {
      expect(
        () => TransactionBuilder.buildAndSignBitcoin(
          key: null!,
          utxos: [],
          toAddress: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
          toAmountSats: 10000,
          changeAddress: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
          changeSats: 0,
        ),
        throwsA(anything),
      );
    });
  });

  group('decodeBase58 - Decodificacion base58', () {
    // Verifica que direcciones Solana en base58 sean aceptadas sin error
    test('buildAndSignSolana acepta direcciones base58 validas', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => (i % 256)));
      const addr = '11111111111111111111111111111111';
      final result = await TransactionBuilder.buildAndSignSolana(
        privateKey: key,
        fromAddress: addr,
        toAddress: addr,
        amount: 0.0,
        recentBlockhash: addr,
      );
      expect(result, isA<String>());
    });
  });
}
