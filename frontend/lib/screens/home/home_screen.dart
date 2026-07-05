import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/security_provider.dart';
import '../../config/theme.dart';
import '../../models/wallet.dart';
import '../wallet/create_wallet_screen.dart';
import '../wallet/import_wallet_screen.dart';
import '../wallet/asset_detail_screen.dart';
import '../wallet/send_screen.dart';
import '../wallet/receive_screen.dart';
import '../security/security_settings_screen.dart';
import '../dapp/sign_message_screen.dart';
import '../dapp/dapp_browser_screen.dart';
import '../history/history_screen.dart';

///
/// HomeScreen: Pantalla principal de Wallet Multicadena
/// Muestra el balance total, lista de activos (SOL, BTC, BNB) y navegacion inferior
/// Si no hay wallet creada, muestra pantalla de bienvenida con opciones Crear/Importar
///
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Registrar actividad para el timer de auto-logout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SecurityProvider>().recordActivity();

      // Verificar si existe wallet local y cargar datos
      final wallet = context.read<WalletProvider>();
      wallet.checkExistingWallet().then((hasWallet) {
        if (hasWallet) {
          wallet.fetchAllBalances();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Multicadena'),
        actions: [
          // Icono de seguridad: muestra codigo anti-phishing si esta configurado
          Consumer<SecurityProvider>(
            builder: (_, sec, __) {
              if (!sec.hasAntiPhishing) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(
                  avatar: const Icon(Icons.verified, size: 16, color: AppTheme.success),
                  label: Text(sec.antiPhishingCode!, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'DApps',
            onPressed: () {
              context.read<SecurityProvider>().recordActivity();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DAppBrowserScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Seguridad',
            onPressed: () {
              context.read<SecurityProvider>().recordActivity();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => context.read<SecurityProvider>().recordActivity(),
        onPanDown: (_) => context.read<SecurityProvider>().recordActivity(),
        child: _buildBody(wallet, auth),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => _onTabSelected(i, wallet),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Enviar'),
          NavigationDestination(icon: Icon(Icons.qr_code), label: 'Recibir'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }

  /// Navega a la pantalla segun la pestana seleccionada (Enviar, Recibir, etc.)
  void _onTabSelected(int index, WalletProvider wallet) {
    if (!wallet.hasWallet && wallet.wallets.isEmpty) return;

    switch (index) {
      case 0:
        setState(() => _currentIndex = 0);
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SendScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReceiveScreen()),
        );
        break;
      case 3:
        context.read<SecurityProvider>().recordActivity();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
      case 4:
        context.read<SecurityProvider>().recordActivity();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
        );
        break;
    }
  }

  ///
  /// Construye el cuerpo de la pantalla segun la pestana seleccionada
  /// Si no hay wallet creada, muestra pantalla de bienvenida
  ///
  Widget _buildBody(WalletProvider wallet, AuthProvider auth) {
    // Si no tiene wallet y no hay datos cargados, mostrar bienvenida
    if (!wallet.hasWallet && wallet.wallets.isEmpty) {
      return _buildNoWalletScreen(wallet);
    }

    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(wallet);
      default:
        return _buildHomeTab(wallet);
    }
  }

  ///
  /// Pantalla de bienvenida cuando el usuario no tiene wallet creada
  /// Ofrece dos opciones: Crear nueva wallet o Importar existente
  ///
  Widget _buildNoWalletScreen(WalletProvider wallet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 80, color: AppTheme.primary),
            const SizedBox(height: 24),
            Text(
              'Bienvenido a Wallet Multicadena',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu wallet descentralizada para Solana, Bitcoin y BNB Chain',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateWalletScreen()),
                  );
                },
                child: const Text('Crear nueva wallet'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
                );
              },
              child: const Text('Importar wallet existente'),
            ),
          ],
        ),
      ),
    );
  }

  ///
  /// Pestana de inicio: muestra el balance total y la lista de activos
  /// Soporta pull-to-refresh para recargar balances desde la blockchain
  ///
  Widget _buildHomeTab(WalletProvider wallet) {
    return RefreshIndicator(
      onRefresh: () async {
        await wallet.fetchAllBalances();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Indicador de carga solo si esta cargando y no hay datos previos
          if (wallet.isLoading && wallet.wallets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Mensaje de error si existe
          if (wallet.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                wallet.error!,
                style: const TextStyle(color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // Tarjeta de balance total en USD
          _BalanceCard(
            totalUsd: wallet.totalUsd,
            isLoading: wallet.isLoading,
            onSend: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SendScreen()),
            ),
            onReceive: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiveScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // Seccion de activos con titulo
          Text(
            'Tus activos',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Boton para firmar mensajes (DApps)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<SecurityProvider>().recordActivity();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignMessageScreen()),
                  );
                },
                icon: const Icon(Icons.draw),
                label: const Text('Firmar Mensaje para DApps'),
              ),
            ),
          ),

          // Lista de activos por red (SOL, BTC, BNB)
          // Si hay datos cargados, mostrar con valores reales
          // Si no, mostrar placeholders mientras se cargan
          if (wallet.wallets.isNotEmpty)
            ...wallet.wallets.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AssetCard(
                walletInfo: w,
                price: _priceFor(w.network, wallet),
                onTap: () => _openAssetDetail(w, wallet),
              ),
            ))
          else ...[
            _AssetCardPlaceholder(symbol: 'SOL', name: 'Solana'),
            const SizedBox(height: 12),
            _AssetCardPlaceholder(symbol: 'BTC', name: 'Bitcoin'),
            const SizedBox(height: 12),
            _AssetCardPlaceholder(symbol: 'BNB', name: 'BNB Chain'),
          ],
        ],
      ),
    );
  }

  ///
  /// Retorna el precio USD del activo segun su red desde los precios cacheados
  ///
  double _priceFor(String network, WalletProvider wallet) {
    if (wallet.prices == null) return 0;
    switch (network) {
      case 'solana': return wallet.prices!.solana;
      case 'bitcoin': return wallet.prices!.bitcoin;
      case 'bnb': return wallet.prices!.bnb;
      default: return 0;
    }
  }

  ///
  /// Navega a la pantalla de detalle del activo seleccionado
  ///
  void _openAssetDetail(WalletInfo walletInfo, WalletProvider wallet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          walletInfo: walletInfo,
          price: _priceFor(walletInfo.network, wallet),
        ),
      ),
    );
  }

}

