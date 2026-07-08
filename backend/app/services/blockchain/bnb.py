import httpx
import asyncio
import logging
from app.config import get_settings
from .base import BlockchainService

logger = logging.getLogger(__name__)


class BNBService(BlockchainService):
    """Servicio para interactuar con BNB Chain (BSC) usando JSON-RPC sobre HTTPS"""

    def __init__(self):
        self.rpc_url = get_settings().bnb_rpc_url

    async def _rpc_call(self, method: str, params: list, retries: int = 2) -> dict:
        """Ejecuta una llamada JSON-RPC a la red BNB Chain de forma asincrona con retry"""
        for attempt in range(retries + 1):
            try:
                async with httpx.AsyncClient(timeout=httpx.Timeout(15.0)) as client:
                    response = await client.post(
                        self.rpc_url,
                        json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
                    )
                    response.raise_for_status()
                    return response.json()
            except Exception as e:
                logger.warning(f"BNB RPC call failed (attempt {attempt+1}/{retries+1}): {e}")
                if attempt < retries:
                    await asyncio.sleep(1)
                else:
                    return {"error": {"message": str(e)}}

    async def get_balance(self, address: str) -> float:
        """Obtiene el balance de BNB en wei y lo convierte a BNB (1 BNB = 10^18 wei)"""
        result = await self._rpc_call("eth_getBalance", [address, "latest"])
        wei_balance = int(result.get("result", "0x0"), 16)
        return wei_balance / 1e18

    async def prepare_transaction(self, from_address: str, to_address: str, amount: float) -> dict:
        """Prepara los datos necesarios para construir una transaccion BNB Chain (EVM compatible)
        Obtiene tres datos fundamentales de la red BSC mediante RPC:
        1. nonce: contador de transacciones de la direccion origen (evita reutilizacion)
        2. gas_price: precio actual del gas en wei
        3. chain_id: identificador de la cadena (56 para BSC mainnet, 97 para testnet)
        El frontend usa estos datos con el paquete web3dart para construir y firmar
        una transaccion EIP-1559 o legacy, codificarla en RLP y retornar el hex firmado
        """
        nonce_result = await self._rpc_call("eth_getTransactionCount", [from_address, "pending"])
        nonce_hex = nonce_result.get("result", "0x0")
        gas_result = await self._rpc_call("eth_gasPrice", [])
        gas_price_hex = gas_result.get("result", "0x3b9aca00")
        chain_result = await self._rpc_call("eth_chainId", [])
        chain_id_hex = chain_result.get("result", "0x38")
        chain_id = int(chain_id_hex, 16) if chain_id_hex else 56
        gas_price_wei = int(gas_price_hex, 16) if gas_price_hex else 10000000000
        fee_estimate = (gas_price_wei * 21000) / 1e18
        return {
            "nonce": nonce_hex,
            "gas_price_wei": gas_price_wei,
            "gas_price_hex": gas_price_hex,
            "chain_id": chain_id,
            "gas_limit": 21000,
            "fee_estimate_bnb": round(fee_estimate, 10),
        }

    async def send_transaction(self, signed_tx: str) -> str:
        """Transmite una transaccion firmada (RLP encoded hex) a la red BNB Chain"""
        result = await self._rpc_call("eth_sendRawTransaction", [signed_tx])
        return result.get("result", "")

    async def get_transaction_history(self, address: str, limit: int = 50) -> list[dict]:
        """Obtiene el historial de transacciones escaneando bloques recientes via JSON-RPC batch"""
        address_lower = address.lower()

        block_result = await self._rpc_call("eth_blockNumber", [])
        if "error" in block_result:
            logger.error(f"BNB history error: {block_result['error']}")
            return []
        current_block = int(block_result.get("result", "0x0"), 16)

        transactions = []
        seen_hashes = set()

        # Escanear bloques en orden descendente usando peticiones batch (50 bloques por request)
        scan_depth = 5000
        batch_size = 50
        from_block = max(current_block - scan_depth, 0)

        for batch_start in range(current_block, from_block - 1, -batch_size):
            batch_end = max(batch_start - batch_size + 1, 0)

            batch_requests = []
            for block_num in range(batch_start, batch_end - 1, -1):
                batch_requests.append({
                    "jsonrpc": "2.0",
                    "id": block_num,
                    "method": "eth_getBlockByNumber",
                    "params": [hex(block_num), True],
                })

            async with httpx.AsyncClient() as client:
                response = await client.post(self.rpc_url, json=batch_requests)
                response.raise_for_status()
                results = response.json()

            for resp in results:
                block_data = resp.get("result", {})
                block_num = resp.get("id", 0)
                for tx in block_data.get("transactions", []):
                    tx_hash = tx.get("hash", "")
                    if tx_hash in seen_hashes:
                        continue
                    tx_from = tx.get("from", "").lower()
                    tx_to = (tx.get("to") or "").lower()
                    if tx_from == address_lower or tx_to == address_lower:
                        seen_hashes.add(tx_hash)
                        transactions.append({
                            "hash": tx_hash,
                            "from": tx.get("from", ""),
                            "to": tx.get("to", ""),
                            "value": int(tx.get("value", "0x0"), 16) / 1e18,
                            "block": block_num,
                        })
                        if len(transactions) >= limit:
                            break
                if len(transactions) >= limit:
                    break
            if len(transactions) >= limit:
                break

        return transactions[:limit]
