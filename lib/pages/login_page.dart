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
  bool _obscure = true;
  bool _sending = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_sending) return;
    setState(() => _sending = true);

    // TODO: integra aquí tu lógica real de login con Supabase
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _sending = false);
    // Si quieres navegar al home después de loguear:
    // context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // Logo con fallback para que no reviente si el asset falta
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/petfyco_logo_full.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(Icons.pets, size: 64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Iniciar sesión',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rescate y adopción de mascotas en Colombia',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card con el formulario
                  PetfyCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // OJO: PetfyTextField NO acepta 'label', usamos 'hint'
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Correo electrónico',
                          keyboardType: TextInputType.emailAddress,
                          prefix: const Icon(Icons.mail_outline),
                        ),
                        const SizedBox(height: 12),
                        PetfyTextField(
                          controller: passCtrl,
                          hint: 'Contraseña',
                          obscureText: _obscure,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // TODO: navegar a recuperación si la tienes
                              // context.go('/forgot');
                            },
                            child: const Text('¿Olvidaste la contraseña?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // En onPressed envolvemos el async para que el tipo sea void Function()
                        PetfyButton(
                          text: _sending ? 'Ingresando…' : 'Ingresar',
                          onPressed: _sending ? null : () => _doLogin(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta? '),
                      PetfyLink(
                        text: 'Regístrate',
                        onTap: () => context.go('/register'),
                      ),
                    ],
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
