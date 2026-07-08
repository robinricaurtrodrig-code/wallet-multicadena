/// Modelo que representa la informacion de una wallet en una red especifica
class WalletInfo {
  final String address;   // Direccion publica de la wallet en la red
  final String network;   // Nombre de la red (solana, bitcoin, bnb)
  final String symbol;    // Simbolo del token nativo (SOL, BTC, BNB)
  final double balance;   // Balance del token nativo
  final double balanceUsd; // Balance convertido a USD
  final double usdPrice;   // Precio unitario del token en USD

  WalletInfo({
    required this.address,
    required this.network,
    required this.symbol,
    this.balance = 0,
    this.balanceUsd = 0,
    this.usdPrice = 0,
  });

  /// Construye un WalletInfo desde la respuesta JSON del backend
  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      address: json['address'] ?? '',
      network: json['network'] ?? '',
      symbol: json['symbol'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      balanceUsd: (json['balance_usd'] ?? 0).toDouble(),
      usdPrice: (json['usd_price'] ?? 0).toDouble(),
    );
  }
}

/// Modelo que agrupa los datos de todas las wallets del usuario
class WalletData {
  final List<WalletInfo> wallets; // Lista de wallets (una por red)
  final double totalUsd;          // Suma total de todos los balances en USD

  WalletData({required this.wallets, required this.totalUsd});

  /// Construye WalletData desde la respuesta JSON del backend
  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      wallets: (json['balances'] as List)
          .map((e) => WalletInfo.fromJson(e))
          .toList(),
      totalUsd: (json['total_usd'] ?? 0).toDouble(),
    );
  }
}

/// Modelo que representa una transaccion en la blockchain
class Transaction {
  final String txHash;
  final String network;
  final String type;
  final double amount;
  final double fee;
  final String status;
  final String explorerUrl;
  final DateTime? timestamp;
  final String fromAddress;
  final String toAddress;
  final int blockNumber;
  final int slot;

  Transaction({
    required this.txHash,
    required this.network,
    required this.type,
    required this.amount,
    this.fee = 0,
    this.status = 'pendiente',
    required this.explorerUrl,
    this.timestamp,
    this.fromAddress = '',
    this.toAddress = '',
    this.blockNumber = 0,
    this.slot = 0,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txHash: json['tx_hash'] ?? '',
      network: json['network'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      fee: (json['fee'] ?? 0).toDouble(),
      status: json['status'] ?? 'pendiente',
      explorerUrl: json['explorer_url'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
      fromAddress: json['from_address'] ?? '',
      toAddress: json['to_address'] ?? '',
      blockNumber: (json['block_number'] ?? 0),
      slot: (json['slot'] ?? 0),
    );
  }
}
