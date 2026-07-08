from fastapi import APIRouter, HTTPException, Depends
from app.models.schemas import (
    BalancesResponse,
    BalanceResponse,
    TransactionRequest,
    TransactionResponse,
    TransactionHistoryItem,
    Network,
    PrepareSendRequest,
    PrepareSendResponse,
)
from app.middleware.auth import get_current_user
from app.services.blockchain.solana import SolanaService
from app.services.blockchain.bitcoin import BitcoinService
from app.services.blockchain.bnb import BNBService
from app.services.firebase import send_push_notification
from app.utils.security import limiter
from fastapi import Request
import httpx
from cachetools import TTLCache
from app.config import get_settings
import datetime

router = APIRouter(prefix="/blockchain", tags=["Blockchain"])
price_cache = TTLCache(maxsize=1, ttl=60)

EXPLORER_URLS = {
    Network.solana: "https://solscan.io/tx/",
    Network.bitcoin: "https://mempool.space/tx/",
    Network.bnb: "https://bscscan.com/tx/",
}


def get_service(network: Network):
    services = {
        Network.solana: SolanaService(),
        Network.bitcoin: BitcoinService(),
        Network.bnb: BNBService(),
    }
    return services.get(network)


async def get_usd_prices() -> dict:
    """Obtiene los precios actuales de SOL, BTC y BNB desde CoinGecko con cache de 60s"""
    if "prices" in price_cache:
        return price_cache["prices"]
    settings = get_settings()
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.coingecko_api_url}/simple/price",
                params={"ids": "solana,bitcoin,binancecoin", "vs_currencies": "usd"},
            )
            response.raise_for_status()
            data = response.json()
            prices = {
                "solana": data.get("solana", {}).get("usd", 0),
                "bitcoin": data.get("bitcoin", {}).get("usd", 0),
                "bnb": data.get("binancecoin", {}).get("usd", 0),
            }
            price_cache["prices"] = prices
            return prices
    except Exception:
        # Si falla CoinGecko, devolver precios cacheados o cero
        return price_cache.get("prices", {"solana": 0, "bitcoin": 0, "bnb": 0})


@router.get("/balance/{network}/{address}", response_model=BalanceResponse)
@limiter.limit("20/minute")
async def get_balance(
    request: Request,
    network: Network,
    address: str,
    user=Depends(get_current_user),
):
    """Obtiene el balance de una red especifica para una direccion, con conversion a USD"""
    prices = await get_usd_prices()
    symbol = {"solana": "SOL", "bitcoin": "BTC", "bnb": "BNB"}[network.value]

    try:
        service = get_service(network)
        balance = await service.get_balance(address)
        usd_price = prices.get(network.value, 0)
        balance_usd = balance * usd_price
        return BalanceResponse(
            network=network,
            symbol=symbol,
            address=address,
            balance=round(balance, 8),
            balance_usd=round(balance_usd, 2),
            usd_price=round(usd_price, 2),
        )
    except Exception as e:
        return BalanceResponse(
            network=network,
            symbol=symbol,
            address=address,
            balance=0,
            balance_usd=0,
            usd_price=0,
        )


@router.post("/send", response_model=TransactionResponse)
@limiter.limit("5/minute")
async def send_transaction(
    request: Request,
    body: TransactionRequest,
    user=Depends(get_current_user),
):
    """Retransmite una transaccion ya firmada a la red blockchain correspondiente"""
    service = get_service(body.network)
    if not service:
        raise HTTPException(status_code=400, detail="Red no soportada")

    try:
        tx_hash = await service.send_transaction(body.signed_transaction)

        # Enviar notificacion push al usuario que realizo la transaccion
        try:
            await send_push_notification(
                user["uid"],
                title="Transaccion enviada",
                body=f"{body.amount} {body.network.value.upper()} enviado a {body.to_address[:8]}...",
                data={
                    "tx_hash": tx_hash,
                    "network": body.network.value,
                    "type": "sent",
                },
            )
        except Exception:
            pass  # La notificacion no debe bloquear la respuesta

        return TransactionResponse(
            network=body.network,
            tx_hash=tx_hash,
            status="pendiente",
            amount=body.amount,
            fee=0,  # La comision real se obtiene del explorador una vez confirmada
            explorer_url=f"{EXPLORER_URLS[body.network]}{tx_hash}",
        )
    except Exception:
        raise HTTPException(status_code=500, detail="Error al enviar la transaccion. Intente nuevamente.")


@router.post("/prepare-send", response_model=PrepareSendResponse)
@limiter.limit("10/minute")
async def prepare_send(
    request: Request,
    body: PrepareSendRequest,
    user=Depends(get_current_user),
):
    """Prepara los datos necesarios para que el frontend construya y firme una transaccion
    Retorna informacion especifica de cada red (blockhash, UTXOs, nonce, etc.)
    """
    service = get_service(body.network)
    if not service:
        raise HTTPException(status_code=400, detail="Red no soportada")

    try:
        prep_data = await service.prepare_transaction(
            from_address=body.from_address,
            to_address=body.to_address,
            amount=body.amount,
        )
        fee_keys = ["fee_estimate_btc", "fee_estimate_bnb", "fee_lamports_per_signature"]
        fee_estimate = 0
        for key in fee_keys:
            val = prep_data.pop(key, None)
            if val is not None:
                fee_estimate = float(val)
                break
        return PrepareSendResponse(
            network=body.network,
            fee_estimate=round(fee_estimate, 10),
            preparation_data=prep_data,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al preparar transaccion: {str(e)}")


@router.get("/history/{address}", response_model=list[TransactionHistoryItem])
@limiter.limit("10/minute")
async def get_history(
    request: Request,
    address: str,
    network: Network,
    user=Depends(get_current_user),
):
    """Obtiene el historial de transacciones con hash, monto, comision y estado"""
    service = get_service(network)
    if not service:
        raise HTTPException(status_code=400, detail="Red no soportada")

    try:
        txs = await service.get_transaction_history(address, limit=50)
        return [
            TransactionHistoryItem(
                tx_hash=tx.get("signature", tx.get("hash", tx.get("tx_hash", ""))),
                network=network,
                type=tx.get("type", "unknown"),
                amount=tx.get("amount", abs(tx.get("value", 0))),
                fee=tx.get("fee", 0),
                status=tx.get("status", "pendiente"),
                timestamp=datetime.datetime.fromtimestamp(tx["blockTime"]).isoformat() if tx.get("blockTime") else "",
                explorer_url=f"{EXPLORER_URLS[network]}{tx.get('signature', tx.get('hash', tx.get('tx_hash', '')))}",
                from_address=tx.get("from", ""),
                to_address=tx.get("to", ""),
                block_number=tx.get("block", tx.get("blockNumber", 0)),
                slot=tx.get("slot", tx.get("block_number", 0)),
            )
            for tx in txs
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
