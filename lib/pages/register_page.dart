import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  final nameCtrl  = TextEditingController();
  bool loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PetfyAuthBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  PetfyAuthHeader(
                    title: 'Crear cuenta',
                    subtitle: 'Únete a PetfyCo para ayudar y adoptar',
                  ),
                  const SizedBox(height: 14),
                  PetfyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!, style: const TextStyle(color: Colors.red)),
                          ),
                        PetfyTextField(controller: nameCtrl,  hint: 'Nombre'),
                        const SizedBox(height: 12),
                        PetfyTextField(controller: emailCtrl, hint: 'Correo electrónico', keyboard: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        PetfyTextField(controller: passCtrl,  hint: 'Contraseña', obscure: true),
                        const SizedBox(height: 12),
                        PetfyButton(text: 'Registrarme', loading: loading, onPressed: _register),
                        const SizedBox(height: 8),
                        TextButton(onPressed: () => context.go('/login'), child: const Text('¿Ya tienes cuenta? Inicia sesión')),
                      ],
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

  Future<void> _register() async {
    final p = passCtrl.text;
    final ok = RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[a-z]').hasMatch(p) &&
        RegExp(r'\d').hasMatch(p) &&
        RegExp(r'[!@#\$%\^&\*]').hasMatch(p) &&
        p.length >= 8;

    if (!ok) {
      setState(() => _error = 'La contraseña debe tener mayúscula, minúscula, número, caracter especial y 8+ caracteres.');
      return;
    }

    setState(() {
      _error = null;
      loading = true;
    });
    try {
      final supa = Supabase.instance.client;
      final res = await supa.auth.signUp(email: emailCtrl.text.trim(), password: passCtrl.text);
      final uid = res.user?.id;
      if (uid != null) {
        await supa.from('profiles').insert({'id': uid, 'display_name': nameCtrl.text});
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
