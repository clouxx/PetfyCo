import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();

  bool showPass = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Image.asset(
                'assets/logo/petfyco_logo_full.png',
                height: 120,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Crear cuenta',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PetfyCard(
              child: Column(
                children: [
                  PetfyTextField(
                    controller: nameCtrl,
                    hint: 'Nombre',
                    prefix: const Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                  PetfyTextField(
                    controller: emailCtrl,
                    hint: 'Correo electrónico',
                    keyboard: TextInputType.emailAddress,
                    prefix: const Icon(Icons.mail_outline),
                  ),
                  const SizedBox(height: 12),
                  PetfyTextField(
                    controller: passCtrl,
                    hint: 'Contraseña',
                    obscure: !showPass,
                    prefix: const Icon(Icons.lock_outline),
                    suffix: IconButton(
                      onPressed: () => setState(() => showPass = !showPass),
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PetfyButton(
                    text: 'Registrarme',
                    loading: isLoading, // <-- usa 'loading'
                    onPressed: _onRegister,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
