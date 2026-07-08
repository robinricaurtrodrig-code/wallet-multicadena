/// Archivo de configuracion de la aplicacion Wallet Multicadena.
/// Define el widget raiz WalletApp con temas claro/oscuro,
/// el guardian de autenticacion AuthGate y el guardian de bloqueo LockGate.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_provider.dart';
import 'controllers/security_provider.dart';
import 'config/theme.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_screen.dart';
import 'views/security/lock_screen.dart';
import 'widgets/connectivity_banner.dart';

/// Widget principal de la aplicacion Wallet Multicadena
/// Configura el tema (oscuro/claro), el enrutamiento y usa navigatorKey para FCM
class WalletApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const WalletApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Determinar el modo de tema segun preferencia del usuario
    // Por defecto usa modo oscuro, en el futuro se leera de SETTINGS.tema
    ThemeMode themeMode = ThemeMode.dark;
    if (auth.isAuthenticated && auth.user != null) {
      // TODO: Leer preferencia 'tema' desde la coleccion SETTINGS del usuario
    }

    return MaterialApp(
      navigatorKey: navigatorKey,    // Necesario para navegar desde notificaciones
      title: 'Wallet Multicadena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,     // Tema claro por defecto
      darkTheme: AppTheme.darkTheme,   // Tema oscuro configurado
      themeMode: themeMode,            // Alterna entre claro y oscuro segun preferencia
      home: const AuthGate(),          // Widget de entrada que decide la pantalla inicial
    );
  }
}

/// AuthGate: widget de guardian de autenticacion
/// Escucha el estado de autenticacion del AuthProvider y muestra:
/// - Pantalla de carga mientras se inicializa Firebase
/// - Pantalla de login si no hay sesion activa
/// - LockGate si el usuario esta autenticado (para verificar PIN/bloqueo)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ConnectivityBanner(
      child: switch (auth.status) {
        AuthStatus.uninitialized => const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthStatus.authenticated => const LockGate(),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}

/// LockGate: decide si mostrar la pantalla de bloqueo o el Home
/// Si hay PIN configurado y la app esta bloqueada, muestra LockScreen
class LockGate extends StatelessWidget {
  const LockGate({super.key});

  @override
  Widget build(BuildContext context) {
    final sec = context.watch<SecurityProvider>();

    if (sec.isLocked) {
      return const LockScreen();
    }
    return const HomeScreen();
  }
}
