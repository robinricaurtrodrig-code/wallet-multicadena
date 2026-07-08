import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/firebase_messaging_service.dart';
import '../models/user.dart';
import '../core/storage/secure_storage.dart';

///
/// AuthProvider: Proveedor de estado para la autenticacion de usuarios.
/// Gestiona registro, inicio de sesion, cierre de sesion, carga de datos
/// de usuario desde Firestore, refresco periodico del token JWT de Firebase,
/// y mapeo de errores de Firebase Auth a mensajes legibles para el usuario.
///

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService apiService;
  Timer? _tokenRefreshTimer;

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Inicializa el provider suscribiendose a los cambios de autenticacion de Firebase
  AuthProvider({required this.apiService}) {
    _authService.userStream.listen(_onAuthChange);
  }

  /// Escucha cambios en el estado de autenticacion de Firebase
  /// Se dispara automaticamente al iniciar sesion, cerrar sesion o reabrir la app
  /// Si firebaseUser es null, el usuario cerro sesion o su sesion expiro
  void _onAuthChange(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      // Estado no autenticado: limpiar usuario y token de la API
      _status = AuthStatus.unauthenticated;
      _user = null;
      apiService.setToken(null);
      notifyListeners();
    } else {
      // Usuario ya autenticado (ej. al reabrir la app con sesion activa)
      _loadUserData(firebaseUser);
    }
  }

  /// Carga los datos del usuario desde Firestore y configura el token JWT
  Future<void> _loadUserData(fb_auth.User firebaseUser) async {
    try {
      // Obtener el token JWT de Firebase Auth
      final token = await firebaseUser.getIdToken();
      apiService.setToken(token);

      // Configurar el prefijo de usuario para SecureStorage (almacenamiento por usuario)
      SecureStorage.setUserId(firebaseUser.uid);

      // Leer datos del usuario desde Firestore
      final doc = await FirebaseFirestore.instance
          .collection('USERS')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        // Si el documento existe en Firestore, convertirlo al modelo de usuario
        _user = UserModel.fromJson(doc.data()!);
      } else {
        // Si no existe en Firestore, crear con datos minimos de Firebase Auth
        _user = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          username: firebaseUser.displayName ?? '',
          fechaRegistro: DateTime.now(),
          walletCreada: false,
        );
      }

      _status = AuthStatus.authenticated;
      // Iniciar refresco periodico del token JWT cada 45 minutos
      _startTokenRefresh(firebaseUser);
    } catch (e) {
      // Autenticado igual aunque falle Firestore, para no bloquear al usuario
      _status = AuthStatus.authenticated; // Autenticado igual aunque falle Firestore
    }
    notifyListeners();
  }

  /// Refresca el token JWT cada 45 minutos (los tokens de Firebase expiran a la hora)
  void _startTokenRefresh(fb_auth.User firebaseUser) {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 45), (_) async {
      try {
        final token = await firebaseUser.getIdToken(true);
        apiService.setToken(token);
      } catch (_) {}
    });
  }

  /// Registra un nuevo usuario con email, contrasena y nombre de usuario
  Future<void> register(String email, String password, String username) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final fcmToken = FirebaseMessagingService.currentToken ?? '';
      await _authService.register(email, password, username, fcmToken: fcmToken);

      // Obtener el usuario actual y cargar sus datos
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser);
      }

      // Notificar al backend para enviar correo de bienvenida
      try {
        await apiService.notifyRegister(_user?.email ?? email, _user?.username ?? username);
      } catch (_) {}
    } catch (e) {
      _error = _mapFirebaseError(e.toString());
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Inicia sesion con email y contrasena
  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final fcmToken = FirebaseMessagingService.currentToken ?? '';
      await _authService.login(email, password, fcmToken: fcmToken);

      // Obtener el usuario actual y cargar sus datos
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser);
      }

      // Notificar al backend para enviar correo de inicio de sesion
      try {
        await apiService.notifyLogin(_user?.email ?? email, _user?.username ?? '');
      } catch (_) {}
    } catch (e) {
      _error = _mapFirebaseError(e.toString());
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Cierra la sesion del usuario
  Future<void> logout() async {
    _tokenRefreshTimer?.cancel();
    await _authService.logout();
    _status = AuthStatus.unauthenticated;
    _user = null;
    apiService.setToken(null);
    SecureStorage.clearUserId();
    notifyListeners();
  }

  /// Obtiene el token JWT actual de Firebase Auth
  Future<String> getIdToken() async {
    return await _authService.getIdToken();
  }

  /// Limpia el mensaje de error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Mapea errores de Firebase Auth a mensajes amigables para el usuario
  String _mapFirebaseError(String error) {
    if (error.contains('weak-password')) return 'La contrasena debe tener al menos 6 caracteres';
    if (error.contains('email-already-in-use')) return 'Este correo ya esta registrado';
    if (error.contains('user-not-found')) return 'Usuario no encontrado';
    if (error.contains('wrong-password')) return 'Contrasena incorrecta';
    if (error.contains('invalid-email')) return 'Correo electronico invalido';
    if (error.contains('too-many-requests')) return 'Demasiados intentos. Intenta mas tarde';
    if (error.contains('operation-not-allowed')) return 'Inicio de sesion con Email/Password no habilitado. Activalo en Firebase Console > Authentication > Sign-in method';
    if (error.contains('network-request-failed')) return 'Error de red. Verifica tu conexion a internet';
    if (error.contains('invalid-credential')) return 'Credenciales invalidas. Verifica tu correo y contrasena';
    return 'Error de autenticacion: $error';
  }
}
