"""Locust stress test para la API Wallet Multicadena.
Simula multiples usuarios concurrentes consultando endpoints.

Uso:
    # Iniciar backend:
    cd backend && uvicorn app.main:app --port 8000

    # Stress test basico (30 usuarios, 30s):
    locust -f locustfile.py --host=http://localhost:8000 --headless --users 30 --spawn-rate 5 --run-time 30s --print-stats
"""

from locust import HttpUser, task, between


class HealthUser(HttpUser):
    """Simula usuarios que consultan el estado del servidor"""
    wait_time = between(0.5, 2)
    weight = 3

    @task(3)
    def health_check(self):
        self.client.get("/health", name="GET /health")

    @task(1)
    def root_info(self):
        self.client.get("/", name="GET /")


class PriceUser(HttpUser):
    """Simula usuarios que consultan precios de criptomonedas.
    Los precios se cachean por 60s, asi que la mayoria de las
    peticiones deben servirse desde cache.
    """
    wait_time = between(1, 5)
    weight = 5

    @task(5)
    def get_prices(self):
        self.client.get("/api/v1/prices/", name="GET /api/v1/prices/")


class AuthenticatedUser(HttpUser):
    """Simula usuarios autenticados.
    Esta clase es abstracta porque requiere un token JWT real.
    Para pruebas con autenticacion, sobrescribir on_start() para obtener un token.
    """
    wait_time = between(2, 8)
    abstract = True
    token = None

    def on_start(self):
        """Obtener token de autenticacion"""
        # En produccion, aqui se llamaria a /api/v1/auth/login con un id_token valido
        pass

    @task(1)
    def get_balance(self):
        if self.token:
            self.client.get(
                "/api/v1/blockchain/balance/solana/TestAddr",
                headers={"Authorization": f"Bearer {self.token}"},
                name="GET /api/v1/blockchain/balance/{network}/{address}",
            )
