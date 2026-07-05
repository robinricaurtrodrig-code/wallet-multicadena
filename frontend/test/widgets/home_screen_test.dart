import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wallet_multicadena/providers/auth_provider.dart';
import 'package:wallet_multicadena/providers/wallet_provider.dart';
import 'package:wallet_multicadena/providers/security_provider.dart';
import 'package:wallet_multicadena/screens/home/home_screen.dart';
import 'package:wallet_multicadena/models/wallet.dart';
import 'package:wallet_multicadena/config/theme.dart';
import '../helpers/mock_providers.dart';
import '../helpers/firebase_setup.dart';

Widget createHomeScreen({
  WalletProvider? walletProvider,
  SecurityProvider? securityProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: MockAuth(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(
        value: walletProvider ?? MockWallet(),
      ),
      ChangeNotifierProvider<SecurityProvider>.value(
        value: securityProvider ?? MockSecurity(),
      ),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
      theme: AppTheme.darkTheme,
    ),
  );
}

void main() {
  setupFirebaseMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('HomeScreen - Sin wallet', () {
    testWidgets('muestra icono de wallet y mensaje de bienvenida', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a Wallet Multicadena'), findsOneWidget);
      expect(find.text('Tu wallet descentralizada para Solana, Bitcoin y BNB Chain'), findsOneWidget);
      expect(find.text('Crear nueva wallet'), findsOneWidget);
      expect(find.text('Importar wallet existente'), findsOneWidget);
    });

    testWidgets('muestra titulo de la app en AppBar', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Wallet Multicadena'), findsOneWidget);
    });
  });

  group('HomeScreen - Con wallet', () {
    final mockWallets = [
      WalletInfo(
        address: 'solAddr123',
        network: 'solana',
        symbol: 'SOL',
        balance: 10.5,
        balanceUsd: 1575.0,
        usdPrice: 150.0,
      ),
      WalletInfo(
        address: 'btcAddr456',
        network: 'bitcoin',
        symbol: 'BTC',
        balance: 0.5,
        balanceUsd: 20000.0,
        usdPrice: 40000.0,
      ),
    ];

    testWidgets('muestra balance total en USD', (tester) async {
      final wallet = MockWallet();
      wallet.wallets = mockWallets;
      wallet.hasWallet = true;

      await tester.pumpWidget(createHomeScreen(walletProvider: wallet));
      await tester.pumpAndSettle();

      expect(find.text('Balance Total'), findsOneWidget);
      expect(find.text('\$21575.00'), findsOneWidget);
    });

    testWidgets('muestra lista de activos y boton de firma', (tester) async {
      final wallet = MockWallet();
      wallet.wallets = mockWallets;
      wallet.hasWallet = true;

      await tester.pumpWidget(createHomeScreen(walletProvider: wallet));
      await tester.pumpAndSettle();

      expect(find.text('Tus activos'), findsOneWidget);
      expect(find.text('Firmar Mensaje para DApps'), findsOneWidget);
      expect(find.text('10.500000 SOL'), findsOneWidget);
      expect(find.text('0.500000 BTC'), findsOneWidget);
    });

    testWidgets('muestra iconos de DApps y Seguridad', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.apps), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });
  });

  group('HomeScreen - Estados', () {
    testWidgets('muestra indicador de carga', (tester) async {
      final wallet = MockWallet();
      wallet.hasWallet = true;
      wallet.isLoading = true;

      await tester.pumpWidget(createHomeScreen(walletProvider: wallet));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('muestra mensaje de error', (tester) async {
      final wallet = MockWallet();
      wallet.hasWallet = true;
      wallet.wallets = [
        WalletInfo(address: 'a', network: 'solana', symbol: 'SOL'),
      ];
      wallet.error = 'Error de conexion';

      await tester.pumpWidget(createHomeScreen(walletProvider: wallet));
      await tester.pumpAndSettle();

      expect(find.text('Error de conexion'), findsOneWidget);
    });
  });

  group('HomeScreen - Anti-phishing', () {
    testWidgets('muestra chip anti-phishing cuando esta configurado', (tester) async {
      final sec = MockSecurity();
      sec.antiPhishingCode = 'SEGURO';

      await tester.pumpWidget(createHomeScreen(securityProvider: sec));
      await tester.pumpAndSettle();

      expect(find.text('SEGURO'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('no muestra chip anti-phishing si no esta configurado', (tester) async {
      await tester.pumpWidget(createHomeScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified), findsNothing);
    });
  });
}
