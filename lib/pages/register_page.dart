import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  // Controllers
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // UI state
  bool obscure1 = true;
  bool obscure2 = true;
  bool loading = false;
  bool showMap = false;
  bool acceptedTerms = false;

  // Ubicación
  double? lat;
  double? lng;

  // Pais / Departamento / Ciudad
  String countryCode = '+57';
  String? depto;
  String? city;

  final deptos = const <String>[
    'Antioquia',
    'Cundinamarca',
    'Valle del Cauca',
    'Santander',
    'Atlántico',
  ];

  List<String> get cities {
    switch (depto) {
      case 'Antioquia':
        return ['Medellín', 'Envigado', 'Bello'];
      case 'Cundinamarca':
        return ['Bogotá', 'Soacha', 'Chía'];
      case 'Valle del Cauca':
        return ['Cali', 'Palmira', 'Yumbo'];
      case 'Santander':
        return ['Bucaramanga', 'Floridablanca', 'Giron'];
      case 'Atlántico':
        return ['Barranquilla', 'Soledad', 'Malambo'];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFakeLocation() async {
    // Placeholder de selección: asignamos coords de Medellín.
    setState(() {
      lat = 6.2518;
      lng = -75.5636;
      showMap = true;
    });
  }

  Future<void> _submit() async {
    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
      );
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);
    try {
      final auth = Supabase.instance.client.auth;

      final resp = await auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      final user = resp.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // Llamamos la RPC upsert_profile que ya creaste en la BD
      await Supabase.instance.client.rpc('upsert_profile', params: {
        'p_id': user.id,
        'p_name': nameCtrl.text.trim(),
        'p_email': emailCtrl.text.trim(),
        'p_country_code': countryCode,
        'p_phone': phoneCtrl.text.trim(),
        'p_province': depto,
        'p_city': city,
        'p_lat': lat,
        'p_lng': lng,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada! Revisa tu correo para confirmar.')),
        );
        context.go('/login');
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

  void _showTerms() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Última actualización: 20/06/2025\n\n'
                  'Bienvenido(a) a PetfyCo. Al utilizar nuestra aplicación, '
                  'aceptas los siguientes Términos y Condiciones de uso.\n',
                ),
                SizedBox(height: 8),
                _TermItem(
                  title: '1. Descripción del Servicio',
                  body:
                      'Publicar mascotas disponibles para adopción y reportar mascotas perdidas o encontradas.',
                ),
                _TermItem(
                  title: '2. Aceptación de Términos',
                  body:
                      'El uso de la app implica aceptar estos términos. Si no estás de acuerdo, por favor no la uses.',
                ),
                _TermItem(
                  title: '3. Registro del Usuario',
                  body:
                      'Podemos solicitar información veraz y actualizada. Mantén tus credenciales seguras.',
                ),
                _TermItem(
                  title: '4. Publicación de Contenido',
                  body:
                      'El contenido debe ser real, preciso y actualizado. Podemos retirar contenido inapropiado.',
                ),
                _TermItem(
                  title: '5. Uso Adecuado',
                  body:
                      'Prohibido el uso ilegal, suplantación de identidad o interferir con el funcionamiento de la app.',
                ),
                _TermItem(
                  title: '6. Responsabilidad',
                  body:
                      'No somos responsables por publicaciones de usuarios ni acuerdos fuera de la app.',
                ),
                _TermItem(
                  title: '7. Modificaciones',
                  body:
                      'Podemos actualizar estos Términos. Te notificaremos cambios importantes por correo.',
                ),
                _TermItem(
                  title: '8. Cancelación de Cuenta',
                  body:
                      'Podemos cancelar o suspender cuentas por uso indebido o violación de políticas.',
                ),
                _TermItem(
                  title: '9. Legislación Aplicable',
                  body: 'Estos Términos se rigen por las leyes del país en el que operes la app.',
                ),
                _TermItem(
                  title: '10. Contacto',
                  body: 'Si tienes dudas, contáctanos desde la sección de soporte dentro de la app.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Aceptar'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text('Registrarse',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 12),

                // Card principal
                PetfyCard(
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
                        const SizedBox(height: 14),

                        // Email
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Correo electrónico',
                          keyboardType: TextInputType.emailAddress,
                          prefix: const Icon(Icons.mail_outline),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Ingresa tu correo';
                            if (!t.contains('@') || !t.contains('.')) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Teléfono (código de país + número)
                        Row(
                          children: [
                            Flexible(
                              flex: 3,
                              child: PetfyDropdown<String>(
                                value: countryCode,
                                items: const [
                                  DropdownMenuItem(value: '+57', child: Text('+57')),
                                  DropdownMenuItem(value: '+593', child: Text('+593')),
                                  DropdownMenuItem(value: '+51', child: Text('+51')),
                                ],
                                onChanged: (v) => setState(() => countryCode = v ?? '+57'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              flex: 7,
                              child: PetfyTextField(
                                controller: phoneCtrl,
                                hint: 'Número de teléfono',
                                keyboardType: TextInputType.phone,
                                prefix: const Icon(Icons.phone_outlined),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Departamento
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Departamento',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(.8),
                              )),
                        ),
                        const SizedBox(height: 6),
                        PetfyDropdown<String>(
                          value: depto,
                          items: deptos
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            depto = v;
                            city = null;
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Ciudad
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Ciudad',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(.8),
                              )),
                        ),
                        const SizedBox(height: 6),
                        PetfyDropdown<String>(
                          value: city,
                          items: cities
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => city = v),
                        ),
                        const SizedBox(height: 14),

                        // Contraseña
                        PetfyTextField(
                          controller: passCtrl,
                          hint: 'Contraseña',
                          prefix: const Icon(Icons.lock_outline),
                          obscure: obscure1,
                          onToggleObscure: () => setState(() => obscure1 = !obscure1),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.length < 8) return 'Mínimo 8 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Confirmar contraseña
                        PetfyTextField(
                          controller: pass2Ctrl,
                          hint: 'Confirmar contraseña',
                          prefix: const Icon(Icons.lock_outline),
                          obscure: obscure2,
                          onToggleObscure: () => setState(() => obscure2 = !obscure2),
                          validator: (v) =>
                              (v ?? '') == passCtrl.text ? null : 'No coincide',
                        ),
                        const SizedBox(height: 18),

                        // Ubicación
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mi ubicación',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                'Selecciona tu ubicación para poder mostrarte mascotas cercanas.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        PetfyButton(
                          text: lat == null
                              ? 'Seleccionar en mapa'
                              : 'Ubicación seleccionada (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)})',
                          leading: const Icon(Icons.map_outlined),
                          onPressed: _pickFakeLocation, // placeholder
                        ),
                        const SizedBox(height: 10),

                        if (showMap)
                          Container(
                            height: 200,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: theme.colorScheme.surface.withOpacity(.6),
                              border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(.15)),
                            ),
                            child: const Text('Mapa (placeholder)'),
                          ),

                        const SizedBox(height: 16),

                        // Términos
                        Row(
                          children: [
                            Checkbox(
                              value: acceptedTerms,
                              onChanged: (v) => setState(() => acceptedTerms = v ?? false),
                            ),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('Acepto los '),
                                  PetfyLink(
                                    text: 'términos y condiciones',
                                    onTap: _showTerms,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Botón
                        PetfyButton(
                          text: 'Registrarme',
                          loading: loading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                PetfyLink(
                  text: '¿Ya tienes cuenta? Inicia sesión',
                  onTap: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  final String title;
  final String body;
  const _TermItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
