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

      // IMPORTANTE:
      // En web, define un redirectTo que apunte a tu ruta de "reset password".
      // Ejemplo (ajusta a tu dominio real):
      // final redirectTo = 'https://tudominio.com/PetfyCo/#/reset-password';
      //
      // Si aún no tienes esa pantalla, igual puedes enviar el correo sin redirectTo,
      // pero lo mejor es tener el flujo completo.
      const redirectTo = null; // <-- cámbialo cuando tengas tu URL final

      await sb.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: redirectTo,
      );

      if (!mounted) return;

      // Mensaje genérico (seguro): no confirmamos si existe o no el correo.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si el correo está registrado, te enviaremos un enlace para restablecer tu contraseña.',
          ),
        ),
      );

      // Opcional: volver al login
      context.pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enviando enlace: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
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
                    const SizedBox(height: 8),
                    const Icon(Icons.lock_reset, size: 64),
                    const SizedBox(height: 12),
                    const Text(
                      'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
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
