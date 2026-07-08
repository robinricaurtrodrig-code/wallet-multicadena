from pydantic_settings import BaseSettings
from pydantic import field_validator, ValidationInfo
from functools import lru_cache


class Settings(BaseSettings):
    # Configuracion de Firebase Admin SDK
    firebase_project_id: str = ""
    firebase_private_key_id: str = ""
    firebase_private_key: str = ""
    firebase_client_email: str = ""
    firebase_client_id: str = ""
    firebase_auth_uri: str = "https://accounts.google.com/o/oauth2/auth"
    firebase_token_uri: str = "https://oauth2.googleapis.com/token"
    firebase_auth_provider_x509_cert_url: str = "https://www.googleapis.com/oauth2/v1/certs"
    firebase_client_x509_cert_url: str = ""
    firebase_universe_domain: str = "googleapis.com"

    # Endpoints RPC para cada blockchain (QuickNode / Helius / Alchemy)
    solana_rpc_url: str = "https://api.mainnet-beta.solana.com"
    solana_ws_url: str = "wss://api.mainnet-beta.solana.com"
    bitcoin_rpc_url: str = "https://mempool.space/api"
    bnb_rpc_url: str = "https://bsc-dataseed.binance.org"

    # Email del administrador para notificaciones de nuevos registros
    admin_email: str = ""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""

    # API de precios (CoinGecko)
    coingecko_api_url: str = "https://api.coingecko.com/api/v3"

    # Configuracion JWT para verificar tokens de Firebase Auth
    jwt_algorithm: str = "RS256"
    jwt_audience: str = ""
    jwt_issuer: str = ""

    @field_validator("firebase_project_id")
    @classmethod
    def validate_project_id(cls, v):
        if not v:
            raise ValueError("FIREBASE_PROJECT_ID es requerido")
        return v

    @field_validator("solana_rpc_url", "solana_ws_url", "bitcoin_rpc_url", "bnb_rpc_url")
    @classmethod
    def validate_rpc_url(cls, v: str, info: ValidationInfo):
        defaults = {
            "solana_rpc_url": "https://api.mainnet-beta.solana.com",
            "solana_ws_url": "wss://api.mainnet-beta.solana.com",
            "bitcoin_rpc_url": "https://mempool.space/api",
            "bnb_rpc_url": "https://bsc-dataseed.binance.org",
        }
        if not v or not v.startswith(("http://", "https://", "wss://")):
            return defaults[info.field_name]
        if info.field_name in ("bnb_rpc_url",) and "mempool" in v:
            return defaults[info.field_name]
        return v

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
