from slowapi import Limiter
from slowapi.util import get_remote_address
from datetime import datetime, timedelta, timezone
import hashlib

# Limitador de tasa de peticiones por IP (rate limiting)
# Protege contra ataques de fuerza bruta y abuso de endpoints
limiter = Limiter(key_func=get_remote_address)


def hash_device_id(device_id: str) -> str:
    """Genera un hash SHA-256 del identificador del dispositivo
    Se usa para tracking de sesiones sin almacenar el ID original
    """
    return hashlib.sha256(device_id.encode()).hexdigest()


def check_session_timeout(last_access: datetime, timeout_minutes: int = 30) -> bool:
    """Verifica si una sesion ha excedido el tiempo maximo de inactividad
    Retorna True si la sesion expiro, False si aun es valida
    """
    return datetime.now(timezone.utc) - last_access > timedelta(minutes=timeout_minutes)


def validate_phishing_url(url: str) -> bool:
    """Valida que una URL no contenga palabras clave de phishing conocidas
    Retorna True si la URL es segura, False si es sospechosa
    """
    suspicious_domains = [
        "airdrop", "claim", "free", "giveaway",
        "bonus", "reward", "promo", "wallet-connect",
    ]
    url_lower = url.lower()
    for domain in suspicious_domains:
        if domain in url_lower:
            return False
    return True
