/// Servicio de Firebase Cloud Messaging (FCM) para notificaciones push.
/// Maneja la solicitud de permisos, obtencion y refresco del token FCM,
/// y la recepcion de notificaciones tanto en foreground (SnackBar) como en background.
/// No disponible en plataforma web.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Clase que maneja las notificaciones push de Firebase.
class FirebaseMessagingService {
  static final bool _isWeb = kIsWeb;

  static FirebaseMessaging? _messaging;
  static String? _currentToken;
  static String? get currentToken => _currentToken;

  static GlobalKey<NavigatorState>? navigatorKey;

  /// Inicializa FCM con un GlobalKey de navegacion para redirigir al tocar notificaciones.
  /// Solicita permisos, obtiene el token, escucha cambios y maneja mensajes.
  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    if (_isWeb) return;
    navigatorKey = navKey;
    _messaging = FirebaseMessaging.instance;
    await _requestPermission();
    await _getToken();
    _listenTokenRefresh();
    _handleForegroundMessages();
    _handleBackgroundMessages();
  }

  /// Solicita permiso al usuario para mostrar notificaciones (alert, badge, sound).
  static Future<void> _requestPermission() async {
    final status = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (status.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Permiso de notificaciones denegado');
    }
  }

  /// Obtiene el token FCM actual del dispositivo.
  static Future<void> _getToken() async {
    _currentToken = await _messaging!.getToken();
    debugPrint('FCM token: $_currentToken');
  }

  /// Escucha cambios en el token FCM (se refresca periodicamente).
  /// Cuando el token cambia, se debe actualizar en el backend (AuthService).
  static void _listenTokenRefresh() {
    _messaging!.onTokenRefresh.listen((token) {
      _currentToken = token;
      debugPrint('FCM token refrescado: $token');
    });
  }

  /// Muestra un SnackBar cuando la app recibe una notificacion en foreground.
  /// Si la notificacion incluye un tx_hash, muestra un boton "Ver" para abrir detalles.
  static void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null || navigatorKey?.currentContext == null) return;

    final context = navigatorKey!.currentContext!;
    final txHash = message.data['tx_hash'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.title ?? 'Notificacion',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(notification.body ?? ''),
          ],
        ),
        action: txHash.isNotEmpty
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => _openTransaction(txHash),
              )
            : null,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Abre el explorador de transacciones al tocar la notificacion (funcionalidad futura).
  static void _openTransaction(String txHash) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    debugPrint('Abrir detalle de tx: $txHash');
  }

  /// Maneja mensajes en foreground: muestra SnackBar con la notificacion.
  static void _handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen(_showInAppNotification);
  }

  /// Maneja mensajes en background: delega al handler top-level.
  static void _handleBackgroundMessages() {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }
}

/// Handler obligatorio top-level para mensajes en background.
/// Debe ser una funcion global (no metodo de clase) segun requisito de Firebase.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint('Notificacion en background: ${message.notification?.title}');
}
