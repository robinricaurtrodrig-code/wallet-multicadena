import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/wallet_provider.dart';
import '../../core/crypto/bip39.dart';
import '../../config/theme.dart';
import 'setup_pin_screen.dart';

/// Pantalla para importar una wallet existente usando la frase semilla BIP39
/// El usuario ingresa su seed phrase de 12 o 24 palabras para recuperar su wallet
class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _seedCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _seedCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Procesa la importacion de la wallet: valida la frase, deriva direcciones y cifra
  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final wallet = context.read<WalletProvider>();
    // Limpiar la frase: reemplazar saltos de linea y espacios multiples por un solo espacio
    final seedPhrase = _seedCtrl.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s,;]+'), ' ')
        .trim();

    // Validar que la frase semilla tenga el formato BIP39 correcto
    if (!BIP39Service.validateSeedPhrase(seedPhrase)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Frase semilla invalida. Verifica las palabras.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Importar la wallet: valida, deriva direcciones BIP44, cifra con AES-256 y guarda
    final seedOk = await wallet.importWallet(seedPhrase, _passwordCtrl.text);

    setState(() => _isLoading = false);

    if (seedOk && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupPinScreen()),
      );
    } else if (mounted) {
      final errorMsg = wallet.error ?? 'Error desconocido al importar la wallet';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar Wallet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono y titulo de la pantalla
                const Icon(Icons.download_for_offline, size: 48, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Importar wallet existente',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu frase semilla de 12 o 24 palabras para recuperar tu wallet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Campo de texto para ingresar la frase semilla completa
                TextFormField(
                  controller: _seedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Frase semilla (seed phrase)',
                    hintText: 'Ingresa las palabras separadas por espacios',
                    prefixIcon: Icon(Icons.text_fields),
                  ),
                  maxLines: 4,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu frase semilla';
                    final words = v.trim().split(RegExp(r'\s+'));
                    if (words.length != 12 && words.length != 24) {
                      return 'La frase debe tener 12 o 24 palabras';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo de contrasena para cifrar la seed phrase localmente con AES-256
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena de cifrado',
                    hintText: 'Protege tu seed phrase localmente',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != null && v.length >= 6 ? null : 'Minimo 6 caracteres',
                ),
                const SizedBox(height: 24),

                // Boton para iniciar la importacion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importWallet,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Importar Wallet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