///
/// _BalanceCard: Tarjeta que muestra el balance total en USD
/// Incluye el monto total y botones de accion rapida (Enviar/Recibir)
///
class _BalanceCard extends StatelessWidget {
  final double totalUsd;
  final bool isLoading;
  final VoidCallback? onSend;
  final VoidCallback? onReceive;

  const _BalanceCard({
    required this.totalUsd,
    this.isLoading = false,
    this.onSend,
    this.onReceive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Balance Total', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '\$${totalUsd.toStringAsFixed(2)}',
                      key: ValueKey(totalUsd),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 40),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(icon: Icons.arrow_upward, label: 'Enviar', onTap: onSend),
                const SizedBox(width: 24),
                _ActionButton(icon: Icons.arrow_downward, label: 'Recibir', onTap: onReceive),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

///
/// _ActionButton: Boton circular con icono para accion rapida (Enviar/Recibir)
///
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

///
/// _AssetCard: Tarjeta individual para cada activo (SOL, BTC, BNB)
/// Muestra icono, balance, simbolo, valor USD y precio unitario
/// Al hacer tap navega al detalle del activo
///
class _AssetCard extends StatelessWidget {
  final WalletInfo walletInfo;
  final double price;
  final VoidCallback? onTap;

  const _AssetCard({
    required this.walletInfo,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colorForNetwork(walletInfo.network).withOpacity(0.15),
          child: Text(
            walletInfo.symbol[0],
            style: TextStyle(
              color: _colorForNetwork(walletInfo.network),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${walletInfo.balance.toStringAsFixed(6)} ${walletInfo.symbol}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(walletInfo.network),
            if (price > 0)
              Text(
                '\$${price.toStringAsFixed(2)} USD',
                style: TextStyle(fontSize: 12, color: AppTheme.textDarkSecondary),
              ),
          ],
        ),
        trailing: Text(
          '\$${walletInfo.balanceUsd.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        onTap: onTap,
      ),
    );
  }

  ///
  /// Retorna un color distintivo para cada red blockchain
  ///
  Color _colorForNetwork(String network) {
    switch (network) {
      case 'solana': return const Color(0xFF9945FF);
      case 'bitcoin': return const Color(0xFFF7931A);
      case 'bnb': return const Color(0xFFF0B90B);
      default: return AppTheme.primary;
    }
  }
}

///
/// _AssetCardPlaceholder: Tarjeta de carga mientras no hay datos de balance
/// Muestra balance en cero con estilo de espera
///
class _AssetCardPlaceholder extends StatelessWidget {
  final String symbol;
  final String name;

  const _AssetCardPlaceholder({required this.symbol, required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.15),
          child: Text(symbol[0], style: const TextStyle(color: AppTheme.primary)),
        ),
        title: Text('0.000000 $symbol'),
        subtitle: Text(name),
        trailing: const Text(
          '\$0.00',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
