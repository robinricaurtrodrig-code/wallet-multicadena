import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wallet_multicadena/controllers/auth_provider.dart';
import 'package:wallet_multicadena/controllers/wallet_provider.dart';
import 'package:wallet_multicadena/controllers/security_provider.dart';
import 'package:wallet_multicadena/controllers/connectivity_provider.dart';
import 'package:wallet_multicadena/views/auth/login_screen.dart';
import 'package:wallet_multicadena/views/home/home_screen.dart';
import 'package:wallet_multicadena/views/security/lock_screen.dart';
import 'package:wallet_multicadena/app.dart';
import 'package:wallet_multicadena/config/theme.dart';
import '../helpers/mock_providers.dart';
import '../helpers/firebase_setup.dart';

Widget createApp({
  required AuthProvider authProvider,
  required WalletProvider walletProvider,
  required SecurityProvider securityProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<SecurityProvider>.value(value: securityProvider),
      ChangeNotifierProvider<ConnectivityProvider>(create: (_) => ConnectivityProvider()),
    ],
    child: MaterialApp(
      navigatorKey: GlobalKey<NavigatorState>(),
      home: const AuthGate(),
      theme: AppTheme.darkTheme,
    ),
  );
}

void main() {
  setupFirebaseMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('AuthGate - Enrutamiento por estado de autenticacion', () {
    testWidgets('muestra pantalla de carga cuando no inicializado', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.uninitialized;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: MockSecurity(),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('muestra pantalla de carga durante loading', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.loading;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: MockSecurity(),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('muestra LoginScreen cuando no autenticado', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.unauthenticated;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: MockSecurity(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Iniciar Sesion'), findsOneWidget);
    });

    testWidgets('muestra HomeScreen cuando autenticado y no bloqueado', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.authenticated;
      final sec = MockSecurity();
      sec.isLocked = false;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: sec,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(LockScreen), findsNothing);
    });

    testWidgets('muestra LockScreen cuando autenticado y bloqueado', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.authenticated;
      final sec = MockSecurity();
      sec.isLocked = true;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: sec,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('transiciona de carga a login cuando cambia estado', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.loading;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: MockSecurity(),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.status = AuthStatus.unauthenticated;
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('transiciona de login a home al autenticarse', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.unauthenticated;

      await tester.pumpWidget(createApp(
        authProvider: auth,
        walletProvider: MockWallet(),
        securityProvider: MockSecurity(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      auth.status = AuthStatus.authenticated;
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
