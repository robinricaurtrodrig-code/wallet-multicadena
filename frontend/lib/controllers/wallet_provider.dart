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
/// WalletProvider: Proveedor principal de estado para la wallet multicadena.
/// Gestiona el ciclo de vida completo: creacion de wallet con derivacion BIP44
/// para 3 redes (Solana, Bitcoin, BNB), importacion desde frase semilla BIP39,
/// cifrado AES-256 de la seed phrase, almacenamiento seguro en SecureStorage,
/// consulta de balances y precios via API, construccion y firma de transacciones,
/// y limpieza de datos al cerrar sesion.
///
class WalletProvider extends ChangeNotifier {
  final ApiService apiService;

  /// Inicializa el provider con la instancia de ApiService para consultas externas
  WalletProvider({required this.apiService});

  bool _isLoading = false;
  String? _error;
  MarketPrice? _prices;

  // Lista de direcciones/balances por red (Solana, Bitcoin, BNB)
  List<WalletInfo> _wallets = [];

  // Historial de transacciones recientes (maximo las ultimas N)
  List<Transaction> _recentTransactions = [];

  // Frase semilla BIP39 en texto plano (solo existe temporalmente durante creacion/importacion)
  String? _seedPhrase;

  // Frase semilla cifrada con AES-256 y almacenada en SecureStorage
  String? _encryptedSeed;

  // Direcciones publicas derivadas para cada red (formato BIP44)
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
  /// Itera sobre la lista de wallets (Solana + Bitcoin + BNB)
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
  /// La frase se genera localmente sin enviarla a ningun servidor
  /// Retorna la frase generada para mostrarla al usuario (debe copiarla)
  ///
  Future<String> generateWallet() async {
    _seedPhrase = BIP39Service.generateSeedPhrase(wordCount: 12);
    return _seedPhrase!;
  }

  ///
  /// Guarda la wallet recien creada:
  /// 1. Deriva direcciones BIP44 para cada red
  /// 2. Cifra la frase semilla con AES-256 usando la contrasena del usuario
  /// 3. Almacena la seed cifrada y las direcciones en SecureStorage
  /// 4. Actualiza flag walletCreada en Firestore para el usuario actual
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
      // Cada red usa un path de derivacion distinto (m/44'/501', m/44'/0', m/44'/714')
      _solanaAddress = await BIP44Derivation.deriveSolanaAddress(seedBytes);
      _bitcoinAddress = BIP44Derivation.deriveBitcoinAddress(seedBytes);
      _bnbAddress = BIP44Derivation.deriveBNBAddress(seedBytes);

      // Cifrar la frase semilla con AES-256 usando la contrasena del usuario
      // La seed nunca se almacena en texto plano, solo cifrada
      final encrypted = AESEncryption.encrypt(seedPhrase, password);
      await SecureStorage.saveEncryptedSeed(encrypted);
      _encryptedSeed = encrypted;

      // Guardar las direcciones derivadas en almacenamiento seguro
      // Esto evita tener que derivar de nuevo cada vez que se abre la app
      await SecureStorage.saveAddresses(
        solana: _solanaAddress!,
        bitcoin: _bitcoinAddress!,
        bnb: _bnbAddress!,
      );

      // Marcar en Firestore que este usuario ya creo su wallet
      await _updateWalletCreatedFlag(true);

