import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
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
  bool _isLoadingMore = false;
  String? _error;
  int _loadId = 0;
  int _page = 0;
  bool _hasMore = true;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _api = context.read<AuthProvider>().apiService;
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadHistory({String? network}) async {
    final net = network ?? _selectedNetwork;

    final currentLoadId = ++_loadId;
    _page = 0;
    _hasMore = true;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _transactions = [];
    });

    await _fetchTransactions(net, currentLoadId, 0);
  }

  Future<void> _loadMore() async {
    final currentLoadId = _loadId;

    if (!mounted) return;
    setState(() => _isLoadingMore = true);

    await _fetchTransactions(_selectedNetwork, currentLoadId, _page + 1);
  }

  Future<void> _fetchTransactions(String net, int loadId, int page) async {
    if (_api == null) {
      if (mounted && loadId == _loadId) {
        setState(() {
          _error = 'Servicio de API no disponible';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      return;
    }

    final wallet = context.read<WalletProvider>();
    final address = _getAddressForNetwork(net, wallet);

    if (address == null) {
      if (mounted && loadId == _loadId) {
        setState(() {
          _transactions = [];
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      return;
    }

    try {
      final txs = await _api!.getHistory(address, net);

      if (!mounted || loadId != _loadId) return;

      final hasMore = txs.length >= _pageSize;
      setState(() {
        if (page == 0) {
          _transactions = txs;
        } else {
          _transactions.addAll(txs);
        }
        _page = page;
        _hasMore = hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        if (page == 0) {
          _error = 'Error al cargar historial: $e';
        }
        _isLoading = false;
        _isLoadingMore = false;
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
    final connectivity = context.watch<ConnectivityProvider>();

    if (!connectivity.isOnline) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de transacciones')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: AppTheme.textDarkSecondary),
              const SizedBox(height: 16),
              Text(
                'Sin conexion a internet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Conectate a internet para ver tu historial',
                style: TextStyle(color: AppTheme.textDarkSecondary),
              ),
            ],
          ),
        ),
      );
    }

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
      selectedColor: _colorForNetwork(network).withValues(alpha: 0.2),
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
            Icon(Icons.history, size: 64, color: AppTheme.textDarkSecondary.withValues(alpha: 0.5)),
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _transactions.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildTransactionItem(_transactions[i]);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final isSent = tx.type == 'sent';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
        color: color.withValues(alpha: 0.15),
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
