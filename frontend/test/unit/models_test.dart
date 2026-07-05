// Tests unitarios para los modelos de datos (WalletInfo, Transaction, AssetBalance, etc.)
// Verifica la correcta serializacion/deserializacion desde/hacia JSON

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_multicadena/models/asset.dart';
import 'package:wallet_multicadena/models/user.dart';
import 'package:wallet_multicadena/models/wallet.dart';

void main() {
  group('WalletInfo - Informacion de wallet por red', () {
    // Verifica construccion con todos los campos del JSON de la API
    test('fromJson crea instancia correcta con datos completos', () {
      final json = {
        'address': '0x123',
        'network': 'bnb',
        'symbol': 'BNB',
        'balance': 10.5,
        'balance_usd': 3500.0,
        'usd_price': 333.33,
      };
      final info = WalletInfo.fromJson(json);
      expect(info.address, '0x123');
      expect(info.network, 'bnb');
      expect(info.symbol, 'BNB');
      expect(info.balance, 10.5);
      expect(info.balanceUsd, 3500.0);
      expect(info.usdPrice, 333.33);
    });

    // Verifica tolerancia a campos faltantes (resiliencia del modelo)
    test('fromJson usa valores por defecto cuando faltan campos', () {
      final json = <String, dynamic>{};
      final info = WalletInfo.fromJson(json);
      expect(info.address, '');
      expect(info.network, '');
      expect(info.symbol, '');
      expect(info.balance, 0.0);
      expect(info.balanceUsd, 0.0);
      expect(info.usdPrice, 0.0);
    });

    // Verifica conversion automatica de int a double desde JSON
    test('fromJson maneja enteros en campos numericos', () {
      final json = {
        'address': 'abc',
        'network': 'solana',
        'symbol': 'SOL',
        'balance': 5,
        'balance_usd': 750,
        'usd_price': 150,
      };
      final info = WalletInfo.fromJson(json);
      expect(info.balance, 5.0);
      expect(info.balanceUsd, 750.0);
      expect(info.usdPrice, 150.0);
    });
  });

  group('WalletData - Datos agregados de todas las wallets', () {
    // Verifica construccion con lista multiple de wallets
    test('fromJson crea WalletData con lista de wallets', () {
      final json = {
        'balances': [
          {'address': 'addr1', 'network': 'solana', 'symbol': 'SOL'},
          {'address': 'addr2', 'network': 'bitcoin', 'symbol': 'BTC'},
        ],
        'total_usd': 50000.0,
      };
      final data = WalletData.fromJson(json);
      expect(data.wallets.length, 2);
      expect(data.wallets[0].network, 'solana');
      expect(data.wallets[1].network, 'bitcoin');
      expect(data.totalUsd, 50000.0);
    });

    // Verifica comportamiento con lista vacia (usuario nuevo)
    test('fromJson maneja lista vacia', () {
      final json = {'balances': [], 'total_usd': 0.0};
      final data = WalletData.fromJson(json);
      expect(data.wallets, isEmpty);
      expect(data.totalUsd, 0.0);
    });
  });

  group('Transaction - Historial de transacciones', () {
    // Verifica deserializacion completa incluyendo parsing de timestamp ISO
    test('fromJson crea transaccion completa', () {
      final json = {
        'tx_hash': '0xabc123',
        'network': 'bnb',
        'type': 'sent',
        'amount': 1.5,
        'fee': 0.001,
        'status': 'confirmada',
        'explorer_url': 'https://bscscan.com/tx/0xabc123',
        'timestamp': '2026-07-04T10:00:00Z',
      };
      final tx = Transaction.fromJson(json);
      expect(tx.txHash, '0xabc123');
      expect(tx.network, 'bnb');
      expect(tx.type, 'sent');
      expect(tx.amount, 1.5);
      expect(tx.fee, 0.001);
      expect(tx.status, 'confirmada');
      expect(tx.timestamp, DateTime.utc(2026, 7, 4, 10, 0, 0));
    });

    // Verifica valores por defecto cuando el JSON esta vacio
    test('fromJson usa valores por defecto', () {
      final json = <String, dynamic>{};
      final tx = Transaction.fromJson(json);
      expect(tx.txHash, '');
      expect(tx.network, '');
      expect(tx.type, '');
      expect(tx.amount, 0.0);
      expect(tx.fee, 0.0);
      expect(tx.status, 'pendiente');
      expect(tx.timestamp, isNull);
    });
  });

  group('AssetBalance - Modelo de balance de activo', () {
    // Verifica deserializacion de AssetBalance desde JSON
    test('fromJson crea AssetBalance correctamente', () {
      final json = {
        'network': 'solana',
        'symbol': 'SOL',
        'balance': 15.0,
        'balance_usd': 2250.0,
        'usd_price': 150.0,
        'address': 'SolAddr123',
      };
      final asset = AssetBalance.fromJson(json);
      expect(asset.network, 'solana');
      expect(asset.symbol, 'SOL');
      expect(asset.balance, 15.0);
      expect(asset.address, 'SolAddr123');
    });

    // Verifica formato de balance: 4 decimales para montos >= 1
    test('formattedBalance muestra 4 decimales para montos >= 1', () {
      final asset = AssetBalance(
        network: 'bitcoin',
        symbol: 'BTC',
        balance: 1.23456789,
        balanceUsd: 50000,
        usdPrice: 40000,
      );
      expect(asset.formattedBalance, '1.2346');
    });

    // Verifica formato de balance: 6 decimales para montos entre 0.001 y 1
    test('formattedBalance muestra 6 decimales para montos entre 0.001 y 1', () {
      final asset = AssetBalance(
        network: 'solana',
        symbol: 'SOL',
        balance: 0.12345678,
        balanceUsd: 18.5,
        usdPrice: 150,
      );
      expect(asset.formattedBalance, '0.123457');
    });

    // Verifica formato de balance: 8 decimales para montos < 0.001
    test('formattedBalance muestra 8 decimales para montos < 0.001', () {
      final asset = AssetBalance(
        network: 'bnb',
        symbol: 'BNB',
        balance: 0.00012345,
        balanceUsd: 0.04,
        usdPrice: 333,
      );
      expect(asset.formattedBalance, '0.00012345');
    });

    // Verifica seleccion de icono SVG segun simbolo de red
    test('iconPath retorna ruta SVG correcta por simbolo', () {
      final sol = AssetBalance(network: 'solana', symbol: 'SOL', balance: 1, balanceUsd: 150, usdPrice: 150);
      final btc = AssetBalance(network: 'bitcoin', symbol: 'BTC', balance: 1, balanceUsd: 40000, usdPrice: 40000);
      final bnb = AssetBalance(network: 'bnb', symbol: 'BNB', balance: 1, balanceUsd: 333, usdPrice: 333);
      final unknown = AssetBalance(network: 'eth', symbol: 'ETH', balance: 1, balanceUsd: 2000, usdPrice: 2000);

      expect(sol.iconPath, 'assets/icons/solana.svg');
      expect(btc.iconPath, 'assets/icons/bitcoin.svg');
      expect(bnb.iconPath, 'assets/icons/bnb.svg');
      expect(unknown.iconPath, 'assets/icons/crypto.svg');
    });

    // Verifica conversion a WalletInfo para compatibilidad con providers
    test('toWalletInfo convierte correctamente', () {
      final asset = AssetBalance(
        network: 'solana', symbol: 'SOL', balance: 5, balanceUsd: 750, usdPrice: 150, address: 'addr',
      );
      final info = asset.toWalletInfo();
      expect(info.address, 'addr');
      expect(info.network, 'solana');
      expect(info.symbol, 'SOL');
      expect(info.balance, 5);
      expect(info.balanceUsd, 750);
      expect(info.usdPrice, 150);
    });
  });

  group('MarketPrice - Precios desde CoinGecko', () {
    // Verifica deserializacion de los precios de mercado
    test('fromJson crea MarketPrice correctamente', () {
      final json = {
        'solana': 150.25,
        'bitcoin': 40000.0,
        'bnb': 333.50,
        'last_updated': '2026-07-04T12:00:00Z',
      };
      final price = MarketPrice.fromJson(json);
      expect(price.solana, 150.25);
      expect(price.bitcoin, 40000.0);
      expect(price.bnb, 333.50);
      expect(price.lastUpdated, '2026-07-04T12:00:00Z');
    });
  });

  group('UserModel - Datos de usuario desde Firestore', () {
    // Verifica construccion del modelo de usuario
    test('fromJson crea UserModel correctamente', () {
      final json = {
        'uid': 'user123',
        'email': 'test@example.com',
        'username': 'testuser',
        'walletCreada': true,
      };
      final user = UserModel.fromJson(json);
      expect(user.uid, 'user123');
      expect(user.email, 'test@example.com');
      expect(user.username, 'testuser');
      expect(user.walletCreada, isTrue);
    });
  });

  group('UserSettings - Configuracion de usuario', () {
    // Verifica carga completa de configuracion desde JSON
    test('fromJson carga configuracion completa', () {
      final json = {
        'idioma': 'en',
        'tema': 'light',
        'monedaPreferida': 'EUR',
        'notificacionesActivas': false,
        'tokensFavoritos': ['SOL', 'BTC'],
      };
      final settings = UserSettings.fromJson(json);
      expect(settings.idioma, 'en');
      expect(settings.tema, 'light');
      expect(settings.monedaPreferida, 'EUR');
      expect(settings.notificacionesActivas, isFalse);
      expect(settings.tokensFavoritos, ['SOL', 'BTC']);
    });

    // Verifica valores por defecto cuando no hay configuracion guardada
    test('fromJson usa valores por defecto', () {
      final json = <String, dynamic>{};
      final settings = UserSettings.fromJson(json);
      expect(settings.idioma, 'es');
      expect(settings.tema, 'dark');
      expect(settings.monedaPreferida, 'USD');
      expect(settings.notificacionesActivas, isTrue);
      expect(settings.tokensFavoritos, isEmpty);
    });

    // Verifica serializacion a JSON para guardar en Firestore
    test('toJson produce mapa correcto', () {
      final settings = UserSettings(
        idioma: 'pt',
        tema: 'dark',
        monedaPreferida: 'USD',
        notificacionesActivas: true,
        tokensFavoritos: ['BNB'],
      );
      final json = settings.toJson();
      expect(json['idioma'], 'pt');
      expect(json['tema'], 'dark');
      expect(json['monedaPreferida'], 'USD');
      expect(json['notificacionesActivas'], isTrue);
      expect(json['tokensFavoritos'], ['BNB']);
    });
  });
}
