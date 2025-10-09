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
  final confirmCtrl = TextEditingController();

  String? countryCode;   // p.e. +57
  String? depto;         // departamento
  String? city;          // municipio

  bool showPass = false;
  bool showConfirm = false;
  bool accepted = false;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Image.asset('assets/logo/petfyco_logo_full.png', height: 110),
                  const SizedBox(height: 12),
                  Text('Crear cuenta', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),

                  PetfyCard(
                    color: const Color(0xFFF6F2FF).withOpacity(.45), // <- ahora permitido
                    child: Column(
                      children: [
                        // Nombre
                        PetfyTextField(
                          controller: nameCtrl,
                          hint: 'Nombre',
                          prefix: const Icon(Icons.person_outline),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                        ),
                        _gap,
                        // Email
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Correo electrónico',
                          keyboard: TextInputType.emailAddress, // <- ahora permitido
                          prefix: const Icon(Icons.mail_outline),
                          validator: (v) {
                            final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v ?? '');
                            return ok ? null : 'Correo inválido';
                          },
                        ),
                        _gap,
                        // Contraseña
                        PetfyTextField(
                          controller: passCtrl,
                          hint: 'Contraseña',
                          obscure: !showPass,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton( // <- ahora permitido
                            icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => showPass = !showPass),
                          ),
                          validator: (v) => (v != null && v.length >= 8) ? null : 'Mínimo 8 caracteres',
                        ),
                        _gap,
                        // Confirmar
                        PetfyTextField(
                          controller: confirmCtrl,
                          hint: 'Confirmar contraseña',
                          obscure: !showConfirm,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => showConfirm = !showConfirm),
                          ),
                          validator: (v) => v == passCtrl.text ? null : 'No coincide',
                        ),
                        _gap,

                        // Fila País / Departamento
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: PetfyDropdown<String>(
                                value: countryCode,
                                hint: 'País', // <- ahora permitido
                                items: const [
                                  DropdownMenuItem(value: '+57', child: Text('+57')),
                                  DropdownMenuItem(value: '+593', child: Text('+593')),
                                ],
                                onChanged: (v) => setState(() => countryCode = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 8,
                              child: PetfyDropdown<String>(
                                value: depto,
                                hint: 'Departamento', // <- antes “Provincia”
                                items: const [
                                  DropdownMenuItem(value: 'Antioquia', child: Text('Antioquia')),
                                  DropdownMenuItem(value: 'Cundinamarca', child: Text('Cundinamarca')),
                                  DropdownMenuItem(value: 'Valle del Cauca', child: Text('Valle del Cauca')),
                                ],
                                onChanged: (v) => setState(() {
                                  depto = v;
                                  city = null; // resetea ciudad
                                }),
                              ),
                            ),
                          ],
                        ),
                        _gap,

                        // Ciudad (Municipio)
                        PetfyDropdown<String>(
                          value: city,
                          hint: 'Ciudad', // <- ahora permitido
                          items: _citiesFor(depto)
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => city = v),
                        ),
                        _gap,

                        // Ubicación - botón simple (puedes reemplazar por mapa)
                        PetfyButton(
                          leading: const Icon(Icons.map_outlined),
                          text: 'Ubicación seleccionada (lat,lng)',
                          onPressed: () {
                            // TODO: abrir mapa y asignar lat/lng en tu estado
                          },
                        ),
                        const SizedBox(height: 10),

                        // Acepto términos
                        Row(
                          children: [
                            Checkbox(
                              value: accepted,
                              onChanged: (v) => setState(() => accepted = v ?? false),
                            ),
                            Flexible(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('Acepto los '),
                                  GestureDetector(
                                    onTap: () => _showTerms(context),
                                    child: Text(
                                      'términos y condiciones',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        _gap,
                        PetfyButton(
                          text: 'Registrarme',
                          loading: saving,
                          onPressed: () async {
                            if (!accepted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Debes aceptar los términos')),
                              );
                              return;
                            }
                            if (formKey.currentState!.validate()) {
                              setState(() => saving = true);
                              try {
                                // TODO: llamada a Supabase + upsert profile
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  PetfyLink(
                    text: '¿Ya tienes cuenta? Inicia sesión',
                    onTap: () {
                      // TODO: navegar a login
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _citiesFor(String? depto) {
    switch (depto) {
      case 'Antioquia':
        return const ['Medellín', 'Envigado', 'Bello'];
      case 'Cundinamarca':
        return const ['Bogotá', 'Chía', 'Zipaquirá'];
      case 'Valle del Cauca':
        return const ['Cali', 'Palmira', 'Yumbo'];
      default:
        return const [];
    }
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Términos y Condiciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: const [
                        Text(
                          'Bienvenido a PetfyCo. Al utilizar nuestra aplicación aceptas los siguientes términos...',
                        ),
                        SizedBox(height: 12),
                        Text('1. Descripción del servicio\n• Publicar mascotas disponibles para adopción...\n'),
                        SizedBox(height: 12),
                        Text('2. Aceptación de términos\n…'),
                        SizedBox(height: 12),
                        Text('3. Registro y responsabilidad del usuario\n…'),
                        SizedBox(height: 12),
                        Text('4. Publicación de contenido\n…'),
                        SizedBox(height: 12),
                        Text('5. Uso adecuado / prohibiciones\n…'),
                        SizedBox(height: 12),
                        Text('6. Responsabilidad\n…'),
                        SizedBox(height: 12),
                        Text('7. Modificaciones — 8. Cancelación — 9. Legislación — 10. Contacto\n…'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Aceptar'),
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

const _gap = SizedBox(height: 12);
