/// Widget que muestra un banner de conexion cuando el dispositivo no tiene internet.
/// Escucha el estado de conectividad a traves de ConnectivityProvider
/// y muestra una barra naranja con el mensaje "Sin conexion a internet".
/// La transicion entre los estados online/offline es animada con AnimatedCrossFade.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/connectivity_provider.dart';

/// Widget que envuelve su hijo con un banner de conectividad.
/// Muestra un banner naranja en la parte superior cuando no hay internet.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    return Column(
      children: [
        // Banner animado que aparece/desaparece segun la conectividad
        AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.orange.shade800,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Sin conexion a internet',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isOnline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        Expanded(child: child),
      ],
    );
  }
}
