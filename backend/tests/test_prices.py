"""Tests de integracion para el endpoint de precios:
- GET /api/v1/prices/
Verifica que los precios se obtienen correctamente de CoinGecko
y que el cache funciona adecuadamente.
"""

from unittest.mock import patch, AsyncMock, MagicMock


class TestPrices:
    """Test del endpoint de precios con CoinGecko mockeado"""

    COINGECKO_RESPONSE = {
        "solana": {"usd": 150.25},
        "bitcoin": {"usd": 42000.00},
        "binancecoin": {"usd": 333.50},
    }

    def _make_mock_response(self):
        """Crea un mock de respuesta HTTP con json() sincrono"""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = self.COINGECKO_RESPONSE
        mock_resp.headers = {"date": "Mon, 04 Jul 2026 12:00:00 GMT"}
        return mock_resp

    @patch("app.routers.prices.httpx.AsyncClient")
    def test_get_prices_success(self, mock_httpx, client):
        mock_resp = self._make_mock_response()
        mock_httpx.return_value.__aenter__.return_value.get.return_value = mock_resp

        response = client.get("/api/v1/prices/")
        assert response.status_code == 200
        data = response.json()
        assert data["solana"] == 150.25
        assert data["bitcoin"] == 42000.00
        assert data["bnb"] == 333.50
        assert "last_updated" in data

    @patch("app.routers.prices.httpx.AsyncClient")
    def test_get_prices_coin_ids(self, mock_httpx, client):
        """Verifica que CoinGecko recibe los parametros correctos"""
        mock_resp = self._make_mock_response()
        mock_httpx.return_value.__aenter__.return_value.get.return_value = mock_resp

        client.get("/api/v1/prices/")

        call_kwargs = mock_httpx.return_value.__aenter__.return_value.get.call_args[1]
        assert call_kwargs["params"]["ids"] == "solana,bitcoin,binancecoin"
        assert call_kwargs["params"]["vs_currencies"] == "usd"

    @patch("app.routers.prices.httpx.AsyncClient")
    def test_prices_use_cache(self, mock_httpx, client):
        """La segunda llamada debe usar cache, no llamar a CoinGecko"""
        mock_resp = self._make_mock_response()
        mock_httpx.return_value.__aenter__.return_value.get.return_value = mock_resp

        # Primera llamada - debe consultar CoinGecko
        client.get("/api/v1/prices/")
        assert mock_httpx.return_value.__aenter__.return_value.get.call_count == 1

        # Segunda llamada - debe usar cache (no incrementar call_count)
        client.get("/api/v1/prices/")
        assert mock_httpx.return_value.__aenter__.return_value.get.call_count == 1
