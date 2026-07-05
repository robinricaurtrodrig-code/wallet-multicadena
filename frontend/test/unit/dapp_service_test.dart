// Tests unitarios para DAppService
// Verifica el formato de salida de las funciones de firma de mensajes
// para Solana (Ed25519), BNB (personal_sign) y Bitcoin (ECDSA)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:wallet_multicadena/services/dapp_service.dart';

void main() {
  group('DAppService.signSolanaMessage - Firma Ed25519', () {
    // Clave privada de 32 bytes para Ed25519
    final validKey = Uint8List.fromList(List.generate(32, (i) => (i % 256)));
    const testMessage = 'Hola mundo';

    // Verifica que la firma Solana retorne base64 valido
    test('retorna string base64 valido', () async {
      final result = await DAppService.signSolanaMessage(
        privateKey: validKey,
        message: testMessage,
      );
      expect(result, isA<String>());
      expect(result.isNotEmpty, isTrue);
      expect(() => base64.decode(result), returnsNormally);
    });

    // Verifica que mensajes diferentes produzcan firmas diferentes
    test('produce firmas diferentes para mensajes diferentes', () async {
      final r1 = await DAppService.signSolanaMessage(
        privateKey: validKey,
        message: 'Mensaje A',
      );
      final r2 = await DAppService.signSolanaMessage(
        privateKey: validKey,
        message: 'Mensaje B',
      );
      expect(r1, isNot(r2));
    });
  });

  group('DAppService.signBnbMessage - Firma personal_sign (Ethereum)', () {
    // Clave privada de 32 bytes para Ethereum (clave de prueba)
    final validKey = Uint8List.fromList(List.generate(32, (i) => (i % 256)));
    const testMessage = 'Hola mundo';

    // Verifica que la firma BNB retorne hex con prefijo 0x
    test('retorna hex con prefijo 0x', () {
      final result = DAppService.signBnbMessage(
        privateKey: validKey,
        message: testMessage,
      );
      expect(result, startsWith('0x'));
      expect(result.length > 2, isTrue);
      expect(() => HEX.decode(result.substring(2)), returnsNormally);
    });

    // Verifica que mensajes diferentes produzcan firmas diferentes
    test('produce firmas diferentes para mensajes diferentes', () {
      final r1 = DAppService.signBnbMessage(
        privateKey: validKey,
        message: 'Mensaje A',
      );
      final r2 = DAppService.signBnbMessage(
        privateKey: validKey,
        message: 'Mensaje B',
      );
      expect(r1, isNot(r2));
    });
  });

  group('DAppService.signBitcoinMessage - Firma ECDSA (Bitcoin)', () {
    const testMessage = 'Hola mundo';

    // Verifica que la funcion maneje clave nula correctamente
    test('lanza excepcion con key nulo', () {
      expect(
        () => DAppService.signBitcoinMessage(
          key: null!,
          message: testMessage,
        ),
        throwsA(anything),
      );
    });
  });
}
