"""Tests de integracion para los endpoints de autenticacion:
- POST /api/v1/auth/register
- POST /api/v1/auth/login
- POST /api/v1/auth/logout
- GET /api/v1/auth/profile
- GET /api/v1/auth/settings
- PUT /api/v1/auth/settings
"""


class TestRegister:
    """Test del endpoint de registro de usuario"""

    def test_register_invalid_email(self, client):
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "password": "123456",
                "username": "testuser",
            },
        )
        assert response.status_code == 422  # Validation error

    def test_register_short_password(self, client):
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "test@example.com",
                "password": "123",
                "username": "testuser",
            },
        )
        assert response.status_code == 422

    def test_register_short_username(self, client):
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "test@example.com",
                "password": "123456",
                "username": "x",
            },
        )
        assert response.status_code == 422


class TestLogin:
    """Test del endpoint de inicio de sesion"""

    def test_login_with_valid_token(self, client):
        response = client.post(
            "/api/v1/auth/login",
            json={
                "id_token": "valid-firebase-id-token",
                "device_id": "device123",
                "fcm_token": "fcm-token-abc",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["uid"] == "test-uid-123"
        assert data["email"] == "test@example.com"
        assert data["username"] == "testuser"

    def test_login_without_device_id(self, client):
        response = client.post(
            "/api/v1/auth/login",
            json={
                "id_token": "valid-token",
            },
        )
        assert response.status_code == 200
        assert response.json()["uid"] == "test-uid-123"


class TestProfile:
    """Test del endpoint de perfil de usuario"""

    def test_get_profile(self, client):
        response = client.get("/api/v1/auth/profile")
        assert response.status_code == 200
        data = response.json()
        assert data["uid"] == "test-uid-123"


class TestSettings:
    """Test del endpoint de configuracion de usuario"""

    def test_get_settings(self, client):
        response = client.get("/api/v1/auth/settings")
        assert response.status_code == 200

    def test_update_settings(self, client):
        response = client.put(
            "/api/v1/auth/settings",
            json={"idioma": "en", "tema": "light"},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "ok"

    def test_update_settings_invalid_language(self, client):
        response = client.put(
            "/api/v1/auth/settings",
            json={"idioma": "fr"},
        )
        assert response.status_code == 422


class TestLogout:
    """Test del endpoint de cierre de sesion"""

    def test_logout(self, client):
        response = client.post("/api/v1/auth/logout")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
