from fastapi import APIRouter, HTTPException, Depends
from app.models.schemas import (
    AuthRegisterRequest,
    AuthLoginRequestV2,
    AuthResponse,
    AuthLoginResponse,
    SettingsUpdate,
)
from app.middleware.auth import get_current_user
from app.services.firebase import (
    get_firebase_app,
    get_firestore_client,
    get_user_data,
    get_user_settings,
    verify_id_token,
)
from app.utils.security import limiter, hash_device_id
from app.utils.notifications import send_email
from fastapi import Request
from google.cloud import firestore
import firebase_admin.auth

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/register", response_model=AuthResponse)
@limiter.limit("5/minute")
async def register(request: Request, body: AuthRegisterRequest):
    get_firebase_app()
    db = get_firestore_client()

    # Verificar que el email no exista ya en Firestore
    users_ref = db.collection("USERS")
    existing = users_ref.where("email", "==", body.email).limit(1).stream()
    if any(existing):
        raise HTTPException(status_code=409, detail="El correo ya está registrado")

    # Crear usuario en Firebase Authentication (servidor)
    try:
        firebase_admin.auth.create_user(
            email=body.email,
            password=body.password,
            display_name=body.username,
        )
    except firebase_admin.auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=409, detail="El correo ya está registrado en Firebase Auth")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al crear usuario en Firebase: {str(e)}")

    # Obtener el UID asignado por Firebase Auth
    firebase_user = firebase_admin.auth.get_user_by_email(body.email)
    uid = firebase_user.uid

    # Guardar datos del usuario en Firestore (coleccion USERS)
    user_data = {
        "uid": uid,
        "email": body.email,
        "username": body.username,
        "fechaRegistro": firestore.SERVER_TIMESTAMP,
        "walletCreada": False,
    }
    db.collection("USERS").document(uid).set(user_data)

    # Guardar configuracion por defecto en Firestore (coleccion SETTINGS)
    settings_data = {
        "idioma": "es",
        "tema": "dark",
        "monedaPreferida": "USD",
        "notificacionesActivas": True,
        "tokensFavoritos": [],
    }
    db.collection("SETTINGS").document(uid).set(settings_data)

    # Enviar correo de bienvenida al usuario
    send_email(
        to_email=body.email,
        subject="Bienvenido a Wallet Multicadena",
        body=f"Hola {body.username},\n\nTu cuenta ha sido creada exitosamente en Wallet Multicadena.\n\nYa puedes iniciar sesion y crear tu wallet para enviar y recibir SOL, BTC y BNB.\n\nGracias por confiar en nosotros.",
    )

    # Generar token JWT personalizado de Firebase
    token = firebase_admin.auth.create_custom_token(uid)

    return AuthResponse(
        uid=uid,
        email=body.email,
        username=body.username,
        token=token.decode("utf-8") if isinstance(token, bytes) else token,
        wallet_created=False,
    )


@router.post("/login", response_model=AuthLoginResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: AuthLoginRequestV2):
    get_firebase_app()

    # Verificar el ID token enviado desde el cliente (Firebase Auth SDK)
    decoded_token = await verify_id_token(body.id_token)
    uid = decoded_token.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Token invalido: sin UID")

    # Obtener datos del usuario desde Firestore
    db = get_firestore_client()
    user_doc = db.collection("USERS").document(uid).get()
    user_data = user_doc.to_dict() if user_doc.exists else {}

    # Enviar alerta de inicio de sesion al usuario
    send_email(
        to_email=user_data.get("email", ""),
        subject="Inicio de sesion en Wallet Multicadena",
        body=f"Hola {user_data.get('username', 'Usuario')},\n\nSe ha iniciado sesion en tu cuenta de Wallet Multicadena.\n\nSi fuiste tu, ignora este mensaje.\nSi NO fuiste tu, cambia tu contrasena inmediatamente.",
    )

    # Registrar la sesion en Firestore (coleccion SESSION)
    session_data = {
        "deviceId": hash_device_id(body.device_id) if body.device_id else "",
        "ultimoAcceso": firestore.SERVER_TIMESTAMP,
        "tokenSesion": body.id_token,
        "fcmToken": body.fcm_token,
    }
    db.collection("SESSION").document(uid).set(session_data, merge=True)

    return AuthLoginResponse(
        uid=uid,
        email=user_data.get("email", ""),
        username=user_data.get("username", ""),
        token=body.id_token,
        wallet_created=user_data.get("walletCreada", False),
    )


@router.post("/logout")
async def logout(user=Depends(get_current_user)):
    uid = user["uid"]
    db = get_firestore_client()
    db.collection("SESSION").document(uid).delete()
    return {"status": "ok"}


@router.get("/profile")
async def get_profile(user=Depends(get_current_user)):
    uid = user["uid"]
    user_data = await get_user_data(uid)
    if not user_data:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return user_data


@router.put("/settings")
async def update_settings(body: SettingsUpdate, user=Depends(get_current_user)):
    uid = user["uid"]
    db = get_firestore_client()
    update_data = body.model_dump(exclude_none=True)
    if update_data:
        db.collection("SETTINGS").document(uid).set(update_data, merge=True)
    return {"status": "ok"}


@router.get("/settings")
async def get_settings_endpoint(user=Depends(get_current_user)):
    uid = user["uid"]
    settings = await get_user_settings(uid)
    if not settings:
        return {}
    return settings
