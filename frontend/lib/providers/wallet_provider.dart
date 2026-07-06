import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:bip32/bip32.dart' as bip32;
import '../models/wallet.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/transaction_builder.dart';
import '../core/crypto/bip39.dart';
import '../core/crypto/bip44.dart';
import '../core/crypto/aes_encryption.dart';
import '../core/storage/secure_storage.dart';


///
/// WalletProvider: Proveedor principal de estado para la wallet multicadena
/// Gestiona el ciclo de vida completo: creacion, importacion, almacenamiento
/// y consulta de balances/precios para las 3 redes (Solana, Bitcoin, BNB)
///
class WalletProvider extends ChangeNotifier {
  final ApiService apiService;

  WalletProvider({required this.apiService});

  bool _isLoading = false;
  String? _error;
  MarketPrice? _prices;

  // Lista de wallets/balances por red (Solana, Bitcoin, BNB)
  List<WalletInfo> _wallets = [];

  // Historial de transacciones recientes
  List<Transaction> _recentTransactions = [];

  // Frase semilla (solo temporal durante creacion)
  String? _seedPhrase;

  // Frase semilla cifrada almacenada localmente
  String? _encryptedSeed;

  // Direcciones derivadas para cada red
  String? _solanaAddress;
  String? _bitcoinAddress;
  String? _bnbAddress;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WalletInfo> get wallets => _wallets;
  MarketPrice? get prices => _prices;
  List<Transaction> get recentTransactions => _recentTransactions;
  String? get seedPhrase => _seedPhrase;
  bool get hasWallet => _encryptedSeed != null;
  String? get solanaAddress => _solanaAddress;
  String? get bitcoinAddress => _bitcoinAddress;
  String? get bnbAddress => _bnbAddress;

  ///
  /// Calcula el balance total en USD sumando todas las redes
  ///
  double get totalUsd {
    double total = 0;
    for (final w in _wallets) {
      total += w.balanceUsd;
    }
    return total;
  }

  ///
  /// Genera una nueva frase semilla BIP39 de 12 palabras
  /// Retorna la frase generada para mostrarla al usuario
  ///
  Future<String> generateWallet() async {
    _seedPhrase = BIP39Service.generateSeedPhrase(wordCount: 12);
    return _seedPhrase!;
  }

