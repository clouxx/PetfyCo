import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    const petfyBlue   = Color(0xFF2C62A3);
    const petfyNavy   = Color(0xFF15223B);
    const petfyOrange = Color(0xFFF28C2E);
    const bg          = Color(0xFFFAFCFF);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- LOGO ---
                  // Usa SOLO uno de los dos: el que tengas en pubspec
                  // Image.asset('assets/images/PetfyCo2.png', height: 160),
                  Image.asset('assets/logo/petfyco_logo_full.png', height: 160),

                  const SizedBox(height: 16),

                  // --- TÍTULO + subrayado naranja ---
                  Text(
                    'Login',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: petfyBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 140,
                    height: 4,
                    decoration: BoxDecoration(
                      color: petfyOrange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // --- Email ---
                  _Field(
                    label: 'Correo Electrónico',
                    hint: 'ejemplo@correo.com',
                    icon: Icons.mail_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 18),

                  // --- Password ---
                  _Field(
                    label: 'Contraseña',
                    hint: 'Tu contraseña',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onSuffixTap: () => setState(() => _obscure = !_obscure),
                    suffixIcon: _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),

                  const SizedBox(height: 10),

                  // --- ¿Olvidaste contraseña? ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: navegación recuperar contraseña
                      },
                      child: const Text(
                        '¿Has Olvidado Tu Contraseña?',
                        style: TextStyle(
                          color: petfyBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // --- Botón Login ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: petfyBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // TODO: login
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // --- Registrarse ---
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta? '),
                      GestureDetector(
                        onTap: () {
                          // TODO: ir a registro
                        },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: petfyBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onSuffixTap;
  final IconData? suffixIcon;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onSuffixTap,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    const fill = Colors.white;
    const borderColor = Color(0xFFE6ECF6);

    OutlineInputBorder _b(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B485F),
            )),
        const SizedBox(height: 8),
        TextField(
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: (suffixIcon != null)
                ? IconButton(icon: Icon(suffixIcon), onPressed: onSuffixTap)
                : null,
            isDense: true,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: _b(borderColor),
            enabledBorder: _b(borderColor),
            focusedBorder: _b(const Color(0xFFBFD3F0)),
          ),
        ),
      ],
    );
  }
}
