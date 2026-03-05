import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/petfy_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;

      // ✅ IMPORTANTE:
      // Debe ser una URL que EXISTA y esté permitida en Supabase Redirect URLs.
      // - Web local:  http://localhost:TU_PUERTO/reset-password
      // - Producción: https://tu-dominio/reset-password
      await sb.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: 'https://clouxx.github.io/PetfyCo/reset-password',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si el correo está registrado, te enviamos un enlace para restablecer tu contraseña.'),
        ),
      );

      context.pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 72),
                    const SizedBox(height: 12),
                    Text(
                      '¿Olvidaste tu contraseña?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PetfyTextField(
                      controller: _email,
                      hint: 'Correo electrónico',
                      keyboardType: TextInputType.emailAddress,
                      prefix: const Icon(Icons.mail_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    PetfyButton(
                      text: 'Enviar enlace',
                      loading: _sending,
                      onPressed: _sending ? null : _sendReset,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: PetfyLink(
                        text: 'Volver a inicio de sesión',
                        onTap: () => context.pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
