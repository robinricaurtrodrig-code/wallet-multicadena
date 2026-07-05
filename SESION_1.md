# Wallet Multicadena - Sesiones

## Sesión 1 - 2 Julio 2026

### Completado
- ✅ **FASE 3 COMPLETADA**: Gestión de activos multi-red
  - Iconos SVG para SOL, BTC, BNB en assets/icons/
  - wallet_provider.dart reescrito: fetchAllBalances usa 3 llamadas paralelas (una por red)
  - Backend endpoint cambiado a /blockchain/balance/{network}/{address}
  - api_service.dart: nuevo getBalance(network, address)
  - home_screen.dart: lista de activos con precios, colores por red, pull-to-refresh
  - asset_detail_screen.dart: detalle de activo con balance, info, historial de transacciones
- ✅ **FASE 4 COMPLETADA**: Enviar/Recibir transacciones
  - Backend: prepare-send, send endpoints para Solana, Bitcoin, BNB
  - Frontend: send_screen.dart, receive_screen.dart, transaction_builder.dart
  - Firma local no-custodial para las 3 redes
  - web3dart API corregida (signTransactionRaw)
- ✅ **FASE 5 COMPLETADA**: Historial y notificaciones push (FCM)
  - Historial de transacciones (backend + frontend)
  - FirebaseMessagingService: permisos, token, foreground/background messages
  - auth_service.dart: FCM token en register/login
  - Backend: send_push_notification al enviar transacción
- ✅ **MOD-06 COMPLETADO**: Seguridad avanzada
  - LockScreen con PIN + biometría
  - SecurityProvider: auto-logout por inactividad, anti-phishing
  - BiometricService con local_auth
  - SecuritySettingsScreen: cambiar PIN, biometría, auto-logout, anti-phishing
  - LockGate en app.dart entre AuthGate y HomeScreen
- ✅ **MOD-08 COMPLETADO**: Web3/DApps
  - SignMessageScreen: firma mensajes con claves de Solana, Bitcoin, BNB
  - DAppBrowserScreen: lista de DApps populares + url_launcher
  - DAppService: firma Ed25519, personal_sign, ECDSA
  - WalletProvider: getPrivateKey/getBitcoinKey públicos
- ✅ Firebase: Android + iOS configurados
- ✅ Compilación exitosa en Chrome
- ✅ Errores de compilación corregidos (Transaction, CardTheme, KeyData, ConstrainedBox, Inter font)

## Sesión 2 - 4 Julio 2026

### Completado
- ✅ **FASE 6 COMPLETADA**: Testing, auditoría y despliegue
  - ✅ **30 tests unitarios** Flutter (modelos, transaction_builder, dapp_service)
  - ✅ **28 tests integración** Backend (health, prices, blockchain, auth)
  - ✅ **25 tests crypto** (bip39, bip44, aes_encryption: mnemonic, derivación BIP44, base58, hashes, direcciones BTC/BNB, PBKDF2+AES-GCM)
  - ✅ **23 tests widget** Flutter (LoginScreen: 7, HomeScreen: 9, AuthGate: 7)
  - ✅ **83 tests frontend** (55 unit + 28 widget) + **28 backend** = **111 tests proyecto**
  - ✅ **Stress testing API** (locust: 30 usuarios/30s)
  - ✅ **Auditoría de seguridad** (4 hallazgos corregidos: SecureRandom, await, CORS, errores)
- ✅ **5 CRITICAL FIXES (arreglados)**:
  - ✅ **deriveSolanaAddress()**: `bip44.dart` ya no retorna placeholder; usa `pinenacl` Ed25519 para derivar clave pública real en base58
  - ✅ **Pantalla de Historial**: `history_screen.dart` creada con filtro por red, pull-to-refresh, estados loading/error/vacío; tab #3 en home_screen.dart navega a HistoryScreen
  - ✅ **JWT token refresh**: Timer periódico cada 45 min en `auth_provider.dart` que refresca el token antes de expirar; se cancela en logout
  - ✅ **Indicador de conectividad**: `ConnectivityProvider` monitorea red vía `connectivity_plus`; `ConnectivityBanner` muestra barra naranja "Sin conexión a internet"
  - ✅ **Bug transaction_builder.dart:79**: BNB RLP no aceptaba `data: null`; corregido a `data: Uint8List(0)`
- ✅ **Web build**: `flutter build web` exitoso (JS estándar). Advertencias WASM solo de paquetes terceros, no de código propio. No se usa `dart:html`.
- ✅ **AUDITORIA.md**: documento de hallazgos y correcciones
- ✅ **SESION_1.md**: actualizado con todo el progreso

