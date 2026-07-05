import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedNetwork = 'solana';
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({String? network}) async {
    final wallet = context.read<WalletProvider>();
    final net = network ?? _selectedNetwork;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final address = _getAddressForNetwork(net, wallet);
      if (address == null) {
        setState(() {
          _transactions = [];
          _isLoading = false;
        });
        return;
      }
      final api = ApiService();
      final txs = await api.getHistory(address, net);
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar historial: $e';
        _isLoading = false;
      });
    }
  }

  String? _getAddressForNetwork(String network, WalletProvider wallet) {
    switch (network) {
      case 'solana': return wallet.solanaAddress;
      case 'bitcoin': return wallet.bitcoinAddress;
      case 'bnb': return wallet.bnbAddress;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de transacciones'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _networkChip('Solana', 'solana'),
                const SizedBox(width: 8),
                _networkChip('Bitcoin', 'bitcoin'),
                const SizedBox(width: 8),
                _networkChip('BNB Chain', 'bnb'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _networkChip(String label, String network) {
    final selected = _selectedNetwork == network;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedNetwork = network);
        _loadHistory(network: network);
      },
      selectedColor: _colorForNetwork(network).withOpacity(0.2),
      checkmarkColor: _colorForNetwork(network),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadHistory(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textDarkSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No hay transacciones en ${_networkName(_selectedNetwork)}',
              style: TextStyle(color: AppTheme.textDarkSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Las transacciones apareceran aqui cuando envies o recibas fondos',
              style: TextStyle(color: AppTheme.textDarkSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (_, i) => _buildTransactionItem(_transactions[i]),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final isSent = tx.type == 'sent';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isSent ? AppTheme.error : AppTheme.success).withOpacity(0.15),
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
              'Hash: ${tx.txHash.length > 20 ? "${tx.txHash.substring(0, 20)}..." : tx.txHash}',
              style: const TextStyle(fontSize: 12),
            ),
            if (tx.fee > 0)
              Text(
                'Comision: ${tx.fee.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
            if (tx.timestamp != null)
              Text(
                _formatDate(tx.timestamp!),
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
        trailing: _statusChip(tx.status),
      ),
    );
  }

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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _networkName(String network) {
    switch (network) {
      case 'solana': return 'Solana';
      case 'bitcoin': return 'Bitcoin';
      case 'bnb': return 'BNB Chain';
      default: return network;
    }
  }

  Color _colorForNetwork(String network) {
    switch (network) {
      case 'solana': return const Color(0xFF9945FF);
      case 'bitcoin': return const Color(0xFFF7931A);
      case 'bnb': return const Color(0xFFF0B90B);
      default: return AppTheme.primary;
    }
  }
}
