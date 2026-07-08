"""Servicio de Firebase para la wallet multicadena.
Inicializa y expone el SDK Admin de Firebase para autenticacion,
Firestore (base de datos) y FCM (notificaciones push).
"""

import firebase_admin
from firebase_admin import credentials, auth, firestore, messaging
from app.config import get_settings
from functools import lru_cache


@lru_cache
def get_firebase_app():
    """Inicializa Firebase Admin SDK con las credenciales del archivo .env"""
    settings = get_settings()
    if not firebase_admin._apps:
        # Construir el diccionario de credenciales de la cuenta de servicio
        cred_dict = {
            "type": "service_account",
            "project_id": settings.firebase_project_id,
            "private_key_id": settings.firebase_private_key_id,
            "private_key": settings.firebase_private_key.replace("\\n", "\n"),
            "client_email": settings.firebase_client_email,
            "client_id": settings.firebase_client_id,
            "auth_uri": settings.firebase_auth_uri,
            "token_uri": settings.firebase_token_uri,
            "auth_provider_x509_cert_url": settings.firebase_auth_provider_x509_cert_url,
            "client_x509_cert_url": settings.firebase_client_x509_cert_url,
            "universe_domain": settings.firebase_universe_domain,
        }
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
    return firebase_admin.get_app()


def get_firestore_client():
    """Retorna el cliente de Firestore para operaciones de base de datos"""
    get_firebase_app()
    return firestore.client()


async def verify_id_token(id_token: str) -> dict:
    """Verifica un ID token de Firebase Auth usando el Admin SDK"""
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded
    except Exception as e:
        raise ValueError(f"Token verification failed: {str(e)}")


async def get_user_data(uid: str) -> dict | None:
    """Obtiene los datos de un usuario desde la coleccion USERS en Firestore"""
    db = get_firestore_client()
    doc = db.collection("USERS").document(uid).get()
    return doc.to_dict() if doc.exists else None


async def create_user_settings(uid: str, data: dict):
    """Crea la configuracion inicial del usuario en Firestore"""
    db = get_firestore_client()
    db.collection("SETTINGS").document(uid).set(data)


async def get_user_settings(uid: str) -> dict | None:
    """Obtiene la configuracion del usuario desde Firestore"""
    db = get_firestore_client()
    doc = db.collection("SETTINGS").document(uid).get()
    return doc.to_dict() if doc.exists else None


async def send_push_notification(user_uid: str, title: str, body: str, data: dict = None):
    """Envia una notificacion push FCM al dispositivo del usuario"""
    get_firebase_app()
    db = get_firestore_client()

    # Obtener el FCM token del usuario desde la coleccion SESSION
    session_doc = db.collection("SESSION").document(user_uid).get()
    if not session_doc.exists:
        return

    session_data = session_doc.to_dict()
    fcm_token = session_data.get("fcmToken")
    if not fcm_token:
        return

    # Construir y enviar el mensaje FCM
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        token=fcm_token,
    )
    try:
        messaging.send(message)
    except Exception:
        pass  # Si falla el envio, ignoramos (el token podria haber expirado)
