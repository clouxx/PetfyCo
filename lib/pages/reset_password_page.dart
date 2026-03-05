import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/petfy_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? email;
  const ResetPasswordPage({super.key, this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _sending = false;
  bool _obscure = true;

  @override
  void dispose() {
    _code.dispose();
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (widget.email == null || widget.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se proporcionó un correo válido.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;

      // 1. Verificar el código OTP
      await sb.auth.verifyOTP(
        email: widget.email!,
        token: _code.text.trim(),
        type: OtpType.recovery,
      );

      // 2. Si es exitoso, actualizar la contraseña
      await sb.auth.updateUser(
        UserAttributes(password: _pass1.text),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')),
      );

      // Cierra sesión por seguridad y vuelve al login
      await sb.auth.signOut();
      if (!mounted) return;
      context.go('/login');
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
                    const Icon(Icons.password, size: 72),
                    const SizedBox(height: 12),
                    Text(
                      'Restablecer contraseña',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (widget.email != null)
                      Text(
                        'Ingresa el código de 6 dígitos enviado a:\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    const SizedBox(height: 16),
                    PetfyTextField(
                      controller: _code,
                      hint: 'Código de verificación de 6 dígitos',
                      keyboardType: TextInputType.number,
                      prefix: const Icon(Icons.numbers),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa el código';
                        if (v.trim().length != 6) return 'Debe tener 6 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    PetfyTextField(
                      controller: _pass1,
                      hint: 'Nueva contraseña',
                      obscureText: _obscure,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PetfyTextField(
                      controller: _pass2,
                      hint: 'Confirmar contraseña',
                      obscureText: _obscure,
                      prefix: const Icon(Icons.lock_outline),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirma la contraseña';
                        if (v != _pass1.text) return 'No coinciden';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    PetfyButton(
                      text: 'Guardar contraseña',
                      loading: _sending,
                      onPressed: _sending ? null : _updatePassword,
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
