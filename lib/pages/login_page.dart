import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _sending = false;
  bool _obscure = true;

  Future<void> _doLogin() async {
    setState(() => _sending = true);
    try {
      // TODO: tu lógica de login con Supabase
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go('/home'); // o tu ruta real
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PetfyCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo (asegúrate que exista en pubspec.yaml)
                Image.asset('assets/logo/petfyco_logo_full.png', width: 300, height: 300, fit: BoxFit.contain),
                const SizedBox(height: 12),
                const Text('Iniciar sesión', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),

                PetfyTextField(
                  controller: emailCtrl,
                  label: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  prefix: const Icon(Icons.mail_outlined),
                ),
                const SizedBox(height: 12),

                PetfyTextField(
                  controller: passCtrl,
                  label: 'Contraseña',
                  obscureText: _obscure,
                  prefix: const Icon(Icons.lock_outline),
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 16),

                PetfyButton(
                  text: 'Entrar',
                  loading: _sending,
                  onPressed: _sending ? null : () => _doLogin(),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PetfyLink(
                      text: '¿Olvidaste la contraseña?',
                      onTap: () => context.push('/forgot'),
                    ),
                    const SizedBox(width: 12),
                    PetfyLink(
                      text: 'Registrarse',
                      onTap: () => context.push('/register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
