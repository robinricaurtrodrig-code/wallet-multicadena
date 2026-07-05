from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.firebase import verify_id_token

security = HTTPBearer()


async def verify_firebase_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
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
    return {
        "uid": payload.get("uid"),
        "email": payload.get("email", ""),
        "name": payload.get("name", ""),
    }
