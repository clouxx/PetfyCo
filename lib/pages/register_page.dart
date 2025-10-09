import 'package:flutter/material.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();

  String? province;
  String? city;
  bool showPass = false;
  bool showPass2 = false;
  bool loading = false;

  // Demo de datos de provincia/ciudad
  final _provinces = const ['Antioquia', 'Cundinamarca', 'Valle del Cauca', 'Otro'];
  final _citiesByProv = const {
    'Antioquia': ['Medellín', 'Envigado', 'Bello'],
    'Cundinamarca': ['Bogotá', 'Soacha', 'Chía'],
    'Valle del Cauca': ['Cali', 'Palmira', 'Yumbo'],
    'Otro': ['Otra ciudad'],
  };

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => loading = true);
    try {
      // TODO: Lógica real de registro/Supabase y guardado de perfil
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada (demo).')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 520;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo/petfyco_logo_full.png',
                    width: isWide ? 150 : 120,
                    height: isWide ? 150 : 120,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Crear cuenta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          // Nombre
                          PetfyTextField(
                            controller: nameCtrl,
                            hint: 'Nombre',
                            prefix: const Icon(Icons.person_outline),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                          ),
                          const SizedBox(height: 12),
                          // Email
                          PetfyTextField(
                            controller: emailCtrl,
                            hint: 'Correo electrónico',
                            keyboard: TextInputType.emailAddress,
                            prefix: const Icon(Icons.mail_outline),
                            validator: (v) {
                              final text = v?.trim() ?? '';
                              if (text.isEmpty) return 'Ingresa tu correo';
                              final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text);
                              return ok ? null : 'Correo inválido';
                            },
                          ),
                          const SizedBox(height: 12),
                          // Contraseña
                          PetfyTextField(
                            controller: passCtrl,
                            hint: 'Contraseña',
                            obscure: !showPass,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => showPass = !showPass),
                            ),
                            validator: (v) {
                              final t = v ?? '';
                              if (t.length < 8) return 'Mínimo 8 caracteres';
                              if (!RegExp(r'[A-Z]').hasMatch(t)) return 'Incluye una mayúscula';
                              if (!RegExp(r'[a-z]').hasMatch(t)) return 'Incluye una minúscula';
                              if (!RegExp(r'[0-9]').hasMatch(t)) return 'Incluye un número';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          // Confirmar
                          PetfyTextField(
                            controller: pass2Ctrl,
                            hint: 'Confirmar contraseña',
                            obscure: !showPass2,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(showPass2 ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => showPass2 = !showPass2),
                            ),
                            validator: (v) =>
                                (v ?? '') == passCtrl.text ? null : 'No coincide',
                          ),
                          const SizedBox(height: 12),

                          // Provincia
                          PetfyDropdown<String>(
                            value: province,
                            hint: 'Provincia / Departamento',
                            items: _provinces
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                province = val;
                                city = null;
                              });
                            },
                            validator: (v) => v == null ? 'Selecciona provincia' : null,
                          ),
                          const SizedBox(height: 12),
                          // Ciudad
                          PetfyDropdown<String>(
                            value: city,
                            hint: 'Ciudad / Municipio',
                            items: (province == null
                                    ? const <String>[]
                                    : _citiesByProv[province] ?? const <String>[])
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) => setState(() => city = val),
                            validator: (v) => v == null ? 'Selecciona ciudad' : null,
                          ),
                          const SizedBox(height: 18),

                          PetfyButton(
                            text: 'Registrarme',
                            loading: loading,
                            onPressed: _onRegister,
                          ),
                          const SizedBox(height: 6),

                          PetfyLink(
                            text: '¿Ya tienes cuenta? Inicia sesión',
                            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Al continuar aceptas nuestras políticas.',
                    textAlign: TextAlign.center,
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
      ),
    );
  }
}
