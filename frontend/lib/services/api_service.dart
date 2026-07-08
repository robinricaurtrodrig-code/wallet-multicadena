/// Servicio de comunicacion con el backend de la Wallet Multicadena.
/// Proporciona metodos para consultar precios, balances, historial de transacciones,
/// preparar y enviar transacciones firmadas, notificar eventos de auth y actualizar configuracion.
/// Todas las peticiones incluyen autenticacion JWT cuando hay token disponible.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import '../models/asset.dart';

/// Clase que maneja todas las peticiones HTTP al backend.
class ApiService {
  // Por defecto apunta al backend en Railway; para desarrollo local:
  // flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wallet-multicadena-production.up.railway.app/api/v1',
  );

  String? _token;
  static const Duration _timeout = Duration(seconds: 15);

  /// Configura el token JWT para las peticiones autenticadas.
  void setToken(String? token) {
    _token = token;
  }

  /// Construye los headers incluyendo autenticacion si hay token.
  /// Incluye Content-Type: application/json y Authorization: Bearer <token> si existe.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  /// Obtiene los precios actuales de SOL, BTC y BNB desde CoinGecko a traves del backend.
  Future<MarketPrice> getPrices() async {
    final response = await http
        .get(Uri.parse('$baseUrl/prices/'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return MarketPrice.fromJson(json.decode(response.body));
    }
    throw Exception('Error al obtener precios');
  }

  /// Obtiene el balance de una red especifica para una direccion.
  /// network: "solana", "bitcoin" o "bnb".
  Future<WalletInfo> getBalance(String network, String address) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/blockchain/balance/$network/$address'),
          headers: _headers,
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return WalletInfo.fromJson(json.decode(response.body));
    }
    throw Exception('Error al obtener balance de $network');
  }

  /// Envia una transaccion firmada a la red correspondiente.
  /// El parametro signedTransaction contiene la transaccion serializada y firmada.
  Future<Transaction> sendTransaction({
    required String network,
    required String toAddress,
    required double amount,
    required String signedTransaction,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/blockchain/send'),
          headers: _headers,
          body: json.encode({
            'network': network,
            'to_address': toAddress,
            'amount': amount,
            'signed_transaction': signedTransaction,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return Transaction.fromJson(json.decode(response.body));
    }
    throw Exception('Error al enviar transaccion');
  }

  /// Obtiene el historial de transacciones para una direccion en una red especifica.
  /// Retorna una lista de objetos Transaction.
  Future<List<Transaction>> getHistory(String address, String network) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/blockchain/history/$address?network=$network'),
          headers: _headers,
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list.map((e) => Transaction.fromJson(e)).toList();
    }
    throw Exception('Error al obtener historial');
  }

  /// Prepara los datos necesarios para construir y firmar una transaccion.
  /// Retorna un mapa con blockhash, nonce, gas price, etc. segun la red.
  Future<Map<String, dynamic>> prepareTransaction({
    required String network,
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/blockchain/prepare-send'),
          headers: _headers,
          body: json.encode({
            'network': network,
            'from_address': fromAddress,
            'to_address': toAddress,
            'amount': amount,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error al preparar transaccion');
  }

  /// Notifica al backend sobre un inicio de sesion (para enviar correo de alerta).
  /// Ignora errores silenciosamente para no bloquear el flujo de login.
  Future<void> notifyLogin(String email, String username) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/notify-login'),
        headers: _headers,
        body: json.encode({'email': email, 'username': username}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Notifica al backend sobre un registro (para enviar correo de bienvenida).
  /// Ignora errores silenciosamente para no bloquear el flujo de registro.
  Future<void> notifyRegister(String email, String username) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/notify-register'),
        headers: _headers,
        body: json.encode({'email': email, 'username': username}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Actualiza la configuracion del usuario en el backend.
  /// Envia un mapa con las preferencias actualizadas.
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/auth/settings'),
          headers: _headers,
          body: json.encode(settings),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar configuracion');
    }
  }
}
