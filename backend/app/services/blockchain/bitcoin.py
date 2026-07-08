import httpx
from app.config import get_settings
from .base import BlockchainService


class BitcoinService(BlockchainService):
    """Servicio para interactuar con la red Bitcoin usando la API de Mempool.space"""

    def __init__(self):
        self.api_url = get_settings().bitcoin_rpc_url

    async def get_balance(self, address: str) -> float:
        """Obtiene el balance total incluyendo transacciones confirmadas y no confirmadas"""
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{self.api_url}/address/{address}")
            response.raise_for_status()
            data = response.json()

            # Balance confirmado
            funded = data.get("chain_stats", {}).get("funded_txo_sum", 0)
            spent = data.get("chain_stats", {}).get("spent_txo_sum", 0)
            confirmed_balance = (funded - spent) / 1e8

            # Balance no confirmado (mempool)
            mempool_funded = data.get("mempool_stats", {}).get("funded_txo_sum", 0)
            mempool_spent = data.get("mempool_stats", {}).get("spent_txo_sum", 0)
            unconfirmed_balance = (mempool_funded - mempool_spent) / 1e8

            return round(confirmed_balance + unconfirmed_balance, 8)

    async def prepare_transaction(self, from_address: str, to_address: str, amount: float) -> dict:
        """Prepara los datos necesarios para construir y firmar una transaccion Bitcoin
        1. Obtiene los UTXOs disponibles para la direccion origen desde Mempool.space
        2. Selecciona UTXOs suficientes para cubrir el monto + comision estimada
        3. Calcula el vuelto (change) para la direccion origen
        4. Retorna los UTXOs seleccionados con sus scriptPubKey para que el frontend
           pueda construir el raw transaction, firmar cada entrada con ECDSA y ensamblar
        El frontend usa estos datos para construir el sighash de cada entrada y firmar
        con la clave privada secp256k1 usando el esquema BIP32
        """
        import hashlib
        utxos = await self.get_utxos(from_address)
        if not utxos:
            raise Exception("No hay UTXOs disponibles para esta direccion")

        amount_sats = int(amount * 1e8)
        fee_rate = 50  # satoshis/byte estimado
        selected = []
        selected_sum = 0
        for utxo in utxos:
            selected.append(utxo)
            selected_sum += utxo.get("value", 0)
            estimated_size = len(selected) * 148 + 34 + 10
            fee_est = estimated_size * fee_rate
            if selected_sum >= amount_sats + fee_est:
                break

        if selected_sum < amount_sats:
            raise Exception("Saldo insuficiente para cubrir el monto + comision")

        estimated_size = len(selected) * 148 + 34 + 10
        fee_estimate = estimated_size * fee_rate
        change_sats = selected_sum - amount_sats - fee_estimate
        if change_sats < 0:
            raise Exception("Saldo insuficiente para cubrir la comision")

        inputs_data = []
        for utxo in selected:
            inputs_data.append({
                "txid": utxo.get("txid", ""),
                "vout": utxo.get("vout", 0),
                "value_sats": utxo.get("value", 0),
                "script_pub_key": utxo.get("scriptpubkey", ""),
                "address": from_address,
            })

        return {
            "utxos": inputs_data,
            "to_address": to_address,
            "to_amount_sats": amount_sats,
            "change_address": from_address,
            "change_sats": change_sats,
            "fee_estimate_sats": fee_estimate,
            "fee_estimate_btc": round(fee_estimate / 1e8, 8),
        }

    async def send_transaction(self, signed_tx: str) -> str:
        """Transmite una transaccion Bitcoin firmada en formato hexadecimal"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.api_url}/tx",
                content=signed_tx,
                headers={"Content-Type": "text/plain"},
            )
            response.raise_for_status()
            return response.text.strip()

    async def get_utxos(self, address: str) -> list[dict]:
        """Obtiene los UTXOs disponibles para una direccion (necesario para construir transacciones)"""
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{self.api_url}/address/{address}/utxo")
            response.raise_for_status()
            return response.json()

    async def get_transaction_history(self, address: str, limit: int = 50) -> list[dict]:
        """Obtiene el historial de transacciones con montos y comisiones"""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.api_url}/address/{address}/txs",
                params={"limit": limit},
            )
            response.raise_for_status()
            txs_data = response.json()

        transactions = []
        for tx in txs_data[:limit]:
            txid = tx.get("txid", "")
            vin_sum = sum(inp.get("value", 0) for inp in tx.get("vin", []))
            vout_sum = sum(out.get("value", 0) for out in tx.get("vout", []))
            fee = (vin_sum - vout_sum) / 1e8 if vin_sum > vout_sum else 0

            # Monto recibido (outputs hacia nuestra direccion)
            amount_received = 0
            for out in tx.get("vout", []):
                script_address = out.get("scriptpubkey_address", "")
                if script_address == address:
                    amount_received += out.get("value", 0) / 1e8

            # Monto enviado (inputs desde nuestra direccion)
            amount_sent = 0
            for inp in tx.get("vin", []):
                prevout = inp.get("prevout", {})
                if prevout.get("scriptpubkey_address", "") == address:
                    amount_sent += prevout.get("value", 0)
            amount_sent_btc = amount_sent / 1e8

            if amount_received > 0 and amount_sent == 0:
                amount = amount_received
                tx_type = "received"
            elif amount_sent > 0 and amount_received == 0:
                amount = -amount_sent_btc
                tx_type = "sent"
            elif amount_received > 0 and amount_sent > 0:
                amount = amount_received - amount_sent_btc
                tx_type = "sent" if amount < 0 else "received"
            else:
                amount = 0
                tx_type = "sent"

            transactions.append({
                "hash": txid,
                "amount": round(amount, 8),
                "fee": round(fee, 8),
                "status": "confirmada" if tx.get("status", {}).get("confirmed") else "pendiente",
                "timestamp": tx.get("status", {}).get("block_time"),
                "type": tx_type,
            })

        return transactions
