import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final cityCtrl = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool obscure1 = true;
  bool obscure2 = true;
  bool loading = false;
  bool termsOk = false;

  // Tel: código país (simple)
  String countryCode = '+57'; // CO por defecto

  // Ubicación
  double? lat;
  double? lng;

  // Reglas password
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(passCtrl.text);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(passCtrl.text);
  bool get hasNumber => RegExp(r'\d').hasMatch(passCtrl.text);
  bool get hasSpecial => RegExp(r'[!@#\$%\^&\*_\-\.\,\;\:\?\+\=]').hasMatch(passCtrl.text);
  bool get hasLength => passCtrl.text.length >= 8;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    phoneCtrl.dispose();
    provinceCtrl.dispose();
    cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMyLocation() async {
    try {
      setState(() => loading = true);
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Otorga el permiso de ubicación para continuar')),
          );
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      setState(() {
        lat = p.latitude;
        lng = p.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener ubicación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    if (!termsOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
      );
      return;
    }
    setState(() => loading = true);

    try {
      // TODO: aquí integra tu signUp real (Supabase Auth + insert en profiles)
      await Future<void>.delayed(const Duration(milliseconds: 900));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada ✨')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 520;
    final cardPad = isWide ? 28.0 : 18.0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Image.asset(
                    'assets/logo/petfyco_logo_full.png',
                    height: 120,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Crear cuenta',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: AppColors.navy, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),

                // Card
                Card(
                  elevation: 0,
                  color: AppColors.blue.withValues(alpha: .06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: EdgeInsets.all(cardPad),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          // Nombre
                          PetfyTextField(
                            controller: nameCtrl,
                            hint: 'Nombre',
                            prefix: const Icon(Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                          ),
                          const SizedBox(height: 12),

                          // Correo
                          PetfyTextField(
                            controller: emailCtrl,
                            hint: 'Correo electrónico',
                            keyboard: TextInputType.emailAddress,
                            prefix: const Icon(Icons.mail_outline),
                            validator: (v) {
                              final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v ?? '');
                              return ok ? null : 'Correo inválido';
                            },
                          ),
                          const SizedBox(height: 12),

                          // Teléfono (código + número)
                          Row(
                            children: [
                              SizedBox(
                                width: 110,
                                child: PetfyDropdown<String>(
                                  value: countryCode,
                                  items: const ['+57', '+593', '+58', '+52', '+54'],
                                  label: 'País',
                                  onChanged: (v) => setState(() => countryCode = v ?? '+57'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PetfyTextField(
                                  controller: phoneCtrl,
                                  hint: 'Número de teléfono',
                                  keyboard: TextInputType.phone,
                                  prefix: const Icon(Icons.phone_outlined),
                                  validator: (v) =>
                                      (v == null || v.trim().length < 7) ? 'Número inválido' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Provincia
                          PetfyTextField(
                            controller: provinceCtrl,
                            hint: 'Provincia',
                            prefix: const Icon(Icons.map_outlined),
                          ),
                          const SizedBox(height: 12),

                          // Ciudad
                          PetfyTextField(
                            controller: cityCtrl,
                            hint: 'Ciudad',
                            prefix: const Icon(Icons.location_city_outlined),
                          ),
                          const SizedBox(height: 12),

                          // Contraseña
                          PetfyTextField(
                            controller: passCtrl,
                            hint: 'Contraseña',
                            obscure: obscure1,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              onPressed: () => setState(() => obscure1 = !obscure1),
                              icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (_) {
                              if (!(hasUpper && hasLower && hasNumber && hasLength && hasSpecial)) {
                                return 'La contraseña no cumple las reglas';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          _PasswordRules(
                            upper: hasUpper,
                            lower: hasLower,
                            number: hasNumber,
                            special: hasSpecial,
                            length: hasLength,
                          ),
                          const SizedBox(height: 12),

                          // Confirmar
                          PetfyTextField(
                            controller: pass2Ctrl,
                            hint: 'Confirmar contraseña',
                            obscure: obscure2,
                            prefix: const Icon(Icons.lock_reset_outlined),
                            suffix: IconButton(
                              onPressed: () => setState(() => obscure2 = !obscure2),
                              icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                            ),
                            validator: (v) => v == passCtrl.text ? null : 'No coincide',
                          ),
                          const SizedBox(height: 16),

                          // Ubicación
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Mi ubicación',
                                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700,
                                    )),
                          ),
                          const SizedBox(height: 8),
                          PetfyButton(
                            text: (lat == null)
                                ? 'Mostrar mapa'
                                : 'Ubicación lista (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)})',
                            onPressed: _pickMyLocation,
                            loading: loading,
                            leading: const Icon(Icons.map_outlined),
                            fill: false,
                          ),
                          const SizedBox(height: 16),

                          // TyC
                          Row(
                            children: [
                              Checkbox(
                                value: termsOk,
                                onChanged: (v) => setState(() => termsOk = v ?? false),
                                activeColor: AppColors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Acepto los términos y condiciones',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Botón
                          PetfyButton(
                            text: 'Registrarme',
                            onPressed: _submit,
                            loading: loading,
                          ),

                          const SizedBox(height: 16),
                          PetfyLink(
                            text: '¿Ya tienes cuenta? Inicia sesión',
                            onTap: () => context.go('/login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({
    required this.upper,
    required this.lower,
    required this.number,
    required this.special,
    required this.length,
  });

  final bool upper, lower, number, special, length;

  Widget _row(BuildContext ctx, bool ok, String text) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: ok ? Colors.green : Colors.pink),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(ctx).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, upper, 'Una mayúscula'),
        _row(context, lower, 'Una minúscula'),
        _row(context, length, '8 caracteres'),
        _row(context, number, 'Un número'),
        _row(context, special, 'Un caracter especial (!@#\$%^)'),
      ],
    );
  }
}
