import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/wallet_provider.dart';
import '../../config/theme.dart';
import 'verify_seed_screen.dart';

/// Pantalla que muestra la frase semilla generada (seed phrase) al crear una wallet nueva
/// El usuario debe copiarla y guardarla de forma segura antes de continuar
class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String? _seedPhrase;
  bool _revealed = false;
  bool _savedSeed = false;

  @override
  void initState() {
    super.initState();
    _generateSeed();
  }

  /// Genera una nueva frase semilla de 12 palabras usando BIP39
  Future<void> _generateSeed() async {
    final wallet = context.read<WalletProvider>();
    final seed = await wallet.generateWallet();
    if (mounted) {
      setState(() => _seedPhrase = seed);
    }
  }

  /// Navega a la pantalla de verificacion de la frase semilla
  void _goToVerify() {
    if (_seedPhrase == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifySeedScreen(seedPhrase: _seedPhrase!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Wallet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instrucciones de seguridad para el usuario
              const Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.warning),
              const SizedBox(height: 16),
              Text(
                'Frase de recuperacion',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Esta es tu frase semilla (seed phrase). Es la UNICA forma de recuperar tu wallet si pierdes el acceso.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Escribela en papel y guardala en un lugar seguro. Nunca la compartas con nadie.',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Boton para revelar la frase semilla
              if (!_revealed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _revealed = true),
                    child: const Text('REVELAR FRASE SEMILLA'),
                  ),
                )
              else ...[
                // Mostrar la frase semilla generada en formato de cuadricula
                if (_seedPhrase != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildWordChips(_seedPhrase!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guarda estas palabras en orden. No las tomes foto ni las almacenes digitalmente.',
                    style: TextStyle(color: AppTheme.textDarkSecondary, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                // Checkbox de confirmacion de respaldo
                CheckboxListTile(
                  value: _savedSeed,
                  onChanged: (v) => setState(() => _savedSeed = v ?? false),
                  title: const Text('He guardado mi frase semilla de forma segura'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 16),

                // Boton para continuar solo si confirmo el respaldo
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savedSeed ? _goToVerify : null,
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Construye las tarjetas individuales para cada palabra de la frase semilla
  List<Widget> _buildWordChips(String phrase) {
    final words = phrase.split(' ');
    return List.generate(words.length, (i) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${i + 1}. ${words[i]}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    });
  }
}
