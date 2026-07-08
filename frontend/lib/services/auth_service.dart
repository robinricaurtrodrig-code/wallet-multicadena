/// Servicio de autenticacion que integra Firebase Auth con Firestore.
/// Maneja registro, inicio de sesion, cierre de sesion, actualizacion de FCM token,
/// obtencion de JWT y restablecimiento de contrasena.
/// Cada usuario tiene documentos en tres colecciones: USERS (perfil), SETTINGS (preferencias)
/// y SESSION (datos de sesion con FCM).
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase que encapsula la logica de autenticacion con Firebase.
class AuthService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream de cambios en el estado de autenticacion.
  Stream<fb_auth.User?> get userStream => _auth.authStateChanges();
  /// Usuario actualmente autenticado (puede ser null).
  fb_auth.User? get currentUser => _auth.currentUser;

  /// Registra un nuevo usuario en Firebase Auth y crea su perfil en Firestore.
  /// Crea documentos en USERS, SETTINGS y SESSION con valores iniciales.
  Future<void> register(String email, String password, String username,
      {String fcmToken = ''}) async {
    // Crear usuario en Firebase Authentication
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = result.user!.uid;

    // Actualizar el nombre de usuario en Firebase Auth
    await result.user!.updateDisplayName(username);

    // Crear documento en la coleccion USERS de Firestore
    await _db.collection('USERS').doc(uid).set({
      'uid': uid,
      'email': email,
      'username': username,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'walletCreada': false,
    });

    // Crear configuracion por defecto en la coleccion SETTINGS
    await _db.collection('SETTINGS').doc(uid).set({
      'idioma': 'es',
      'tema': 'dark',
      'monedaPreferida': 'USD',
      'notificacionesActivas': true,
      'tokensFavoritos': [],
    });

    // Crear sesion inicial en la coleccion SESSION con FCM token
    await _db.collection('SESSION').doc(uid).set({
      'deviceId': '',
      'ultimoAcceso': FieldValue.serverTimestamp(),
      'tokenSesion': '',
      'fcmToken': fcmToken,
    });
  }

  /// Inicia sesion con email y contrasena, actualiza FCM token en SESSION.
  Future<void> login(String email, String password,
      {String fcmToken = ''}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    // Actualizar FCM token en la sesion existente
    final user = _auth.currentUser;
    if (user != null && fcmToken.isNotEmpty) {
      await _db.collection('SESSION').doc(user.uid).update({
        'fcmToken': fcmToken,
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Actualiza el token FCM en la sesion del usuario autenticado.
  /// Se usa cuando el token FCM se refresca en FirebaseMessagingService.
  Future<void> updateFcmToken(String fcmToken) async {
    final user = _auth.currentUser;
    if (user == null || fcmToken.isEmpty) return;
    await _db.collection('SESSION').doc(user.uid).update({
      'fcmToken': fcmToken,
      'ultimoAcceso': FieldValue.serverTimestamp(),
    });
  }

  /// Cierra la sesion del usuario en Firebase Auth.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Obtiene el token JWT actual de Firebase Auth.
  /// Se usa para autenticar peticiones al backend en ApiService.
  Future<String> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final token = await user.getIdToken();
    return token ?? '';
  }

  /// Envia correo de restablecimiento de contrasena al email especificado.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
