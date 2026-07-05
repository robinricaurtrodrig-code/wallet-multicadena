"""Tests de integracion para endpoints publicos (sin autenticacion):
- GET / (root)
- GET /health
"""


class TestRoot:
    """Verifica que el endpoint raiz retorne la info basica de la API"""

    def test_root_returns_app_info(self, client):
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["app"] == "Wallet Multicadena API"
        assert "version" in data
        assert "networks" in data
        assert "solana" in data["networks"]
        assert "bitcoin" in data["networks"]
        assert "bnb" in data["networks"]

    def test_root_version_is_string(self, client):
        response = client.get("/")
        data = response.json()
        assert isinstance(data["version"], str)
        assert len(data["version"]) > 0


class TestHealth:
    """Verifica que el endpoint de health retorne ok"""

    def test_health_returns_ok(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    def test_health_is_json(self, client):
        response = client.get("/health")
        assert response.headers["content-type"] == "application/json"
