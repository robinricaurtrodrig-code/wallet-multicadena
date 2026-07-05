import 'wallet.dart';

/// Modelo de balance de activo individual.
/// NOTA: Esta clase es mantenida por compatibilidad, pero WalletInfo en wallet.dart
/// es el modelo principal para representar balances de criptomonedas.
class AssetBalance {
  final String network;
  final String symbol;
  final double balance;
  final double balanceUsd;
  final double usdPrice;
  final String? address;

  AssetBalance({
    required this.network,
    required this.symbol,
    required this.balance,
    required this.balanceUsd,
    required this.usdPrice,
    this.address,
  });

  factory AssetBalance.fromJson(Map<String, dynamic> json) {
    return AssetBalance(
      network: json['network'] ?? '',
      symbol: json['symbol'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      balanceUsd: (json['balance_usd'] ?? 0).toDouble(),
      usdPrice: (json['usd_price'] ?? 0).toDouble(),
      address: json['address'],
    );
  }

  /// Convierte AssetBalance a WalletInfo para mantener consistencia
  WalletInfo toWalletInfo() {
    return WalletInfo(
      address: address ?? '',
      network: network,
      symbol: symbol,
      balance: balance,
      balanceUsd: balanceUsd,
      usdPrice: usdPrice,
    );
  }

  String get formattedBalance {
    if (balance >= 1) return balance.toStringAsFixed(4);
    if (balance >= 0.001) return balance.toStringAsFixed(6);
    return balance.toStringAsFixed(8);
  }

  String get formattedUsd {
    if (balanceUsd >= 1) return '\$${balanceUsd.toStringAsFixed(2)}';
    return '\$${balanceUsd.toStringAsFixed(4)}';
  }

  String get iconPath {
    switch (symbol.toLowerCase()) {
      case 'sol': return 'assets/icons/solana.svg';
      case 'btc': return 'assets/icons/bitcoin.svg';
      case 'bnb': return 'assets/icons/bnb.svg';
      default: return 'assets/icons/crypto.svg';
    }
  }
}

/// Modelo de precios de mercado para SOL, BTC y BNB
class MarketPrice {
  final double solana;
  final double bitcoin;
  final double bnb;
  final String lastUpdated;

  MarketPrice({
    required this.solana,
    required this.bitcoin,
    required this.bnb,
    required this.lastUpdated,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      solana: (json['solana'] ?? 0).toDouble(),
      bitcoin: (json['bitcoin'] ?? 0).toDouble(),
      bnb: (json['bnb'] ?? 0).toDouble(),
      lastUpdated: json['last_updated'] ?? '',
    );
  }
}
