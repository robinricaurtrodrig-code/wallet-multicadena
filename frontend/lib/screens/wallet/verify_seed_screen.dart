import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'setup_pin_screen.dart';

/// Pantalla de verificacion de la frase semilla
/// El usuario debe seleccionar las palabras en el orden correcto para confirmar que la respaldo
class VerifySeedScreen extends StatefulWidget {
  final String seedPhrase;

  const VerifySeedScreen({super.key, required this.seedPhrase});

  @override
  State<VerifySeedScreen> createState() => _VerifySeedScreenState();
}

class _VerifySeedScreenState extends State<VerifySeedScreen> {
  final List<int> _selectedIndices = [];
  final List<String> _shuffledWords = [];
  late List<String> _originalWords;

  @override
  void initState() {
    super.initState();
    _originalWords = widget.seedPhrase.split(' ');
    // Mezclar las palabras para que el usuario las ordene correctamente
    _shuffledWords.addAll(_originalWords);
    _shuffledWords.shuffle();
  }

  /// Verifica si las palabras seleccionadas estan en el orden correcto
  bool get _isComplete => _selectedIndices.length == _originalWords.length;

  /// Retorna true si la seleccion del usuario coincide con la frase original
  bool get _isCorrect {
    if (!_isComplete) return false;
    for (var i = 0; i < _selectedIndices.length; i++) {
      if (_shuffledWords[_selectedIndices[i]] != _originalWords[i]) {
        return false;
      }
    }
    return true;
  }

  /// Procesa la palabra seleccionada por el usuario
  void _selectWord(int index) {
    if (_selectedIndices.contains(index)) return;

    setState(() {
      _selectedIndices.add(index);
    });

    // Si completo la seleccion, verificar automaticamente
    if (_selectedIndices.length == _originalWords.length) {
      _checkAndContinue();
    }
  }

  /// Retorna al paso anterior de seleccion
  void _undo() {
    if (_selectedIndices.isNotEmpty) {
      setState(() => _selectedIndices.removeLast());
    }
  }

  /// Verifica la frase y si es correcta, continua a la configuracion de PIN
  void _checkAndContinue() {
    if (!_isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El orden no es correcto. Intenta de nuevo.'),
          backgroundColor: AppTheme.error,
        ),
      );
      setState(() => _selectedIndices.clear());
      return;
    }

    // Frase correcta: navegar a configuracion de PIN
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SetupPinScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar Frase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de progreso
              Text(
                'Selecciona las palabras en el orden correcto',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Palabra ${_selectedIndices.length + 1} de ${_originalWords.length}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // Area donde se muestran las palabras seleccionadas
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedIndices.map((i) {
                    return Chip(
                      label: Text(_shuffledWords[i]),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _undo(),
                    );
                  }).toList(),
                ),
              ),
              ),

              if (_selectedIndices.isNotEmpty)
                TextButton.icon(
                  onPressed: _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Deshacer ultima'),
                ),

              const Spacer(),

              // Botones de palabras mezcladas para seleccionar
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_shuffledWords.length, (i) {
                  final selected = _selectedIndices.contains(i);
                  return ActionChip(
                    label: Text(_shuffledWords[i]),
                    onPressed: selected ? null : () => _selectWord(i),
                    backgroundColor: selected ? Colors.grey.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.1),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Boton para verificar manualmente
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isComplete ? _checkAndContinue : null,
                  child: const Text('Verificar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
