import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:android:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:ios:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
    iosBundleId: 'com.wallet.multicadena',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAGqXpdzexuLUrSAn-f14RMrNyKAS2o9gs',
    appId: '1:1009413519890:ios:6bf466c7ddb52f079076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
    iosBundleId: 'com.wallet.multicadena',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAFKcukb6CKFpRJCRd0NdfDuiVFvUO8V1I',
    appId: '1:1009413519890:web:ae0cb2dba33824599076cb',
    messagingSenderId: '1009413519890',
    projectId: 'wallet-multicadena',
    authDomain: 'wallet-multicadena.firebaseapp.com',
    storageBucket: 'wallet-multicadena.firebasestorage.app',
  );
}
