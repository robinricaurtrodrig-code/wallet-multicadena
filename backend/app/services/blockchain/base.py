"""Clase base abstracta para servicios blockchain.
Define la interfaz comun que deben implementar Solana, Bitcoin y BNB Chain:
balance, envio de transacciones, historial, preparacion y validacion de direcciones.
"""

from abc import ABC, abstractmethod


class BlockchainService(ABC):
    """Clase base abstracta para todos los servicios blockchain
    Define la interfaz comun que deben implementar Solana, Bitcoin y BNB Chain
    """

    @abstractmethod
    async def get_balance(self, address: str) -> float:
        """Obtiene el balance de una direccion en la red
        Retorna el balance en la unidad nativa (SOL, BTC, BNB)
        """
        pass

    @abstractmethod
    async def send_transaction(self, signed_tx: str) -> str:
        """Transmite una transaccion ya firmada a la red
        Retorna el hash de la transaccion
        """
        pass

    @abstractmethod
    async def get_transaction_history(self, address: str, limit: int = 50) -> list[dict]:
        """Obtiene el historial de transacciones de una direccion
        Retorna una lista de diccionarios con hash, monto, comision, estado, etc.
        """
        pass

    async def prepare_transaction(self, from_address: str, to_address: str, amount: float) -> dict:
        """Prepara los datos necesarios para que el frontend construya y firme una transaccion
        Este metodo es llamado por el endpoint POST /blockchain/prepare-send
        Cada red blockchain necesita datos diferentes para construir una transaccion:
        - Solana: recent blockhash (necesario para firmar)
        - Bitcoin: UTXOs disponibles para seleccionar como entradas
        - BNB: nonce, gas price y chain ID
        Retorna un diccionario con los datos especificos de cada red
        """
        return {"note": "No implementado"}

    async def validate_address(self, address: str) -> bool:
        """Valida que una direccion tenga el formato correcto para la red
        Implementacion por defecto que retorna True (cada red debe sobrescribir)
        """
        return True
