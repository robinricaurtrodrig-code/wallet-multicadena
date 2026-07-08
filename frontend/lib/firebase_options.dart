/// Opciones de configuracion de Firebase para cada plataforma.
/// Proporciona las claves API, ID de aplicacion y demas parametros
/// necesarios para inicializar Firebase correctamente en web, Android, iOS, macOS, Windows y Linux.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Clase que expone las opciones de Firebase para la plataforma actual.
class DefaultFirebaseOptions {
  /// Retorna las opciones de Firebase correspondientes a la plataforma en ejecucion.
  /// Detecta automaticamente si es web, android, ios, macOS, windows o linux.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  /// Opciones de Firebase para la plataforma web.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  /// Opciones de Firebase para la plataforma Android.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:android:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  /// Opciones de Firebase para la plataforma iOS.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:ios:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
    iosBundleId: 'com.wallet.multicadena',
  );

  /// Opciones de Firebase para la plataforma macOS.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:ios:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
    iosBundleId: 'com.wallet.multicadena',
  );

  /// Opciones de Firebase para la plataforma Windows.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  /// Opciones de Firebase para la plataforma Linux.
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );
}
