/// Archivo principal de entrada de la aplicacion Wallet Multicadena.
/// Inicializa Firebase, configura las notificaciones push (FCM)
/// y lanza la interfaz con los providers globales (autenticacion, wallet, seguridad, conectividad).
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/auth_provider.dart';
import 'controllers/wallet_provider.dart';
import 'controllers/security_provider.dart';
import 'controllers/connectivity_provider.dart';
import 'services/api_service.dart';
import 'services/firebase_messaging_service.dart';
import 'app.dart';

/// Clave global del navegador, necesaria para redirigir desde notificaciones push.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
/// Instancia global del servicio de API (inyectada en los providers).
final ApiService apiService = ApiService();

/// Punto de entrada de la aplicacion.
/// Inicializa Firebase, registra FCM en dispositivos moviles y monta el arbol de widgets con MultiProvider.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar Firebase con las opciones de la plataforma actual
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Inicializar FCM para notificaciones push (solo en mobile/native)
    if (!kIsWeb) {
      try {
        await FirebaseMessagingService.init(navigatorKey);
      } catch (_) {
        // FCM no disponible en algunas plataformas, continuar igual
      }
    }
  } catch (e) {
    // Si falla la inicializacion, mostrar pantalla de error
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error al iniciar la aplicacion: $e'),
          ),
        ),
      ),
    );
    return;
  }

  // Montar el arbol de widgets con los proveedores de estado global
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => WalletProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: WalletApp(navigatorKey: navigatorKey),
    ),
  );
}
