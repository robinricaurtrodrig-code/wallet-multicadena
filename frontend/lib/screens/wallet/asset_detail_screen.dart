import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

///
/// AssetDetailScreen: Pantalla de detalle para un activo especifico (SOL, BTC o BNB)
/// Muestra informacion detallada del balance, precio, red y acciones disponibles
/// Tambien carga y muestra las ultimas transacciones de esa red
///
class AssetDetailScreen extends StatefulWidget {
  final WalletInfo walletInfo;
  final double price;

  const AssetDetailScreen({
    super.key,
    required this.walletInfo,
    required this.price,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar el historial de transacciones al abrir el detalle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchHistory(widget.walletInfo.network);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final info = widget.walletInfo;

    return Scaffold(
      appBar: AppBar(
        title: Text('${info.symbol} - ${_networkName(info.network)}'),
        actions: [
          // Boton para abrir en el explorador de bloques
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () {
              // TODO: Abrir URL del explorador de bloques
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seccion del balance principal del activo
            _buildBalanceSection(info),
            const SizedBox(height: 32),

            // Acciones rapidas: Enviar, Recibir, Comprar
            _buildActionButtons(info),
            const SizedBox(height: 32),

            // Informacion detallada del activo
            _buildInfoSection(info),
            const SizedBox(height: 32),

            // Ultimas transacciones de esta red
            Text(
              'Ultimas transacciones',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),

            if (wallet.recentTransactions.isEmpty)
              _buildEmptyTransactions()
            else
              ...wallet.recentTransactions.map((tx) => _buildTransactionItem(tx)),
          ],
        ),
      ),
    );
  }

  ///
  /// Construye la seccion principal del balance con icono grande, monto y valor USD
  ///
  Widget _buildBalanceSection(WalletInfo info) {
    return Center(
      child: Column(
        children: [
          // Icono grande del activo con color de red
          CircleAvatar(
            radius: 36,
            backgroundColor: _colorForNetwork(info.network).withValues(alpha: 0.15),
            child: Text(
              info.symbol[0],
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _colorForNetwork(info.network),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Balance del activo
          Text(
            '${info.balance.toStringAsFixed(6)} ${info.symbol}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 4),

          // Valor en USD
          Text(
            '\$${info.balanceUsd.toStringAsFixed(2)} USD',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),

          // Precio unitario
          if (widget.price > 0)
            Text(
              '1 ${info.symbol} = \$${widget.price.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 14, color: AppTheme.textDarkSecondary),
            ),
        ],
      ),
    );
  }

  ///
  /// Construye los botones de accion rapida para el activo
  ///
  Widget _buildActionButtons(WalletInfo info) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionChip(icon: Icons.arrow_upward, label: 'Enviar', onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SendScreen(walletInfo: info),
          ));
        }),
        _ActionChip(icon: Icons.arrow_downward, label: 'Recibir', onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReceiveScreen(initialNetwork: info.network),
          ));
        }),
        _ActionChip(icon: Icons.shopping_cart, label: 'Comprar', onTap: () {
          // TODO: Abrir enlace de compra (MoonPay, etc.)
        }),
      ],
    );
  }

  ///
  /// Construye la seccion de informacion detallada del activo
  /// Muestra red, direccion publica y precio USD
  ///
  Widget _buildInfoSection(WalletInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informacion del activo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _infoRow('Red', _networkName(info.network)),
            const Divider(height: 24),
            _infoRow('Direccion', info.address.isNotEmpty ? '${info.address.substring(0, 12)}...' : 'No disponible'),
            const Divider(height: 24),
            _infoRow('Precio USD', '\$${widget.price.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _infoRow('Balance USD', '\$${info.balanceUsd.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  ///
  /// Fila de informacion con label y valor para la seccion de detalles
  ///
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textDarkSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  ///
  /// Muestra un mensaje cuando no hay transacciones en el historial
  ///
  Widget _buildEmptyTransactions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: AppTheme.textDarkSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'Aun no hay transacciones',
                style: TextStyle(color: AppTheme.textDarkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ///
  /// Construye un elemento individual del historial de transacciones
  /// Muestra hash, tipo (enviado/recibido), monto, comision y estado
  ///
  Widget _buildTransactionItem(Transaction tx) {
    final isSent = tx.type == 'sent';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isSent ? AppTheme.error : AppTheme.success).withValues(alpha: 0.15),
          child: Icon(
            isSent ? Icons.arrow_upward : Icons.arrow_downward,
            color: isSent ? AppTheme.error : AppTheme.success,
            size: 20,
          ),
        ),
        title: Text(
          '${isSent ? "Enviado" : "Recibido"} ${tx.amount.toStringAsFixed(6)}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hash: ${tx.txHash.length > 16 ? "${tx.txHash.substring(0, 16)}..." : tx.txHash}',
              style: const TextStyle(fontSize: 12),
            ),
            if (tx.fee > 0)
              Text(
                'Comision: ${tx.fee.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: _statusChip(tx.status),
      ),
    );
  }

  ///
  /// Chip de estado coloreado segun el estado de la transaccion
  ///
  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmada':
        color = AppTheme.success;
      case 'pendiente':
        color = AppTheme.warning;
      case 'fallida':
        color = AppTheme.error;
      default:
        color = AppTheme.textDarkSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  ///
  /// Retorna el nombre legible de la red blockchain
  ///
  String _networkName(String network) {
    switch (network) {
      case 'solana': return 'Solana';
      case 'bitcoin': return 'Bitcoin';
      case 'bnb': return 'BNB Chain';
      default: return network;
    }
  }

  ///
  /// Retorna el color distintivo de cada red
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
/// _ActionChip: Widget de boton de accion con icono y label
/// Usado para Enviar, Recibir y Comprar en la pantalla de detalle
///
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
