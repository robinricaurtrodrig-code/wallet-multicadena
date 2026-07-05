import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configura los mocks de Firebase para pruebas.
/// Debe llamarse al inicio de main() en cada archivo de test.
void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}

/// Inicializa Firebase en setUpAll.
Future<void> initFirebase() => Firebase.initializeApp();
