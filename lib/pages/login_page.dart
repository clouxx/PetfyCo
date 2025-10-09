import 'package:flutter/material.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';
import 'package:petfyco/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool showPass = false;
  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size.width > 520 ? 480 : 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/logo/petfyco_logo_full.png', height: 300),
                const SizedBox(height: 16),

                Text('Bienvenido',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 6),
                Text('Rescate y adopción de mascotas en Colombia',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        )),
                const SizedBox(height: 18),

                PetfyCard(
                  child: Column(
                    children: [
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PetfyLink(
                          text: '¿Olvidaste la contraseña?',
                          onTap: () {
                            // ir a recuperar contraseña si lo tienes
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      PetfyButton(
                        text: 'Ingresar',
                        loading: loading,
                        onPressed: () async {
                          setState(() => loading = true);
                          try {
                            // TODO: login real con Supabase
                            if (!mounted) return;
                            context.go('/home');
                          } finally {
                            if (mounted) setState(() => loading = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                PetfyLink(
                  text: '¿No tienes cuenta? Regístrate',
                  onTap: () => context.go('/register'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Al continuar aceptas nuestras políticas.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
