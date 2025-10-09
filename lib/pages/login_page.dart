import 'package:flutter/material.dart';
import '../widgets/petfy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool showPass = false;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // Logo
                Image.asset('assets/logo/petfyco_logo_full.png', height: 120),
                const SizedBox(height: 16),
                Text('¡Bienvenido a PetfyCo!',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Rescate y adopción de mascotas en Colombia', style: theme.textTheme.bodyMedium),

                const SizedBox(height: 18),

                PetfyCard(
                  // si quieres color de fondo sutil:
                  color: const Color(0xFFF6F2FF).withOpacity(.45),
                  child: Column(
                    children: [
                      PetfyTextField(
                        controller: emailCtrl,
                        hint: 'Correo electrónico',
                        keyboard: TextInputType.emailAddress,      // <- ahora soportado
                        prefix: const Icon(Icons.mail_outline),
                      ),
                      _kGap,
                      PetfyTextField(
                        controller: passCtrl,
                        hint: 'Contraseña',
                        obscure: !showPass,
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(                          // <- ahora soportado
                          icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showPass = !showPass),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PetfyLink(
                          text: '¿Olvidaste la contraseña?',
                          onTap: () {
                            // TODO: navegar a "forgot password"
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      PetfyButton(
                        text: 'Ingresar',
                        loading: isLoading, // <- sigue funcionando
                        onPressed: () async {
                          // TODO: login
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PetfyLink(
                  text: '¿No tienes cuenta? Regístrate',
                  onTap: () {
                    // TODO: navegar a register
                  },
                ),
                const SizedBox(height: 8),
                Text('Al continuar aceptas nuestras políticas.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _kGap = SizedBox(height: 12);
