import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

///
/// ConnectivityProvider: Proveedor de estado para monitorear la conexion a internet.
/// Escucha cambios en la conectividad del dispositivo usando connectivity_plus
/// y notifica a los widgets cuando el estado cambia (online/offline).
///

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Inicializa el provider: obtiene el estado actual de conectividad
  /// y se suscribe a cambios futuros en la conexion de red
  ConnectivityProvider() {
    _init();
  }

  /// Obtiene el estado inicial de conectividad y se suscribe a cambios
  /// Verifica si hay conexion a internet al arrancar la aplicacion
  Future<void> _init() async {
    try {
      // Consultar estado actual de conectividad
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      // Escuchar cambios en tiempo real (WiFi, datos moviles, etc.)
      _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
    } catch (_) {}
  }

  /// Actualiza el estado online/offline y notifica a los widgets
  /// Solo dispara notifyListeners cuando el estado realmente cambio
  void _updateStatus(List<ConnectivityResult> result) {
    // Online si el resultado NO contiene ConnectivityResult.none
    final online = !result.contains(ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Cancelar la suscripcion para evitar fugas de memoria
    _subscription?.cancel();
    super.dispose();
  }
}
