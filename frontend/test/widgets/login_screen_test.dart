import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wallet_multicadena/controllers/auth_provider.dart';
import 'package:wallet_multicadena/controllers/wallet_provider.dart';
import 'package:wallet_multicadena/controllers/security_provider.dart';
import 'package:wallet_multicadena/views/auth/login_screen.dart';
import 'package:wallet_multicadena/config/theme.dart';
import '../helpers/mock_providers.dart';
import '../helpers/firebase_setup.dart';

Widget createLoginScreen({
  AuthProvider? authProvider,
  WalletProvider? walletProvider,
  SecurityProvider? securityProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockAuth(),
      ),
      ChangeNotifierProvider<WalletProvider>.value(
        value: walletProvider ?? MockWallet(),
      ),
      ChangeNotifierProvider<SecurityProvider>.value(
        value: securityProvider ?? MockSecurity(),
      ),
    ],
    child: MaterialApp(
      home: const LoginScreen(),
      theme: AppTheme.darkTheme,
    ),
  );
}

void main() {
  setupFirebaseMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('LoginScreen', () {
    testWidgets('renderiza titulo y campos de entrada', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Wallet\nMulticadena'), findsOneWidget);
      expect(find.text('Inicia sesion para gestionar tus activos'), findsOneWidget);
      expect(find.text('Iniciar Sesion'), findsOneWidget);
      expect(find.text('No tienes cuenta? Registrate'), findsOneWidget);
      expect(find.text('Olvide mi contrasena'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('valida que el correo contenga @', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'invalido');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Iniciar Sesion'));
      await tester.pumpAndSettle();

      expect(find.text('Correo invalido'), findsOneWidget);
    });

    testWidgets('valida longitud minima de contrasena', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text('Iniciar Sesion'));
      await tester.pumpAndSettle();

      expect(find.text('Minimo 6 caracteres'), findsOneWidget);
    });

    testWidgets('muestra indicador de carga durante login', (tester) async {
      final auth = MockAuth();
      auth.status = AuthStatus.unauthenticated;

      await tester.pumpWidget(createLoginScreen(authProvider: auth));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'user@test.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');

      auth.status = AuthStatus.loading;
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('muestra error del proveedor', (tester) async {
      final auth = MockAuth();
      auth.error = 'Credenciales invalidas';

      await tester.pumpWidget(createLoginScreen(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.text('Credenciales invalidas'), findsOneWidget);
    });

    testWidgets('alterna visibilidad de contrasena', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextFormField).last;
      final textField = find.descendant(
        of: passwordField,
        matching: find.byType(TextField),
      ).first;
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      final textFieldWidget2 = tester.widget<TextField>(textField);
      expect(textFieldWidget2.obscureText, isFalse);
    });

    testWidgets('limpia error al escribir en campos', (tester) async {
      final auth = MockAuth();
      auth.error = 'Error anterior';

      await tester.pumpWidget(createLoginScreen(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.text('Error anterior'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'nuevo@correo.com');
      await tester.pumpAndSettle();

      expect(auth.error, isNull);
    });
  });
}
