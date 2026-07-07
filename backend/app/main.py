from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.routers import auth, prices, transactions
from app.utils.security import limiter
from contextlib import asynccontextmanager
from app.services.firebase import get_firebase_app
import uvicorn


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verificar que Firebase se inicializa correctamente al arrancar
    try:
        get_firebase_app()
        print("Firebase inicializado correctamente")
    except Exception as e:
        print(f"Error al inicializar Firebase: {e}")
    yield


app = FastAPI(
    title="Wallet Multicadena API",
    description="Backend para wallet descentralizada multicadena (Solana, Bitcoin, BNB Chain)",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://wallet-multicadena.web.app",
        "https://wallet-multicadena.firebaseapp.com",
        "http://localhost:8000",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(prices.router, prefix="/api/v1")
app.include_router(transactions.router, prefix="/api/v1")


@app.get("/")
async def root():
    return {
        "app": "Wallet Multicadena API",
        "version": "1.0.0",
        "networks": ["solana", "bitcoin", "bnb"],
    }


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import os
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
