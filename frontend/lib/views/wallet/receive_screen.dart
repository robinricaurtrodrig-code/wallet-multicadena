import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../controllers/wallet_provider.dart';

/// ReceiveScreen: Pantalla para recibir criptomonedas
/// Muestra la direccion publica de cada red con codigo QR para compartir
class ReceiveScreen extends StatefulWidget {
  final String? initialNetwork; // Red preseleccionada si viene de AssetDetailScreen

  const ReceiveScreen({super.key, this.initialNetwork});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _selectedNetwork = 'solana';

  @override
  void initState() {
    super.initState();
    if (widget.initialNetwork != null) {
      _selectedNetwork = widget.initialNetwork!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recibir'),
          bottom: TabBar(
            onTap: (i) {
              setState(() {
                _selectedNetwork = ['solana', 'bitcoin', 'bnb'][i];
              });
            },
            tabs: const [
              Tab(text: 'Solana'),
              Tab(text: 'Bitcoin'),
              Tab(text: 'BNB Chain'),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textDarkSecondary,
          ),
        ),
        body: _buildNetworkTab(wallet),
      ),
    );
  }

  /// Construye la vista para la red seleccionada: QR + direccion + advertencia
  Widget _buildNetworkTab(WalletProvider wallet) {
    final address = _getAddress(wallet);
    final symbol = _symbolForNetwork(_selectedNetwork);
    final color = _colorForNetwork(_selectedNetwork);

    if (address == null || address.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.warning),
            const SizedBox(height: 16),
            const Text('Direccion no disponible para esta red'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Recibir $symbol',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Escanea el codigo QR o copia la direccion',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Codigo QR con la direccion publica
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: address,
              version: QrVersions.auto,
              size: 240,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: color,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Direccion publica con boton de copiar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu direccion $symbol',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDarkSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.primary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Direccion copiada'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Advertencia de seguridad: solo enviar tokens de esta red
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Solo envia $symbol a esta direccion. Enviar otros tokens puede resultar en perdida de fondos.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareAddress(context, address),
              icon: const Icon(Icons.share),
              label: const Text('Compartir direccion'),
            ),
          ),
        ],
      ),
    );
  }

  /// Obtiene la direccion de la red seleccionada desde WalletProvider
  String? _getAddress(WalletProvider wallet) {
    switch (_selectedNetwork) {
      case 'solana': return wallet.solanaAddress;
      case 'bitcoin': return wallet.bitcoinAddress;
      case 'bnb': return wallet.bnbAddress;
      default: return null;
    }
  }

  /// Copia la direccion al portapapeles para compartir
  void _shareAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Direccion copiada al portapapeles')),
    );
  }

  /// Retorna el simbolo del token segun la red
  String _symbolForNetwork(String network) {
    switch (network) {
      case 'solana': return 'SOL';
      case 'bitcoin': return 'BTC';
      case 'bnb': return 'BNB';
      default: return '';
    }
  }

  /// Retorna el color distintivo de cada red
  Color _colorForNetwork(String network) {
    switch (network) {
      case 'solana': return const Color(0xFF9945FF);
      case 'bitcoin': return const Color(0xFFF7931A);
      case 'bnb': return const Color(0xFFF0B90B);
      default: return AppTheme.primary;
    }
  }
}
