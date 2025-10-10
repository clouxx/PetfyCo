import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/petfy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _sending = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;
      await sb.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      // Ajusta esta ruta a la que tengas definida como "home"
      context.go('/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo (asegúrate de que la ruta exista en pubspec.yaml)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Image.asset(
                    'assets/logo/petfyco_logo_full.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
                PetfyCard(
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        PetfyTextField(
                          controller: _email,
                          label: 'Correo electrónico',
                          keyboardType: TextInputType.emailAddress,
                          prefix: const Icon(Icons.mail_outline),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Ingresa tu correo';
                            if (!t.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        PetfyTextField(
                          controller: _pass,
                          label: 'Contraseña',
                          obscure: _obscure,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                        ),
                        const SizedBox(height: 16),
                        PetfyButton(
                          text: 'Iniciar sesión',
                          loading: _sending,
                          onPressed: _sending ? null : () { _doLogin(); },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta?'),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Registrarse'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/forgot'), // ajusta si tienes otra ruta
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
