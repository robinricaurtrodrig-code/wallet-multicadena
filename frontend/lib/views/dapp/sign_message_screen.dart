// SignMessageScreen: firma mensajes para autenticacion en DApps

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../controllers/wallet_provider.dart';
import '../../controllers/security_provider.dart';
import '../../services/dapp_service.dart';

class SignMessageScreen extends StatefulWidget {
  const SignMessageScreen({super.key});

  @override
  State<SignMessageScreen> createState() => _SignMessageScreenState();
}

class _SignMessageScreenState extends State<SignMessageScreen> {
  final _messageCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedNetwork = 'solana';
  String? _signature;
  bool _isSigning = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Firma el mensaje con la clave de la red seleccionada
  Future<void> _sign() async {
    if (_messageCtrl.text.isEmpty) return;

    setState(() {
      _isSigning = true;
      _signature = null;
    });

    try {
      final wallet = context.read<WalletProvider>();
      context.read<SecurityProvider>().recordActivity();

      if (_selectedNetwork == 'bnb') {
        final privateKey = await wallet.getPrivateKey(_selectedNetwork, _passwordCtrl.text);
        _signature = DAppService.signBnbMessage(
          privateKey: privateKey,
          message: _messageCtrl.text,
        );
      } else if (_selectedNetwork == 'solana') {
        final privateKey = await wallet.getPrivateKey(_selectedNetwork, _passwordCtrl.text);
        _signature = await DAppService.signSolanaMessage(
          privateKey: privateKey,
          message: _messageCtrl.text,
        );
      } else if (_selectedNetwork == 'bitcoin') {
        final key = await wallet.getBitcoinKey(_passwordCtrl.text);
        _signature = DAppService.signBitcoinMessage(
          key: key,
          message: _messageCtrl.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firmar Mensaje')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, size: 48, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text('Firma de Mensajes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Firma un mensaje con tu clave privada para autenticarte en DApps.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Selector de red
            Text('Red', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _networkChip('Solana', 'SOL', const Color(0xFF9945FF), 'solana'),
                const SizedBox(width: 8),
                _networkChip('Bitcoin', 'BTC', const Color(0xFFF7931A), 'bitcoin'),
                const SizedBox(width: 8),
                _networkChip('BNB', 'BNB', const Color(0xFFF0B90B), 'bnb'),
              ],
            ),
            const SizedBox(height: 24),

            // Mensaje a firmar
            TextFormField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Ingresa el mensaje a firmar',
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Contrasena para descifrar seed phrase
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Contrasena de cifrado',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // Boton firmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSigning ? null : _sign,
                icon: _isSigning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.draw),
                label: Text(_isSigning ? 'Firmando...' : 'Firmar Mensaje'),
              ),
            ),

            // Resultado de la firma
            if (_signature != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Firma', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _signature!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _signature!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Firma copiada al portapapeles')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar firma'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Chip visual para seleccionar la red blockchain
  Widget _networkChip(String label, String symbol, Color color, String network) {
    final selected = _selectedNetwork == network;
    return GestureDetector(
      onTap: () => setState(() => _selectedNetwork = network),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? color : null)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: selected ? color : null)),
          ],
        ),
      ),
    );
  }
}
