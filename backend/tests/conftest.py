"""Configuracion de pytest para tests de integracion del backend.
Mockea Firebase y los servicios blockchain para pruebas sin conexion real.
"""

import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

# Agregar la carpeta raiz del backend al PATH para poder importar los modulos
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Configurar variables de entorno minimas para que pydantic-settings no falle
os.environ["FIREBASE_PROJECT_ID"] = "test-project-123"


@pytest.fixture(autouse=True)
def mock_firebase():
    """Mock global de Firebase Admin SDK para todos los tests.
    Reemplaza get_firebase_app y get_firestore_client para evitar
    conexiones reales a Firebase.
    """
    with patch("app.services.firebase.get_firebase_app") as mock_get_app, \
         patch("app.services.firebase.get_firestore_client") as mock_get_db, \
         patch("app.routers.auth.verify_id_token") as mock_verify, \
         patch("app.middleware.auth.verify_id_token") as mock_verify_mw:

        mock_verify.return_value = {"uid": "test-uid-123", "email": "test@example.com"}
        mock_verify_mw.return_value = {"uid": "test-uid-123", "email": "test@example.com"}

        mock_get_app.return_value = MagicMock()

        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.get.return_value = mock_doc
        mock_doc.to_dict.return_value = {
            "uid": "test-uid-123",
            "email": "test@example.com",
            "username": "testuser",
            "walletCreada": True,
        }
        mock_collection = MagicMock()
        mock_collection.document.return_value = mock_doc
        mock_db = MagicMock()
        mock_db.collection.return_value = mock_collection
        mock_get_db.return_value = mock_db

        yield


@pytest.fixture(autouse=True)
def clear_caches():
    """Limpia los caches en memoria entre tests para evitar contaminacion"""
    import app.routers.prices as prices_module
    import app.routers.transactions as txs_module
    prices_module.price_cache.clear()
    txs_module.price_cache.clear()
    yield


@pytest.fixture(autouse=True)
def override_auth_dependency():
    """Reemplaza la dependencia get_current_user para que devuelva
    un usuario mockeado sin necesidad de token JWT real."""
    from app.main import app
    from app.middleware.auth import get_current_user

    async def mock_get_current_user():
        return {
            "uid": "test-uid-123",
            "email": "test@example.com",
            "name": "testuser",
        }

    app.dependency_overrides[get_current_user] = mock_get_current_user
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def auth_header():
    """Header de autenticacion valido para peticiones protegidas.
    El token es mockeado por mock_firebase.
    """
    return {"Authorization": "Bearer fake-test-token"}


@pytest.fixture
def client():
    """Cliente de prueba FastAPI con dependencias mockeadas."""
    from app.main import app
    with TestClient(app) as c:
        yield c
