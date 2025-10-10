import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/petfy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;
      await sb.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (mounted) {
        // navega a home (ajusta la ruta a la tuya)
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
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
            child: PetfyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo (ajusta tu asset si lo deseas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.asset(
                      'assets/logo/petfyco_logo_full.png',
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PetfyTextField(
                    controller: _email,
                    hint: 'Correo electrónico',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(Icons.mail_outline),
                  ),
                  const SizedBox(height: 12),
                  PetfyTextField(
                    controller: _pass,
                    hint: 'Contraseña',
                    obscure: _obscure,
                    prefix: const Icon(Icons.lock_outline),
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PetfyButton(
                    text: 'Iniciar sesión',
                    loading: _sending,
                    onPressed: _sending ? null : () => _doLogin(),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: PetfyLink(
                      text: '¿No tienes cuenta? Regístrate',
                      onTap: () => Navigator.pushNamed(context, '/register'),
                    ),
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
