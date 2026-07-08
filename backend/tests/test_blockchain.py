"""Tests de integracion para los endpoints blockchain:
- GET /api/v1/blockchain/balance/{network}/{address}
- POST /api/v1/blockchain/prepare-send
- POST /api/v1/blockchain/send
- GET /api/v1/blockchain/history/{address}
"""

from unittest.mock import patch, AsyncMock, MagicMock


class TestGetBalance:
    """Test del endpoint de balance con servicios blockchain mockeados"""

    @patch("app.controllers.transactions.SolanaService")
    def test_solana_balance(self, mock_solana, client):
        mock_solana.return_value.get_balance = AsyncMock(return_value=10.5)
        with patch("app.controllers.transactions.get_usd_prices", new_callable=AsyncMock) as mock_prices:
            mock_prices.return_value = {"solana": 150.0}

            response = client.get(
                "/api/v1/blockchain/balance/solana/TestAddr123",
            )
            assert response.status_code == 200
            data = response.json()
            assert data["network"] == "solana"
            assert data["symbol"] == "SOL"
            assert data["balance"] == 10.5
            assert data["balance_usd"] == 1575.0

    @patch("app.controllers.transactions.BitcoinService")
    def test_bitcoin_balance(self, mock_btc, client):
        mock_btc.return_value.get_balance = AsyncMock(return_value=0.5)
        with patch("app.controllers.transactions.get_usd_prices", new_callable=AsyncMock) as mock_prices:
            mock_prices.return_value = {"bitcoin": 42000.0}

            response = client.get(
                "/api/v1/blockchain/balance/bitcoin/1BTCaddr",
            )
            assert response.status_code == 200
            data = response.json()
            assert data["network"] == "bitcoin"
            assert data["symbol"] == "BTC"
            assert data["balance"] == 0.5
            assert data["balance_usd"] == 21000.0

    @patch("app.controllers.transactions.BNBService")
    def test_bnb_balance(self, mock_bnb, client):
        mock_bnb.return_value.get_balance = AsyncMock(return_value=25.0)
        with patch("app.controllers.transactions.get_usd_prices", new_callable=AsyncMock) as mock_prices:
            mock_prices.return_value = {"bnb": 333.0}

            response = client.get(
                "/api/v1/blockchain/balance/bnb/0xBnbAddr",
            )
            assert response.status_code == 200
            data = response.json()
            assert data["network"] == "bnb"
            assert data["symbol"] == "BNB"
            assert data["balance"] == 25.0

    @patch("app.controllers.transactions.SolanaService")
    def test_balance_returns_zero_on_error(self, mock_solana, client):
        mock_solana.return_value.get_balance = AsyncMock(side_effect=Exception("RPC error"))
        with patch("app.controllers.transactions.get_usd_prices", new_callable=AsyncMock) as mock_prices:
            mock_prices.return_value = {"solana": 150.0}

            response = client.get(
                "/api/v1/blockchain/balance/solana/AddrError",
            )
            assert response.status_code == 200
            assert response.json()["balance"] == 0


class TestPrepareSend:
    """Test del endpoint de preparacion de envio"""

    @patch("app.controllers.transactions.SolanaService")
    def test_prepare_send_solana(self, mock_solana, client):
        mock_solana.return_value.prepare_transaction = AsyncMock(return_value={
            "recent_blockhash": "abc123",
            "fee_lamports_per_signature": 5000,
        })

        response = client.post(
            "/api/v1/blockchain/prepare-send",
            json={
                "network": "solana",
                "from_address": "FromAddr",
                "to_address": "ToAddr",
                "amount": 0.1,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["network"] == "solana"
        assert "recent_blockhash" in data["preparation_data"]

    @patch("app.controllers.transactions.BitcoinService")
    def test_prepare_send_bitcoin(self, mock_btc, client):
        mock_btc.return_value.prepare_transaction = AsyncMock(return_value={
            "utxos": [{"txid": "prevtx", "vout": 0, "value": 100000}],
            "change_address": "ChangeAddr",
            "fee_estimate_btc": 0.00001,
        })

        response = client.post(
            "/api/v1/blockchain/prepare-send",
            json={
                "network": "bitcoin",
                "from_address": "FromAddr",
                "to_address": "ToAddr",
                "amount": 0.01,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["network"] == "bitcoin"
        assert len(data["preparation_data"]["utxos"]) == 1

    @patch("app.controllers.transactions.BNBService")
    def test_prepare_send_bnb(self, mock_bnb, client):
        mock_bnb.return_value.prepare_transaction = AsyncMock(return_value={
            "nonce": "5",
            "gas_price_wei": 5000000000,
            "chain_id": 56,
            "gas_limit": 21000,
            "fee_estimate_bnb": 0.0001,
        })

        response = client.post(
            "/api/v1/blockchain/prepare-send",
            json={
                "network": "bnb",
                "from_address": "0xFrom",
                "to_address": "0xTo",
                "amount": 0.5,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["network"] == "bnb"
        assert data["preparation_data"]["chain_id"] == 56

    def test_prepare_send_invalid_network(self, client):
        response = client.post(
            "/api/v1/blockchain/prepare-send",
            json={
                "network": "ethereum",
                "from_address": "addr",
                "to_address": "addr",
                "amount": 1.0,
            },
        )
        assert response.status_code == 422


class TestSendTransaction:
    """Test del endpoint de envio de transaccion firmada"""

    @patch("app.controllers.transactions.SolanaService")
    def test_send_solana_transaction(self, mock_solana, client):
        mock_solana.return_value.send_transaction = AsyncMock(
            return_value="5VERv8NM1iEdYoRXjF3PgnT2BpyM8QkfFfQ4o7yFJ9Wr"
        )

        response = client.post(
            "/api/v1/blockchain/send",
            json={
                "network": "solana",
                "to_address": "ToAddr",
                "amount": 0.1,
                "signed_transaction": "base64signedtx",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["network"] == "solana"
        assert data["tx_hash"] == "5VERv8NM1iEdYoRXjF3PgnT2BpyM8QkfFfQ4o7yFJ9Wr"
        assert data["status"] == "pendiente"
        assert "explorer_url" in data

    @patch("app.controllers.transactions.SolanaService")
    def test_send_transaction_failure(self, mock_solana, client):
        mock_solana.return_value.send_transaction = AsyncMock(
            side_effect=Exception("Blockchain rejected tx")
        )

        response = client.post(
            "/api/v1/blockchain/send",
            json={
                "network": "solana",
                "to_address": "ToAddr",
                "amount": 0.1,
                "signed_transaction": "badsig",
            },
        )
        assert response.status_code == 500
        assert "error" in response.json()["detail"].lower()


class TestGetHistory:
    """Test del endpoint de historial de transacciones"""

    @patch("app.controllers.transactions.SolanaService")
    def test_get_history_solana(self, mock_solana, client):
        mock_solana.return_value.get_transaction_history = AsyncMock(return_value=[
            {
                "signature": "sig1",
                "type": "received",
                "amount": 1.0,
                "fee": 0.000005,
                "status": "confirmed",
                "blockTime": 1720000000,
            },
            {
                "signature": "sig2",
                "type": "sent",
                "amount": 0.5,
                "fee": 0.000005,
                "status": "confirmed",
                "blockTime": 1720000100,
            },
        ])

        response = client.get(
            "/api/v1/blockchain/history/SolAddr?network=solana",
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["type"] == "received"
        assert data[1]["type"] == "sent"
        assert "explorer_url" in data[0]
        assert "solscan.io" in data[0]["explorer_url"]
