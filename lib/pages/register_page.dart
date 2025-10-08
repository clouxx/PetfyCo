import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl  = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PetfyAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const PetfyAuthHeader(
                      title: 'Crea tu cuenta',
                      caption: 'Únete a la comunidad PetfyCo 🇨🇴',
                    ),
                    PetfyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PetfyTextField(controller: nameCtrl,  hint: 'Nombre'),
                          const SizedBox(height: 12),
                          PetfyTextField(controller: emailCtrl, hint: 'Correo electrónico', keyboard: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          PetfyTextField(controller: passCtrl,  hint: 'Contraseña', obscure: true),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(error!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          PetfyButton(
                            label: 'Registrarse',
                            loading: loading,
                            onPressed: () async {
                              final p = passCtrl.text;
                              final ok = RegExp(r'[A-Z]').hasMatch(p) &&
                                  RegExp(r'[a-z]').hasMatch(p) &&
                                  RegExp(r'\d').hasMatch(p) &&
                                  RegExp(r'[!@#\$%\^&\*]').hasMatch(p) &&
                                  p.length >= 8;
                              if (!ok) {
                                setState(() => error =
                                  'La contraseña debe tener mayúscula, minúscula, número, símbolo y 8+ caracteres.');
                                return;
                              }
                              setState(() { loading = true; error = null; });
                              try {
                                final supa = Supabase.instance.client;
                                final res = await supa.auth.signUp(
                                  email: emailCtrl.text.trim(),
                                  password: passCtrl.text,
                                );
                                final uid = res.user?.id;
                                if (uid != null) {
                                  await supa.from('profiles').insert({'id': uid, 'display_name': nameCtrl.text});
                                }
                                if (mounted) context.go('/home');
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              } finally {
                                if (mounted) setState(() => loading = false);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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
