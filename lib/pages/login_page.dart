import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // usa tus colores AppColors

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) {
            final maxW = c.maxWidth > 520 ? 520.0 : c.maxWidth;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LOGO grande
                      Image.asset(
                        'assets/logo/petfyco_logo_full.png',
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),

                      // Título + subrayado naranja
                      Text(
                        'Login',
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Correo
                      _LabeledField(
                        label: 'Correo Electrónico',
                        child: TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'correo@ejemplo.com',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Contraseña con “ojo”
                      _LabeledField(
                        label: 'Contraseña',
                        child: TextField(
                          controller: passCtrl,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ¿Olvidado tu contraseña?
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            text: '¿Has Olvidado Tu Contraseña?',
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // TODO: navega a tu página de recuperación
                                // context.push('/forgot');  // si usas go_router
                              },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón Login
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            // TODO: login
                          },
                          child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Registro
                      Text.rich(
                        TextSpan(
                          text: '¿No Tienes Cuenta? ',
                          style: t.bodyMedium?.copyWith(color: AppColors.navy.withValues(alpha: .7)),
                          children: [
                            TextSpan(
                              text: 'Regístrate',
                              style: t.bodyMedium?.copyWith(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // context.push('/register');
                                },
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.navy.withValues(alpha: .06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}
