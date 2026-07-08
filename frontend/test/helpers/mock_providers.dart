import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:wallet_multicadena/controllers/auth_provider.dart';
import 'package:wallet_multicadena/controllers/wallet_provider.dart';
import 'package:wallet_multicadena/controllers/security_provider.dart';
import 'package:wallet_multicadena/models/wallet.dart';
import 'package:wallet_multicadena/models/asset.dart';
import 'package:wallet_multicadena/models/user.dart';

class MockAuth extends ChangeNotifier implements AuthProvider {
  AuthStatus _status = AuthStatus.unauthenticated;
  UserModel? _user;
  String? _error;

  @override
  AuthStatus get status => _status;
  @override
  UserModel? get user => _user;
  @override
  String? get error => _error;
  @override
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  set status(AuthStatus v) { _status = v; notifyListeners(); }
  set user(UserModel? v) { _user = v; notifyListeners(); }
  set error(String? v) { _error = v; notifyListeners(); }

  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> register(String email, String password, String username) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<String> getIdToken() async => 'mock-token';
  @override
  void clearError() { _error = null; notifyListeners(); }
}

class MockWallet extends ChangeNotifier implements WalletProvider {
  bool _isLoading = false;
  String? _error;
  List<WalletInfo> _wallets = [];
  bool _hasWallet = false;
  String? _solanaAddress;
  String? _bitcoinAddress;
  String? _bnbAddress;
  MarketPrice? _prices;
  List<Transaction> _recentTransactions = [];
  String? _seedPhrase;

  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  @override
  List<WalletInfo> get wallets => _wallets;
  @override
  double get totalUsd => _wallets.fold(0, (s, w) => s + w.balanceUsd);
  @override
  bool get hasWallet => _hasWallet;
  @override
  String? get solanaAddress => _solanaAddress;
  @override
  String? get bitcoinAddress => _bitcoinAddress;
  @override
  String? get bnbAddress => _bnbAddress;
  @override
  MarketPrice? get prices => _prices;
  @override
  List<Transaction> get recentTransactions => _recentTransactions;
  @override
  String? get seedPhrase => _seedPhrase;

  set isLoading(bool v) { _isLoading = v; notifyListeners(); }
  set error(String? v) { _error = v; notifyListeners(); }
  set wallets(List<WalletInfo> v) { _wallets = v; notifyListeners(); }
  set hasWallet(bool v) { _hasWallet = v; notifyListeners(); }
  set solanaAddress(String? v) { _solanaAddress = v; notifyListeners(); }

  @override
  Future<String> generateWallet() async { _seedPhrase = 'mock seed phrase'; return _seedPhrase!; }
  @override
  Future<void> saveWallet(String seedPhrase, String password) async {}
  @override
  Future<bool> importWallet(String seedPhrase, String password) async => true;
  @override
  Future<bool> unlockWallet(String password) async => true;
  @override
  Future<void> fetchAllBalances() async {}
  @override
  Future<void> fetchPrices() async {}
  @override
  Future<void> fetchHistory(String network) async {}
  @override
  Future<bool> checkExistingWallet() async => _hasWallet;
  @override
  Future<void> clearWallet() async { _wallets = []; _hasWallet = false; notifyListeners(); }
  @override
  String? networkForAddress(String address) {
    if (address.startsWith('0x')) return 'bnb';
    if (address.startsWith('1')) return 'bitcoin';
    return 'solana';
  }
  @override
  Future<Uint8List> getPrivateKey(String network, String password) async => Uint8List(0);
  @override
  Future<bip32.BIP32> getBitcoinKey(String password) async => throw UnimplementedError();
  @override
  Future<Transaction> sendTransaction({required String network, required String toAddress, required double amount, required String password}) async => throw UnimplementedError();
}

class MockSecurity extends ChangeNotifier implements SecurityProvider {
  bool _isLocked = false;
  bool _biometricAvailable = false;
  int _lastActivity = 0;
  String? _antiPhishingCode;

  @override
  bool get isLocked => _isLocked;
  @override
  bool get biometricAvailable => _biometricAvailable;
  @override
  int get lastActivity => _lastActivity;
  @override
  String? get antiPhishingCode => _antiPhishingCode;
  @override
  bool get hasAntiPhishing => _antiPhishingCode != null && _antiPhishingCode!.isNotEmpty;

  set isLocked(bool v) { _isLocked = v; notifyListeners(); }
  set antiPhishingCode(String? v) { _antiPhishingCode = v; notifyListeners(); }

  @override
  void recordActivity() { _lastActivity = DateTime.now().millisecondsSinceEpoch; notifyListeners(); }
  @override
  void lock() { _isLocked = true; notifyListeners(); }
  @override
  Future<bool> unlockWithPin(String pin) async { _isLocked = false; notifyListeners(); return true; }
  @override
  Future<bool> unlockWithBiometrics() async { _isLocked = false; notifyListeners(); return true; }
  @override
  Future<void> setAntiPhishingCode(String code) async { _antiPhishingCode = code; notifyListeners(); }
  @override
  Future<void> setAutoLogoutMinutes(int minutes) async {}
}
