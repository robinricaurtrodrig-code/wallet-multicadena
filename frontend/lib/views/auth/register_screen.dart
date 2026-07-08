import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  /// Registra un nuevo usuario con los datos del formulario
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthProvider>().register(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      _usernameCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrate', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Completa los datos para crear tu wallet', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  // Campo de nombre de usuario
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => auth.clearError(),
                    validator: (v) => v != null && v.length >= 2 ? null : 'Minimo 2 caracteres',
                  ),
                  const SizedBox(height: 16),
                  // Campo de correo electronico
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => auth.clearError(),
                    validator: (v) => v?.contains('@') == true ? null : 'Correo invalido',
                  ),
                  const SizedBox(height: 16),
                  // Campo de contrasena
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => auth.clearError(),
                    validator: (v) => v != null && v.length >= 6 ? null : 'Minimo 6 caracteres',
                  ),
                  const SizedBox(height: 16),
                  // Campo de confirmacion de contrasena
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contrasena',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => auth.clearError(),
                    validator: (v) => v == _passwordCtrl.text ? null : 'Las contrasenas no coinciden',
                  ),
                  // Mostrar error de autenticacion si existe
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.error!, style: const TextStyle(color: AppTheme.error)),
                  ],
                  const SizedBox(height: 32),
                  // Boton de registro
                  ElevatedButton(
                    onPressed: auth.status == AuthStatus.loading ? null : _register,
                    child: auth.status == AuthStatus.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear Cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