      // Limpiar la frase semilla de la memoria por seguridad
      // Despues de guardarla cifrada, ya no necesitamos el texto plano en RAM
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
  /// Cada red se deriva con try/catch individual para aislar errores por red
  ///
  Future<bool> importWallet(String seedPhrase, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validar que la frase cumpla con el estandar BIP39 (checksum incluido)
      if (!BIP39Service.validateSeedPhrase(seedPhrase)) {
        _error = 'Frase semilla invalida';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Convertir frase mnemotecnica a bytes de semilla (512 bits)
      final seedBytes = BIP39Service.mnemonicToSeed(seedPhrase);

      // Derivar cada direccion por separado para manejar errores individualmente
      // Si una red falla, las otras redes no se ven afectadas
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

      // Cifrar la frase semilla con AES-256 y la contrasena del usuario
      String encrypted;
      try {
        encrypted = AESEncryption.encrypt(seedPhrase, password);
      } catch (e) {
        _error = 'Error al cifrar seed phrase: $e';
        _isLoading = false; notifyListeners(); return false;
      }
      // Almacenar la seed cifrada localmente (nunca en texto plano)
      await SecureStorage.saveEncryptedSeed(encrypted);
      _encryptedSeed = encrypted;

      // Guardar direcciones publicas para evitar derivacion repetida
      await SecureStorage.saveAddresses(
        solana: _solanaAddress!,
        bitcoin: _bitcoinAddress!,
        bnb: _bnbAddress!,
      );

      // Marcar wallet como creada en Firestore
      await _updateWalletCreatedFlag(true);

      // Eliminar la seed en texto plano de la memoria RAM
      _seedPhrase = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Capturar cualquier error inesperado durante el proceso completo
      _error = 'Error inesperado al importar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  ///
  /// Desbloquea la wallet con la contrasena de cifrado:
  /// 1. Descifra la frase semilla desde SecureStorage
  /// 2. Recupera las direcciones guardadas (mas rapido) o las deriva si no existen
  /// Si la contrasena es incorrecta, AES decryption lanza excepcion y retorna false
  ///
  Future<bool> unlockWallet(String password) async {
    try {
      // Obtener la seed cifrada desde SecureStorage
      final encrypted = await SecureStorage.getEncryptedSeed();
      if (encrypted == null) return false;

      // Descifrar la frase semilla con AES-256
      // Si la contrasena es incorrecta, aqui se lanza una excepcion
      final decrypted = AESEncryption.decrypt(encrypted, password);
      // Convertir la frase mnemotecnica descifrada a bytes de semilla
      final seedBytes = BIP39Service.mnemonicToSeed(decrypted);

      // Recuperar direcciones desde almacenamiento seguro (cache)
      // Esto es mas rapido que derivar de nuevo desde la seed
      final addresses = await SecureStorage.getAddresses();
      if (addresses != null) {
        _solanaAddress = addresses['solana'];
        _bitcoinAddress = addresses['bitcoin'];
        _bnbAddress = addresses['bnb'];
      } else {
        // Si no hay direcciones guardadas (migracion o datos corruptos), derivar de nuevo
        _solanaAddress = await BIP44Derivation.deriveSolanaAddress(seedBytes);
        _bitcoinAddress = BIP44Derivation.deriveBitcoinAddress(seedBytes);
        _bnbAddress = BIP44Derivation.deriveBNBAddress(seedBytes);
      }

      _encryptedSeed = encrypted;
      _seedPhrase = null;
      return true;
    } catch (e) {
      // Contrasena incorrecta o datos corruptos
      return false;
    }
  }

  ///
  /// Obtiene los balances de las 3 redes en paralelo usando las direcciones derivadas
  /// Primero consulta los precios de CoinGecko, luego los balances de cada red
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
    // Necesitamos los precios para calcular balanceUsd de cada wallet
    await fetchPrices();

    // Consultar balance de cada red en paralelo
    // Future.wait ejecuta las 3 consultas simultaneamente para minimizar el tiempo de carga
    final results = await Future.wait([
      _fetchSingleBalance('solana', _solanaAddress!),
      _fetchSingleBalance('bitcoin', _bitcoinAddress!),
      _fetchSingleBalance('bnb', _bnbAddress!),
    ]);

    // Filtrar solo resultados exitosos (dondeType elimina los null) y actualizar la lista
    _wallets = results.whereType<WalletInfo>().toList();

    _isLoading = false;
    notifyListeners();
  }

  ///
  /// Consulta el balance de una red especifica y construye un WalletInfo
  /// Si la consulta falla, retorna un WalletInfo con balance 0 pero el precio actual
  /// Esto permite mostrar la wallet aunque la red no responda a tiempo
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
  /// Retorna el simbolo de ticker correspondiente a cada red
  /// SOL para Solana, BTC para Bitcoin, BNB para Binance Smart Chain
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
  /// Si _prices es null (aun no se cargaron), retorna 0 como valor por defecto
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
  /// 2. Construye y firma la transaccion localmente (la clave privada nunca sale del dispositivo)
  /// 3. Retransmite la transaccion firmada a traves del backend
  /// La contrasena de cifrado es necesaria para descifrar la seed y derivar la clave privada
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
      // Obtener la direccion origen de la red solicitada
      final fromAddress = _getAddressForNetwork(network);
      if (fromAddress == null) throw Exception('Direccion no encontrada para $network');

      // 1. Preparar transaccion (obtener datos de la red)
      // El backend proporciona blockhash, nonce, UTXOs, gas, etc segun la red
      final prepared = await apiService.prepareTransaction(
        network: network,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: amount,
      );
      final prepData = prepared['preparation_data'] as Map<String, dynamic>;

      // 2. Firmar la transaccion localmente
      // Cada red tiene un proceso de firma distinto:
      String signedTx;
      if (network == 'bnb') {
        // BNB: firma EIP-155 (eth-style) con nonce, gasLimit, gasPrice y chainId
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
        // Solana: firma ed25519 con recentBlockhash para evitar replay attacks
        final privateKey = await getPrivateKey(network, password);
        signedTx = await TransactionBuilder.buildAndSignSolana(
          privateKey: privateKey,
          fromAddress: fromAddress,
          toAddress: toAddress,
          amount: amount,
          recentBlockhash: prepData['recent_blockhash'] as String,
        );
      } else if (network == 'bitcoin') {
        // Bitcoin: firma ECDSA con seleccion de UTXOs y calculo de cambio (change)
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

      // 3. Retransmitir la transaccion firmada a traves del backend
      // El backend se encarga de enviarla a la red blockchain correspondiente
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
  /// Detecta la red segun el prefijo o longitud de la direccion:
  /// - '0x' -> BNB (Ethereum-compatible)
  /// - '1', '3', 'bc1' -> Bitcoin (P2PKH, P2SH, Bech32)
  /// - Longitud > 30 -> Solana (base58, ~44 caracteres)
  ///
  String? networkForAddress(String address) {
    if (address.startsWith('0x')) return 'bnb';
    if (address.startsWith('1') || address.startsWith('3') || address.startsWith('bc1')) return 'bitcoin';
    if (address.length > 30) return 'solana';
    return null;
  }

  ///
  /// Limpia todos los datos de la wallet (para logout o restablecimiento)
  /// Elimina datos en memoria (balances, precios, historial, direcciones, seed)
  /// y tambien los almacenados en SecureStorage (seed cifrada, direcciones, PIN, etc.)
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