  ///
  /// Guarda la wallet recien creada:
  /// 1. Deriva direcciones BIP44 para cada red
  /// 2. Cifra la frase semilla con AES-256
  /// 3. Almacena en SecureStorage con prefijo del usuario
  /// 4. Actualiza flag walletCreada en Firestore
  ///
  Future<void> saveWallet(String seedPhrase, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validar la frase semilla BIP39
      if (!BIP39Service.validateSeedPhrase(seedPhrase)) {
        _error = 'Frase semilla invalida';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Convertir frase semilla a seed bytes (BIP39)
      final seedBytes = BIP39Service.mnemonicToSeed(seedPhrase);

      // Derivar direcciones para las 3 redes usando BIP44
      _solanaAddress = await BIP44Derivation.deriveSolanaAddress(seedBytes);
      _bitcoinAddress = BIP44Derivation.deriveBitcoinAddress(seedBytes);
      _bnbAddress = BIP44Derivation.deriveBNBAddress(seedBytes);

      // Cifrar la frase semilla con AES-256 usando la contrasena del usuario
      final encrypted = AESEncryption.encrypt(seedPhrase, password);
      await SecureStorage.saveEncryptedSeed(encrypted);
      _encryptedSeed = encrypted;

      // Guardar las direcciones derivadas en almacenamiento seguro
      await SecureStorage.saveAddresses(
        solana: _solanaAddress!,
        bitcoin: _bitcoinAddress!,
        bnb: _bnbAddress!,
      );

      // Actualizar walletCreada en Firestore
      await _updateWalletCreatedFlag(true);

      // Limpiar la frase semilla de la memoria por seguridad
      _seedPhrase = null;
    } catch (e) {
      _error = 'Error al guardar wallet: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  ///
  /// Importa una wallet existente desde una frase semilla BIP39
  /// Realiza el mismo proceso que saveWallet pero sin generar nueva seed
  ///
  Future<bool> importWallet(String seedPhrase, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!BIP39Service.validateSeedPhrase(seedPhrase)) {
        _error = 'Frase semilla invalida';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final seedBytes = BIP39Service.mnemonicToSeed(seedPhrase);

      try {
        _solanaAddress = await BIP44Derivation.deriveSolanaAddress(seedBytes);
      } catch (e) {
        _error = 'Error al derivar direccion Solana: $e';
        _isLoading = false; notifyListeners(); return false;
      }
      try {
        _bitcoinAddress = BIP44Derivation.deriveBitcoinAddress(seedBytes);
      } catch (e) {
        _error = 'Error al derivar direccion Bitcoin: $e';
        _isLoading = false; notifyListeners(); return false;
      }
      try {
        _bnbAddress = BIP44Derivation.deriveBNBAddress(seedBytes);
      } catch (e) {
        _error = 'Error al derivar direccion BNB: $e';
        _isLoading = false; notifyListeners(); return false;
      }

      String encrypted;
      try {
        encrypted = AESEncryption.encrypt(seedPhrase, password);
      } catch (e) {
        _error = 'Error al cifrar seed phrase: $e';
        _isLoading = false; notifyListeners(); return false;
      }
      await SecureStorage.saveEncryptedSeed(encrypted);
      _encryptedSeed = encrypted;

      await SecureStorage.saveAddresses(
        solana: _solanaAddress!,
        bitcoin: _bitcoinAddress!,
        bnb: _bnbAddress!,
      );

      await _updateWalletCreatedFlag(true);

      _seedPhrase = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error inesperado al importar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  ///
  /// Desbloquea la wallet con la contrasena de cifrado:
  /// 1. Descifra la frase semilla desde SecureStorage
  /// 2. Recupera o deriva las direcciones de cada red
  ///
  Future<bool> unlockWallet(String password) async {
    try {
      final encrypted = await SecureStorage.getEncryptedSeed();
      if (encrypted == null) return false;

      // Descifrar la frase semilla con AES-256
      final decrypted = AESEncryption.decrypt(encrypted, password);
      final seedBytes = BIP39Service.mnemonicToSeed(decrypted);

      // Recuperar direcciones desde almacenamiento seguro
      final addresses = await SecureStorage.getAddresses();
      if (addresses != null) {
        _solanaAddress = addresses['solana'];
        _bitcoinAddress = addresses['bitcoin'];
        _bnbAddress = addresses['bnb'];
      } else {
        // Si no hay direcciones guardadas, derivar de nuevo
        _solanaAddress = await BIP44Derivation.deriveSolanaAddress(seedBytes);
        _bitcoinAddress = BIP44Derivation.deriveBitcoinAddress(seedBytes);
        _bnbAddress = BIP44Derivation.deriveBNBAddress(seedBytes);
      }

      _encryptedSeed = encrypted;
      _seedPhrase = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  ///
  /// Obtiene los balances de las 3 redes en paralelo usando las direcciones derivadas
  /// Cada red se consulta individualmente para manejar errores por separado
  ///
  Future<void> fetchAllBalances() async {
    if (_solanaAddress == null || _bitcoinAddress == null || _bnbAddress == null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    // Obtener precios primero (de CoinGecko via backend)
    await fetchPrices();

    // Consultar balance de cada red en paralelo
    final results = await Future.wait([
      _fetchSingleBalance('solana', _solanaAddress!),
      _fetchSingleBalance('bitcoin', _bitcoinAddress!),
      _fetchSingleBalance('bnb', _bnbAddress!),
    ]);

    // Filtrar solo resultados exitosos y actualizar la lista
    _wallets = results.whereType<WalletInfo>().toList();

    _isLoading = false;
    notifyListeners();
  }

  ///
  /// Consulta el balance de una red especifica y construye un WalletInfo
  /// Si la consulta falla, retorna null para no interrumpir las demas redes
  ///
  Future<WalletInfo?> _fetchSingleBalance(String network, String address) async {
    try {
      return await apiService.getBalance(network, address);
    } catch (e) {
      debugPrint('Error al obtener balance de $network: $e');
      return WalletInfo(
        address: address,
        network: network,
        symbol: _symbolForNetwork(network),
        balance: 0,
        balanceUsd: 0,
        usdPrice: _priceForNetwork(network),
      );
    }
  }

  ///
  /// Retorna el simbolo correspondiente a cada red
  ///
  String _symbolForNetwork(String network) {
    switch (network) {
      case 'solana': return 'SOL';
      case 'bitcoin': return 'BTC';
      case 'bnb': return 'BNB';
      default: return '???';
    }
  }

  ///
  /// Retorna el precio en USD de la red si ya se obtuvieron los precios
  ///
  double _priceForNetwork(String network) {
    if (_prices == null) return 0;
    switch (network) {
      case 'solana': return _prices!.solana;
      case 'bitcoin': return _prices!.bitcoin;
      case 'bnb': return _prices!.bnb;
      default: return 0;
    }
  }

  ///
  /// Obtiene los precios actualizados de SOL, BTC y BNB desde CoinGecko
  /// a traves del backend (api_service.getPrices)
  ///
  Future<void> fetchPrices() async {
    try {
      _prices = await apiService.getPrices();
      notifyListeners();
    } catch (e) {
      _error = 'Error al obtener precios: $e';
    }
  }

  ///
  /// Obtiene el historial de transacciones para una red especifica
  ///
  Future<void> fetchHistory(String network) async {
    final address = _getAddressForNetwork(network);
    if (address == null) return;

    try {
      final txs = await apiService.getHistory(address, network);
      _recentTransactions = txs;
      notifyListeners();
    } catch (e) {
      _error = 'Error al obtener historial: $e';
    }
  }

  ///
  /// Retorna la direccion publica correspondiente a la red solicitada
  ///
  String? _getAddressForNetwork(String network) {
    switch (network) {
      case 'solana':
        return _solanaAddress;
      case 'bitcoin':
        return _bitcoinAddress;
      case 'bnb':
        return _bnbAddress;
      default:
        return null;
    }
  }

  ///
  /// Actualiza el flag walletCreada en Firestore para el usuario actual
  /// Esto permite saber si el usuario ya completo la creacion de su wallet
  ///
  Future<void> _updateWalletCreatedFlag(bool created) async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('USERS')
            .doc(user.uid)
            .update({'walletCreada': created});
      }
    } catch (_) {}
  }

  ///
  /// Verifica si el usuario ya tiene una wallet guardada localmente
  /// Al iniciar la app, revisa SecureStorage por seed phrase cifrada y direcciones
  ///
  Future<bool> checkExistingWallet() async {
    final hasSeed = await SecureStorage.hasSeed();
    if (hasSeed) {
      final addresses = await SecureStorage.getAddresses();
      if (addresses != null) {
        _solanaAddress = addresses['solana'];
        _bitcoinAddress = addresses['bitcoin'];
        _bnbAddress = addresses['bnb'];
      }
      _encryptedSeed = await SecureStorage.getEncryptedSeed();
    }
    notifyListeners();
    return hasSeed;
  }

  ///
  /// Obtiene la clave privada derivada para una red especifica
  /// Requiere la contrasena de cifrado para descifrar la seed phrase
  ///
  Future<Uint8List> getPrivateKey(String network, String password) async {
    final encrypted = _encryptedSeed ?? await SecureStorage.getEncryptedSeed();
    if (encrypted == null) throw Exception('Wallet no encontrada');
    final decrypted = AESEncryption.decrypt(encrypted, password);
    final seedBytes = BIP39Service.mnemonicToSeed(decrypted);
    switch (network) {
      case 'solana':
        return await BIP44Derivation.deriveSolanaKey(seedBytes);
      case 'bitcoin': {
        final key = BIP44Derivation.deriveBitcoinKey(seedBytes);
        return Uint8List.fromList(key.privateKey!);
      }
      case 'bnb': {
        final key = BIP44Derivation.deriveBNBKey(seedBytes);
        return Uint8List.fromList(key.privateKey!);
      }
      default:
        throw Exception('Red no soportada: $network');
    }
  }

  ///
  /// Obtiene el objeto BIP32 para Bitcoin (necesario para firmar)
  ///
  Future<bip32.BIP32> getBitcoinKey(String password) async {
    final encrypted = _encryptedSeed ?? await SecureStorage.getEncryptedSeed();
    if (encrypted == null) throw Exception('Wallet no encontrada');
    final decrypted = AESEncryption.decrypt(encrypted, password);
    final seedBytes = BIP39Service.mnemonicToSeed(decrypted);
    return BIP44Derivation.deriveBitcoinKey(seedBytes);
  }

  ///
  /// Envia una transaccion a la red blockchain:
  /// 1. Prepara la transaccion (obtiene blockhash/nonce/UTXOs del backend)
  /// 2. Construye y firma la transaccion localmente
  /// 3. Retransmite la transaccion firmada a traves del backend
  ///
  Future<Transaction> sendTransaction({
    required String network,
    required String toAddress,
    required double amount,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fromAddress = _getAddressForNetwork(network);
      if (fromAddress == null) throw Exception('Direccion no encontrada para $network');

      // 1. Preparar transaccion (obtener datos de la red)
      final prepared = await apiService.prepareTransaction(
        network: network,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: amount,
      );
      final prepData = prepared['preparation_data'] as Map<String, dynamic>;

      // 2. Firmar la transaccion
      String signedTx;
      if (network == 'bnb') {
        final privateKey = await getPrivateKey(network, password);
        signedTx = await TransactionBuilder.buildAndSignBnb(
          privateKey: privateKey,
          toAddress: toAddress,
          amount: amount,
          nonceHex: prepData['nonce'] as String,
          chainId: prepData['chain_id'] as int,
          gasLimit: prepData['gas_limit'] as int,
          gasPriceWei: prepData['gas_price_wei'] as int,
        );
      } else if (network == 'solana') {
        final privateKey = await getPrivateKey(network, password);
        signedTx = await TransactionBuilder.buildAndSignSolana(
          privateKey: privateKey,
          fromAddress: fromAddress,
          toAddress: toAddress,
          amount: amount,
          recentBlockhash: prepData['recent_blockhash'] as String,
        );
      } else if (network == 'bitcoin') {
        final key = await getBitcoinKey(password);
        final utxos = (prepData['utxos'] as List).cast<Map<String, dynamic>>();
        signedTx = await TransactionBuilder.buildAndSignBitcoin(
          key: key,
          utxos: utxos,
          toAddress: toAddress,
          toAmountSats: prepData['to_amount_sats'] as int,
          changeAddress: prepData['change_address'] as String,
          changeSats: prepData['change_sats'] as int,
        );
      } else {
        throw Exception('Red no soportada');
      }

      // 3. Retransmitir la transaccion firmada
      final tx = await apiService.sendTransaction(
        network: network,
        toAddress: toAddress,
        amount: amount,
        signedTransaction: signedTx,
      );

      _isLoading = false;
      notifyListeners();
      return tx;
    } catch (e) {
      _error = 'Error al enviar transaccion: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  ///
  /// Retorna la red para una direccion (util para escaner QR)
  ///
  String? networkForAddress(String address) {
    if (address.startsWith('0x')) return 'bnb';
    if (address.startsWith('1') || address.startsWith('3') || address.startsWith('bc1')) return 'bitcoin';
    if (address.length > 30) return 'solana';
    return null;
  }

  ///
  /// Limpia todos los datos de la wallet (para logout)
  /// Elimina datos en memoria y tambien los almacenados en SecureStorage
  ///
  Future<void> clearWallet() async {
    _wallets = [];
    _prices = null;
    _recentTransactions = [];
    _seedPhrase = null;
    _encryptedSeed = null;
    _solanaAddress = null;
    _bitcoinAddress = null;
    _bnbAddress = null;
    _error = null;
    // Limpiar el almacenamiento seguro del usuario
    await SecureStorage.clearUserData();
    notifyListeners();
  }
}
