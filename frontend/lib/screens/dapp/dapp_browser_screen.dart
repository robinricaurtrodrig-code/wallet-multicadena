// DAppBrowserScreen: lista de DApps populares para conectar la wallet

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';

class DAppBrowserScreen extends StatelessWidget {
  const DAppBrowserScreen({super.key});

  /// Abre una URL en el navegador del sistema
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dapps = [
      {
        'name': 'Uniswap',
        'url': 'https://app.uniswap.org',
        'desc': 'Exchange descentralizado en Ethereum/BNB',
        'icon': Icons.swap_horiz,
        'color': const Color(0xFFFF007A),
      },
      {
        'name': 'PancakeSwap',
        'url': 'https://pancakeswap.finance',
        'desc': 'Exchange y farming en BNB Chain',
        'icon': Icons.egg,
        'color': const Color(0xFFF0B90B),
      },
      {
        'name': 'Jupiter',
        'url': 'https://jup.ag',
        'desc': 'Agregador de exchanges en Solana',
        'icon': Icons.rocket_launch,
        'color': const Color(0xFF9945FF),
      },
      {
        'name': 'Magic Eden',
        'url': 'https://magiceden.io',
        'desc': 'Marketplace de NFTs en Solana y Bitcoin',
        'icon': Icons.store,
        'color': const Color(0xFFE42575),
      },
      {
        'name': 'Raydium',
        'url': 'https://raydium.io',
        'desc': 'AMM y farming en Solana',
        'icon': Icons.water_drop,
        'color': const Color(0xFF4B8EF5),
      },
      {
        'name': 'Venus Protocol',
        'url': 'https://venus.io',
        'desc': 'Prestamos y borrowing en BNB Chain',
        'icon': Icons.account_balance,
        'color': const Color(0xFF2B6CB0),
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('DApps')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.apps, size: 48, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Explorar DApps', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Conecta tu wallet con aplicaciones descentralizadas. '
            'Cada DApp se abre en tu navegador.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Lista de DApps
          ...dapps.map((dapp) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (dapp['color'] as Color).withValues(alpha: 0.15),
                child: Icon(dapp['icon'] as IconData, color: dapp['color'] as Color),
              ),
              title: Text(dapp['name'] as String),
              subtitle: Text(dapp['desc'] as String),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUrl(dapp['url'] as String),
            ),
          )),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Seccion informativa
          Text('Como conectar tu wallet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '1. Abre la DApp en tu navegador\n'
            '2. Selecciona "Conectar wallet" o "Connect"\n'
            '3. Elige "WalletConnect" o pega tu direccion\n'
            '4. Usa "Firmar Mensaje" para autenticarte cuando la DApp lo solicite\n'
            '5. Confirma las transacciones desde "Enviar" en la app',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
