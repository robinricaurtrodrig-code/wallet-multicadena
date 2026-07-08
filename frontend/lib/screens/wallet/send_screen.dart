import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';

/// SendScreen: Pantalla para enviar criptomonedas a otra direccion
/// Muestra formulario con selector de red, direccion destino, monto y confirmacion
class SendScreen extends StatefulWidget {
  final WalletInfo? walletInfo; // Si viene de AssetDetailScreen, red preseleccionada

  const SendScreen({super.key, this.walletInfo});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedNetwork = '';
  bool _isSending = false;
  bool _showConfirm = false; // Alterna entre formulario y pantalla de confirmacion

  @override
  void initState() {
    super.initState();
    // Preseleccionar red si viene desde AssetDetailScreen
    if (widget.walletInfo != null) {
      _selectedNetwork = widget.walletInfo!.network;
    } else {
      _selectedNetwork = 'solana';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _showConfirm ? _buildConfirmScreen(wallet) : _buildForm(wallet),
      ),
    );
  }

  /// Formulario principal: selector de red, balance, direccion y monto
  Widget _buildForm(WalletProvider wallet) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleccionar red',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _NetworkChip(
                label: 'Solana',
                symbol: 'SOL',
                color: const Color(0xFF9945FF),
                selected: _selectedNetwork == 'solana',
                enabled: widget.walletInfo == null,
                onTap: () => setState(() => _selectedNetwork = 'solana'),
              ),
              const SizedBox(width: 8),
              _NetworkChip(
                label: 'Bitcoin',
                symbol: 'BTC',
                color: const Color(0xFFF7931A),
                selected: _selectedNetwork == 'bitcoin',
                enabled: widget.walletInfo == null,
                onTap: () => setState(() => _selectedNetwork = 'bitcoin'),
              ),
              const SizedBox(width: 8),
              _NetworkChip(
                label: 'BNB',
                symbol: 'BNB',
                color: const Color(0xFFF0B90B),
                selected: _selectedNetwork == 'bnb',
                enabled: widget.walletInfo == null,
                onTap: () => setState(() => _selectedNetwork = 'bnb'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (wallet.hasWallet) _buildBalanceInfo(wallet),
          const SizedBox(height: 24),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Direccion del destinatario',
              hintText: 'Ingresa la direccion de la wallet',
              prefixIcon: Icon(Icons.person),
            ),
            maxLines: 2,
            keyboardType: TextInputType.text,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa una direccion';
              if (v.length < 20) return 'Direccion invalida';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Cantidad a enviar',
              hintText: '0.00',
              prefixIcon: const Icon(Icons.monetization_on),
              suffixText: _symbolForNetwork(_selectedNetwork),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa una cantidad';
              final amount = double.tryParse(v);
              if (amount == null || amount <= 0) return 'Cantidad invalida';
              return null;
            },
          ),
          const SizedBox(height: 24),

          if (widget.walletInfo != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _validateAndConfirm,
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Continuar'),
              ),
            ),

          if (widget.walletInfo == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _validateAndConfirm,
                icon: const Icon(Icons.arrow_upward),
                label: Text('Continuar con ${_symbolForNetwork(_selectedNetwork)}'),
              ),
            ),
        ],
      ),
    );
  }

  /// Muestra el balance disponible de la red seleccionada
  Widget _buildBalanceInfo(WalletProvider wallet) {
    final info = wallet.wallets.firstWhere(
      (w) => w.network == _selectedNetwork,
      orElse: () => WalletInfo(
        address: '',
        network: _selectedNetwork,
        symbol: _symbolForNetwork(_selectedNetwork),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppTheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${info.balance.toStringAsFixed(6)} ${info.symbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Pantalla de confirmacion: resumen de la transaccion y campo de contrasena
  Widget _buildConfirmScreen(WalletProvider wallet) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final address = _addressController.text.trim();
    final symbol = _symbolForNetwork(_selectedNetwork);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirmar envio',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _confirmRow('Red', _networkName(_selectedNetwork)),
                const Divider(height: 24),
                _confirmRow('Enviar', '$amount $symbol'),
                const Divider(height: 24),
                _confirmRow('A', address),
                const Divider(height: 24),
                _confirmRow('Comision estimada', 'Calculada automaticamente'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Contrasena de cifrado',
            hintText: 'Ingresa tu contrasena para firmar',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Contrasena requerida';
            return null;
          },
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : () => _executeSend(wallet),
            icon: _isSending
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Enviando...' : 'Confirmar y enviar'),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() => _showConfirm = false),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }

  /// Fila de informacion para la pantalla de confirmacion
  Widget _confirmRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(color: AppTheme.textDarkSecondary)),
        ),
        Expanded(
          child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  /// Valida el formulario y muestra la pantalla de confirmacion
  void _validateAndConfirm() {
    if (_formKey.currentState!.validate()) {
      setState(() => _showConfirm = true);
    }
  }

  /// Ejecuta el envio: llama a wallet.sendTransaction que prepara, firma y retransmite
  Future<void> _executeSend(WalletProvider wallet) async {
    if (_passwordController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final tx = await wallet.sendTransaction(
        network: _selectedNetwork,
        toAddress: _addressController.text.trim(),
        amount: double.parse(_amountController.text),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaccion enviada exitosamente'),
          backgroundColor: AppTheme.success,
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Abrir URL del explorador con tx.txHash
            },
          ),
        ),
      );
      Navigator.pop(context, tx);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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

  /// Retorna el nombre legible de la red
  String _networkName(String network) {
    switch (network) {
      case 'solana': return 'Solana';
      case 'bitcoin': return 'Bitcoin';
      case 'bnb': return 'BNB Chain';
      default: return network;
    }
  }
}

/// _NetworkChip: Chip visual para seleccionar la red blockchain
class _NetworkChip extends StatelessWidget {
  final String label;
  final String symbol;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.label,
    required this.symbol,
    required this.color,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(symbol, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? color : AppTheme.textDarkSecondary,
            )),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 11,
              color: selected ? color : AppTheme.textDarkSecondary,
            )),
          ],
        ),
      ),
    );
  }
}
