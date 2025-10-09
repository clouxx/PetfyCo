import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/petfy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool showPass = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
            const SizedBox(height: 6),
            Center(
              child: Image.asset(
                'assets/logo/petfyco_logo_full.png',
                height: 140, // <-- logo más grande
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Bienvenido a PetfyCo!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Rescate y adopción de mascotas en Colombia',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            PetfyCard(
              child: Column(
                children: [
                  PetfyTextField(
                    controller: emailCtrl,
                    hint: 'Correo electrónico',
                    keyboard: TextInputType.emailAddress,
                    // tu widget acepta 'prefix' (no 'prefixIcon')
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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // context.go('/forgot'); // cuando la tengas
                      },
                      child: const Text('¿Olvidaste la contraseña?'),
                    ),
                  ),
                  PetfyButton(
                    text: 'Ingresar',
                    loading: isLoading, // <-- tu botón usa 'loading'
                    onPressed: _onLogin,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Al continuar aceptas nuestras políticas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
