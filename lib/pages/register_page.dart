import 'package:flutter/material.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // UI state
  bool showPass = false;
  bool showConfirm = false;
  bool isLoading = false;
  bool termsAccepted = false;

  // Ubicación (opcional)
  double? lat;
  double? lng;

  // Selects
  String? countryCode = '+57';
  String? province;
  String? city;

  // Mock data para selects (cámbialo por tus fuentes reales)
  final countryCodes = const ['+57', '+593', '+58', '+51'];
  final provinces = const ['Antioquia', 'Cundinamarca', 'Valle del Cauca'];
  final cities = const ['Medellín', 'Bogotá', 'Cali'];

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      // TODO: aquí conectas con Supabase/Auth y luego guardas perfil.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro enviado (demo)')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 520;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/logo/petfyco_logo_full.png',
                  width: isWide ? 140 : 108,
                  height: isWide ? 140 : 108,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Crear cuenta',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // CARD con el formulario
                PetfyCard(
                  color: const Color(0xFFF6F2FF).withOpacity(.45),
                  child: Form(
                    key: _formKey,
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

                        // Correo
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Correo electrónico',
                          keyboard: TextInputType.emailAddress,
                          prefix: const Icon(Icons.mail_outline),
                          validator: (v) {
                            final text = (v ?? '').trim();
                            if (text.isEmpty) return 'Ingresa tu correo';
                            final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text);
                            return ok ? null : 'Correo inválido';
                          },
                        ),
                        const SizedBox(height: 12),

                        // Password
                        PetfyTextField(
                          controller: passCtrl,
                          hint: 'Contraseña',
                          obscure: !showPass,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            onPressed: () => setState(() => showPass = !showPass),
                            icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final t = (v ?? '');
                            if (t.length < 8) return 'Mínimo 8 caracteres';
                            if (!RegExp(r'[A-Z]').hasMatch(t)) {
                              return 'Debe contener una mayúscula';
                            }
                            if (!RegExp(r'[a-z]').hasMatch(t)) {
                              return 'Debe contener una minúscula';
                            }
                            if (!RegExp(r'[0-9]').hasMatch(t)) {
                              return 'Debe contener un número';
                            }
                            if (!RegExp(r'[!@#\$%\^&\*]').hasMatch(t)) {
                              return 'Incluye un carácter especial';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Confirmar password
                        PetfyTextField(
                          controller: confirmCtrl,
                          hint: 'Confirmar contraseña',
                          obscure: !showConfirm,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            onPressed: () => setState(() => showConfirm = !showConfirm),
                            icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                          ),
                          validator: (v) =>
                              v == passCtrl.text ? null : 'No coincide',
                        ),
                        const SizedBox(height: 16),

                        // País (código), Provincia, Ciudad
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: PetfyDropdown<String>(
                                value: countryCode,
                                items: countryCodes
                                    .map((c) =>
                                        DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(() => countryCode = v),
                                hint: 'País',
                                label: 'País',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 10,
                              child: PetfyDropdown<String>(
                                value: province,
                                items: provinces
                                    .map((p) =>
                                        DropdownMenuItem(value: p, child: Text(p)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  province = v;
                                  city = null;
                                }),
                                hint: 'Seleccionar provincia',
                                label: 'Provincia',
                                validator: (v) =>
                                    v == null ? 'Selecciona una provincia' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        PetfyDropdown<String>(
                          value: city,
                          items: cities
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => city = v),
                          hint: 'Seleccionar ciudad',
                          label: 'Ciudad',
                          validator: (v) =>
                              v == null ? 'Selecciona una ciudad' : null,
                        ),
                        const SizedBox(height: 16),

                        // Ubicación
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mi ubicación',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PetfyButton(
                          leading: const Icon(Icons.map_outlined, color: Colors.white),
                          text: (lat != null && lng != null)
                              ? 'Ubicación seleccionada (${"${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}"})'
                              : 'Mostrar mapa',
                          onPressed: () async {
                            // TODO: abre tu selector de mapas y actualiza lat/lng
                            setState(() {
                              lat = 6.2518; // DEMO
                              lng = -75.5636;
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        // Términos
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: termsAccepted,
                          onChanged: (v) => setState(() => termsAccepted = v ?? false),
                          title: const Text('Acepto los términos y condiciones'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),

                        // Botón registrar
                        PetfyButton(
                          text: 'Registrarme',
                          loading: isLoading,
                          onPressed: isLoading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                PetfyLink(
                  text: '¿Ya tienes cuenta? Inicia sesión',
                  onTap: () {
                    // Navegación básica; ajusta a tu router si usas go_router
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
