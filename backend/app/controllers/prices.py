from fastapi import APIRouter
from app.models.schemas import PriceResponse
from app.utils.security import limiter
from fastapi import Request
import httpx
from cachetools import TTLCache
from app.config import get_settings

router = APIRouter(prefix="/prices", tags=["Precios"])

# Cache en memoria con TTL de 60 segundos para evitar llamadas repetitivas a CoinGecko
price_cache = TTLCache(maxsize=1, ttl=60)


@router.get("/", response_model=PriceResponse)
@limiter.limit("30/minute")
async def get_prices(request: Request):
    """Obtiene los precios actuales de SOL, BTC y BNB en USD desde CoinGecko
    Los resultados se cachean por 60 segundos para reducir carga en la API externa
    """
    # Devolver datos cacheados si existen
    if "prices" in price_cache:
        return price_cache["prices"]

    settings = get_settings()
    async with httpx.AsyncClient() as client:
        # Consultar precios actuales desde CoinGecko API v3
        response = await client.get(
            f"{settings.coingecko_api_url}/simple/price",
            params={
                "ids": "solana,bitcoin,binancecoin",
                "vs_currencies": "usd",
            },
        )
        response.raise_for_status()
        data = response.json()

    # Construir respuesta con los precios obtenidos
    result = PriceResponse(
        solana=data.get("solana", {}).get("usd", 0),
        bitcoin=data.get("bitcoin", {}).get("usd", 0),
        bnb=data.get("binancecoin", {}).get("usd", 0),
        last_updated=response.headers.get("date", ""),
    )
    price_cache["prices"] = result
    return result
