# Auditoria de Seguridad - Wallet Multicadena

## Hallazgos y Correcciones

### CRITICO: Seed aleatorio debil (CORREGIDO)
- **Archivo**: `frontend/lib/core/storage/secure_storage.dart:121-130`
- **Problema**: `_generateSalt()` usaba `DateTime.microsecondsSinceEpoch` como unica fuente de entropia para el salt PBKDF2, haciendolo predecible.
- **Correccion**: Reemplazado por `SecureRandom()` de PointyCastle.

### ALTO: Bug en auto-logout (CORREGIDO)
- **Archivo**: `frontend/lib/providers/security_provider.dart:47`
- **Problema**: `SecureStorage.hasPin() as bool` es un casteo incorrecto de `Future<dynamic>`.
- **Correccion**: Agregado `await` y `async` al callback del Timer.

### MEDIO: CORS permisivo (CORREGIDO)
- **Archivo**: `backend/app/main.py:34`
- **Problema**: `allow_origins=["*"]` permitia cualquier origen en produccion.
- **Correccion**: Restringido a dominios conocidos (Firebase Hosting, localhost).

### MEDIO: Fuga de informacion en errores (CORREGIDO)
- **Archivo**: `backend/app/routers/transactions.py:143`
- **Problema**: `str(e)` en la respuesta HTTP exponia detalles internos del error.
- **Correccion**: Mensaje generico sin detalles tecnicos.

### INFORMATIVO: send_push_notification sin await (CORREGIDO)
- **Archivo**: `backend/app/routers/transactions.py:121`
- **Problema**: Funcion async llamada sin `await`.
- **Correccion**: Agregado `await`.

### INFORMATIVO: Rate limiting activo
- **Archivo**: `backend/app/utils/security.py`
- **Estado**: OK - rate limiting configurado en todos los endpoints (5-30 req/min).

### INFORMATIVO: Firebase credentials protegidas
- **Backend**: `.env` y `firebase-credentials.json` en `.gitignore`.
- **Frontend**: `google-services.json` y `GoogleService-Info.plist` en `.gitignore`.

### INFORMATIVO: Almacenamiento seguro
- **Frontend**: `flutter_secure_storage` para PIN (PBKDF2 + salt) y frases semilla.
- **Frontend**: Biometria (`local_auth`) con `biometricOnly: true` para evitar fallback a PIN del sistema.

### INFORMATIVO: Web support
- **Riesgo**: En entorno web, las claves privadas en memoria son vulnerables a XSS.
- **Recomendacion**: Para production web, implementar Content Security Policy (CSP) y considerar una extension de navegador.

## Resumen
- **Criticos**: 1 (corregido)
- **Altos**: 1 (corregido)
- **Medios**: 2 (corregidos)
- **Informativos**: 5 (documentados)