### Correcciones durante la sesión
- `test/unit/crypto_test.dart`: agregado `import 'dart:convert'` para `base64`
- `lib/providers/connectivity_provider.dart`: API de `connectivity_plus` v5 usa `ConnectivityResult` (no `List<ConnectivityResult>`). Agregado `try/catch` en `_init()` para entorno de test
- `test/widgets/auth_gate_test.dart`: agregado `ConnectivityProvider` a los providers del test

### Arquitectura final
- **Backend**: Python 3.14.6, FastAPI 0.111.0, uvicorn, Firebase Admin SDK 6.5.0, web3 6.20.0, slowapi
- **Frontend**: Flutter SDK 3.44.4, web3dart 2.7.3, bip39, bip32, pointycastle, cryptography, flutter_secure_storage, local_auth, pinenacl, connectivity_plus
- **Firma**: no-custodial, claves privadas nunca salen del dispositivo
- **Rate limiting**: 5 req/min auth, 30 req/min prices/prepare-send
- **CORS**: dominios específicos (Firebase Hosting, localhost)
- **JWT refresh**: cada 45 min automático

## Sesión 3 - 5 Julio 2026

### Completado
- ✅ **Bugfix backend**: Bitcoin history - corrección de iteración sobre string (carácter por carácter) + cálculo correcto de amount/type
- ✅ **Bugfix backend**: BNB history - reemplazo de eth_getLogs (incorrecto) por JSON-RPC batch scanning (5000 bloques)
- ✅ **Bugfix frontend**: PointyCastle RegistryError en web por minificación - reemplazo de FortunaRandom por Random.secure() en aes_encryption.dart y secure_storage.dart
- ✅ **Bugfix frontend**: `importWallet` ahora muestra el error exacto en vez de mensaje genérico
- ✅ **Bugfix frontend**: `import_wallet_screen.dart` - limpieza mejorada de seed phrase (reemplaza saltos de línea y separadores)
- ✅ **Bugfix frontend**: `bip44.dart` - reemplazo de `pinenacl` por `cryptography` para Solana Ed25519 (compatible con web)
- ✅ **Bugfix frontend**: `auth_provider.dart` - mensajes de error Firebase Auth mejorados (operation-not-allowed, network-request-failed, invalid-credential) en español
- ✅ **Firestore Database**: Creada en Firebase Console (modo prueba) para que funcione el registro
- ✅ **Firebase Auth**: Email/Password habilitado
- ✅ **Web build**: Release sin minificación (profile mode) para compatibilidad con librerías criptográficas
- ✅ **Git init**: Repositorio inicializado con todo el proyecto

### Correcciones
- `lib/core/crypto/aes_encryption.dart`: Reemplazo `FortunaRandom()` por `Random.secure()` para evitar RegistryFactoryException en web
- `lib/core/storage/secure_storage.dart`: Reemplazo `FortunaRandom()` por `Random.secure()`, agregado `import 'dart:math'`
- `lib/providers/wallet_provider.dart`: Manejo de errores detallado por paso en `importWallet()`
- `lib/screens/wallet/import_wallet_screen.dart`: Mejora en limpieza de seed phrase (regex para espacios múltiples, saltos de línea, comas)
- `lib/providers/auth_provider.dart`: Errores Firebase Auth mapeados a español
- `lib/core/crypto/bip44.dart`: Reemplazo `pinenacl` → `cryptography` para `deriveSolanaAddress()` (web compatible)
- `backend/app/services/blockchain/bitcoin.py`: Fix iteración string + lógica received/sent
- `backend/app/services/blockchain/bnb.py`: Fix eth_getLogs → JSON-RPC batch scan 5000 bloques
- `.gitignore`: Agregado `firebase-credentials.json`

### Para la próxima sesión
- ⬜ Desplegar frontend en Firebase Hosting para el equipo
- ⬜ Desplegar backend en Render/Railway para funcionalidad completa
- ⬜ Corregir 22 usos de `withOpacity()` deprecados (serán error en futuras versiones de Flutter)
- ⬜ Agregar `pinenacl` como dependencia explícita o eliminarlo (ya no se usa, se reemplazó por `cryptography`)
- ⬜ Probar Enviar/Recibir transacciones reales
- ⬜ Agregar guards de plataforma para `mobile_scanner` y `local_auth` en web

### Comandos útiles
```powershell
cd I:\ROBIN 6TOSEMESTRE\wallet_app\frontend
flutter run -d chrome
flutter build web --profile   # Build sin minificación
flutter build web --release   # Build con minificación
flutter test
flutter test test/unit/crypto_test.dart  # 30 tests crypto (~2.5 min por PBKDF2)
```
