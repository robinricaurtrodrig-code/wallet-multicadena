/// Modelos para activos individuales y precios de mercado.
/// AssetBalance representa el balance de un token en una red (mantenido por compatibilidad).
/// MarketPrice contiene los precios actualizados de SOL, BTC y BNB desde CoinGecko.
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

  /// Construye un AssetBalance desde la respuesta JSON del backend.
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

  /// Convierte AssetBalance a WalletInfo para mantener consistencia en la interfaz.
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

  /// Retorna el balance formateado con decimales adaptativos segun la magnitud.
  /// Muestra 4 decimales para valores >= 1, 6 para >= 0.001 y 8 para menores.
  String get formattedBalance {
    if (balance >= 1) return balance.toStringAsFixed(4);
    if (balance >= 0.001) return balance.toStringAsFixed(6);
    return balance.toStringAsFixed(8);
  }

  /// Retorna el valor en USD formateado como moneda.
  /// Muestra 2 decimales para valores >= $1 y 4 para menores.
  String get formattedUsd {
    if (balanceUsd >= 1) return '\$${balanceUsd.toStringAsFixed(2)}';
    return '\$${balanceUsd.toStringAsFixed(4)}';
  }

  /// Ruta del icono del token segun su simbolo.
  String get iconPath {
    switch (symbol.toLowerCase()) {
      case 'sol': return 'assets/icons/solana.svg';
      case 'btc': return 'assets/icons/bitcoin.svg';
      case 'bnb': return 'assets/icons/bnb.svg';
      default: return 'assets/icons/crypto.svg';
    }
  }
}

/// Modelo de precios de mercado para SOL, BTC y BNB.
/// Los precios se obtienen desde CoinGecko a traves del backend.
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

  /// Construye MarketPrice desde la respuesta JSON del backend.
  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      solana: (json['solana'] ?? 0).toDouble(),
      bitcoin: (json['bitcoin'] ?? 0).toDouble(),
      bnb: (json['bnb'] ?? 0).toDouble(),
      lastUpdated: json['last_updated'] ?? '',
    );
  }
}
