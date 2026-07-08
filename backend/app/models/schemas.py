"""Esquemas Pydantic para la wallet multicadena.
Define los modelos de datos para autenticacion, balances, transacciones,
precios y configuracion de usuario con validacion de tipos y formatos.
"""

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


class Network(str, Enum):
    """Redes blockchain soportadas por la wallet multicadena"""
    solana = "solana"
    bitcoin = "bitcoin"
    bnb = "bnb"


class AuthRegisterRequest(BaseModel):
    """Schema para la solicitud de registro de usuario
    Valida formato de email, longitud minima de contrasena y nombre de usuario
    """
    email: str = Field(..., pattern=r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
    password: str = Field(..., min_length=6)
    username: str = Field(..., min_length=2, max_length=50)


class AuthLoginRequest(BaseModel):
    """Schema para login con email y contrasena (deprecado, usar AuthLoginRequestV2)"""
    email: str
    password: str


class AuthLoginRequestV2(BaseModel):
    """Schema para login usando ID token de Firebase Authentication
    El cliente envia el token JWT obtenido del SDK de Firebase Auth
    """
    id_token: str
    device_id: str = ""
    fcm_token: str = ""


class AuthResponse(BaseModel):
    """Respuesta del registro de usuario con token JWT personalizado"""
    uid: str
    email: str
    username: str
    token: str
    wallet_created: bool = False


class AuthLoginResponse(BaseModel):
    """Respuesta del inicio de sesion con el ID token de Firebase"""
    uid: str
    email: str
    username: str
    token: str
    wallet_created: bool = False


class BalanceResponse(BaseModel):
    """Balance de una criptomoneda en una red especifica con conversion a USD"""
    network: Network
    symbol: str
    address: str = ""
    balance: float
    balance_usd: float
    usd_price: float


class BalancesResponse(BaseModel):
    """Lista de balances de todas las redes con el total en USD"""
    balances: list[BalanceResponse]
    total_usd: float


class TransactionRequest(BaseModel):
    """Solicitud para retransmitir una transaccion firmada a la blockchain"""
    network: Network
    to_address: str
    amount: float
    signed_transaction: str


class TransactionResponse(BaseModel):
    """Respuesta con el resultado de enviar una transaccion a la red"""
    network: Network
    tx_hash: str
    status: str
    amount: float
    fee: float
    explorer_url: str


class PrepareSendRequest(BaseModel):
    """Solicitud para preparar el envio de una transaccion
    El frontend envia la red, direccion origen, destino y monto
    El backend responde con los datos necesarios para construir y firmar la transaccion
    (blockhash para Solana, UTXOs para Bitcoin, nonce/gas para BNB)
    """
    network: Network
    from_address: str
    to_address: str
    amount: float


class PrepareSendResponse(BaseModel):
    """Respuesta con los datos necesarios para que el frontend firme la transaccion
    preparation_data contiene informacion especifica de cada red:
    - Solana: recent_blockhash
    - Bitcoin: utxos, to_amount_sats, change_address, change_sats
    - BNB: nonce, gas_price_wei, chain_id, gas_limit
    fee_estimate es la comision estimada en la moneda nativa (SOL, BTC, BNB)
    """
    network: Network
    fee_estimate: float
    preparation_data: dict


class TransactionHistoryItem(BaseModel):
    """Elemento del historial de transacciones con todos los detalles"""
    tx_hash: str
    network: Network
    type: str
    amount: float
    fee: float
    status: str
    timestamp: str
    explorer_url: str
    from_address: str = ""
    to_address: str = ""
    block_number: int = 0
    slot: int = 0


class PriceResponse(BaseModel):
    """Precios actualizados de SOL, BTC y BNB en USD desde CoinGecko"""
    solana: float
    bitcoin: float
    bnb: float
    last_updated: str


class SettingsUpdate(BaseModel):
    """Schema para actualizar la configuracion del usuario en Firestore
    Todos los campos son opcionales, solo se actualizan los que se envian
    """
    idioma: Optional[str] = Field(None, pattern=r"^(es|en|pt)$")
    tema: Optional[str] = Field(None, pattern=r"^(dark|light)$")
    monedaPreferida: Optional[str] = Field(None, pattern=r"^(USD|EUR)$")
    notificacionesActivas: Optional[bool] = None
    tokensFavoritos: Optional[list[str]] = None


class ErrorResponse(BaseModel):
    """Schema generico para respuestas de error"""
    detail: str
    code: str
