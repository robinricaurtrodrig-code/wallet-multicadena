"""Middleware de autenticacion para la wallet multicadena.
Verifica tokens JWT de Firebase Auth usando el esquema HTTP Bearer.
Provee dependencias para proteger rutas que requieren autenticacion.
"""

from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.firebase import verify_id_token

security = HTTPBearer()


async def verify_firebase_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verifica un token JWT de Firebase Auth extrayendolo del header Authorization Bearer.
    Parametros:
        credentials: Credenciales HTTP Bearer con el token JWT.
    Retorna:
        dict con el payload decodificado del token (contiene uid, email, etc.).
    Lanza:
        HTTPException 401 si el token es invalido o expiro.
    """
    token = credentials.credentials

    try:
        decoded = await verify_id_token(token)
        uid = decoded.get("uid")
        if uid is None:
            raise HTTPException(status_code=401, detail="Token inválido: sin subject")
        return decoded
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Token inválido o expirado: {str(e)}")


async def get_current_user(payload: dict = Depends(verify_firebase_token)) -> dict:
    """Dependencia FastAPI que retorna el usuario autenticado actual.
    Extrae uid, email y name del token verificado para usar en los endpoints protegidos.
    Parametros:
        payload: Diccionario con los claims del token JWT verificado.
    Retorna:
        dict con uid, email y name del usuario autenticado.
    """
    return {
        "uid": payload.get("uid"),
        "email": payload.get("email", ""),
        "name": payload.get("name", ""),
    }
