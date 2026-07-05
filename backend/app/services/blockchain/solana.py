import httpx
from app.config import get_settings
from .base import BlockchainService


class SolanaService(BlockchainService):
    """Servicio para interactuar con la red Solana usando JSON-RPC"""

    def __init__(self):
        self.rpc_url = get_settings().solana_rpc_url

    async def _rpc_call(self, method: str, params: list) -> dict:
        """Ejecuta una llamada JSON-RPC a la red Solana de forma asincrona"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.rpc_url,
                json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
            )
            response.raise_for_status()
            return response.json()

    async def get_balance(self, address: str) -> float:
        """Obtiene el balance de SOL en lamports y lo convierte a SOL (1 SOL = 10^9 lamports)"""
        result = await self._rpc_call("getBalance", [address])
        if "error" in result:
            raise Exception(result["error"]["message"])
        lamports = result["result"]["value"]
        return lamports / 1e9

    async def prepare_transaction(self, from_address: str, to_address: str, amount: float) -> dict:
        """Prepara los datos necesarios para construir una transaccion Solana
        Obtiene el recent blockhash de la red Solana mediante RPC getRecentBlockhash
        El frontend necesita este blockhash para construir el mensaje de la transaccion
        y firmarlo con la clave privada Ed25519
        Retorna el blockhash y la comision estimada por firma
        """
        result = await self._rpc_call("getRecentBlockhash", [])
        blockhash = result.get("result", {}).get("value", {}).get("blockhash", "")
        fee_info = await self._rpc_call("getFeeCalculatorForBlockhash", [blockhash])
        fee_calculator = fee_info.get("result", {}).get("value", {}).get("feeCalculator", {})
        fee_lamports = fee_calculator.get("lamportsPerSignature", 5000)
        fee_sol = fee_lamports / 1e9
        return {
            "recent_blockhash": blockhash,
            "fee_lamports_per_signature": fee_lamports,
            "min_rent_exempt": 0,
        }

    async def send_transaction(self, signed_tx: str) -> str:
        """Transmite una transaccion firmada en formato base64 a la red Solana"""
        result = await self._rpc_call("sendTransaction", [signed_tx])
        if "error" in result:
            raise Exception(result["error"]["message"])
        return result["result"]

    async def get_transaction_history(self, address: str, limit: int = 50) -> list[dict]:
        """Obtiene el historial de transacciones con detalles completos (monto, comision)"""
        # Primero obtener las firmas de transacciones asociadas a la direccion
        sig_result = await self._rpc_call("getSignaturesForAddress", [
            address,
            {"limit": min(limit, 1000)},
        ])
        if "error" in sig_result:
            raise Exception(sig_result["error"]["message"])

        signatures = sig_result.get("result", [])
        transactions = []

        # Para cada firma, obtener los detalles completos de la transaccion
        for sig_info in signatures[:limit]:
            sig = sig_info.get("signature", "")
            tx_result = await self._rpc_call("getTransaction", [sig, {"encoding": "json", "maxSupportedTransactionVersion": 0}])
            tx_data = tx_result.get("result")

            if tx_data:
                meta = tx_data.get("meta", {})
                pre_balances = meta.get("preBalances", [])
                post_balances = meta.get("postBalances", [])
                fee = meta.get("fee", 0) / 1e9

                # Calcular el monto de la transaccion (diferencia de balances)
                amount = 0
                if pre_balances and post_balances and len(pre_balances) > 0:
                    amount = abs(pre_balances[0] - post_balances[0]) / 1e9

                transactions.append({
                    "signature": sig,
                    "amount": round(amount, 8),
                    "fee": round(fee, 8),
                    "status": sig_info.get("confirmationStatus", "confirmada"),
                    "slot": sig_info.get("slot", 0),
                    "blockTime": sig_info.get("blockTime"),
                    "type": "sent" if amount > 0 else "received",
                })
            else:
                transactions.append({
                    "signature": sig,
                    "amount": 0,
                    "fee": 0,
                    "status": sig_info.get("confirmationStatus", "confirmada"),
                    "slot": sig_info.get("slot", 0),
                })

        return transactions
