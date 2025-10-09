import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/petfy_widgets.dart';

final _sb = Supabase.instance.client;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _termsOk = false;
  bool _isSubmitting = false;

  static const String _countryCode = '+57 (Colombia)';

  double? _lat;
  double? _lng;
  String get _latLngText =>
      (_lat == null || _lng == null)
          ? 'Selecciona tu ubicación'
          : 'Ubicación seleccionada (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})';

  List<String> _deptNames = [];
  List<String> _cityNames = [];
  String? _deptSel;
  String? _citySel;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
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

  Future<void> _loadDepartments() async {
    try {
      final res = await _sb.from('departments').select('name').order('name');
      setState(() {
        _deptNames =
            (res as List).map((e) => (e['name'] as String).trim()).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadCities(String deptName) async {
    try {
      final dept = await _sb
          .from('departments')
          .select('id')
          .eq('name', deptName)
          .maybeSingle();
      if (dept == null) return;
      final res = await _sb
          .from('cities')
          .select('name')
          .eq('department_id', dept['id'])
          .order('name');

      setState(() {
        _cityNames =
            (res as List).map((e) => (e['name'] as String).trim()).toList();
        _citySel = null;
      });
    } catch (_) {}
  }

  Future<void> _pickLocation() async {
    try {
      if (!await _ensureLocationPermission()) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {}
  }

  Future<bool> _ensureLocationPermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsOk) {
      _snack('Debes aceptar los términos y condiciones.');
      return;
    }
    if (_deptSel == null || _citySel == null) {
      _snack('Selecciona departamento y ciudad.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final sign = await _sb.auth
          .signUp(email: emailCtrl.text.trim(), password: passCtrl.text);
      final uid = sign.user?.id;
      if (uid == null) {
        _snack('No se pudo crear el usuario.');
        setState(() => _isSubmitting = false);
        return;
      }

      await _sb.from('profiles').upsert({
        'id': uid,
        'display_name': nameCtrl.text.trim(),
        'phone': '$_countryCode ${phoneCtrl.text.trim()}',
        'depto': _deptSel,
        'municipio': _citySel,
        'lat': _lat,
        'lng': _lng,
      });

      _snack('Cuenta creada. Revisa tu correo.');
      if (mounted) context.go('/login');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- helpers para Dropdown ----------
  List<DropdownMenuItem<String>> _stringItems(List<String> data) =>
      data.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Image.asset('assets/logo/petfyco_logo_full.png',
                        height: 96),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                      child: Text('Registrarse',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Nombre',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        PetfyTextField(
                          controller: nameCtrl,
                          hint: 'Ingresa tu nombre',
                          prefix: const Icon(Icons.person_outline),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu nombre'
                                  : null,
                        ),
                        const SizedBox(height: 12),

                        const Text('Correo electrónico',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Ingresa tu correo',
                          keyboard: TextInputType.emailAddress, // <-- nombre correcto
                          prefix: const Icon(Icons.mail_outline),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Ingresa tu correo';
                            if (!t.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        const Text('Contraseña',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        PetfyTextField(
                          controller: passCtrl,
                          hint: 'Ingresa tu contraseña',
                          prefix: const Icon(Icons.lock_outline),
                          obscure: _obscure1,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure1 = !_obscure1),
                            icon: Icon(_obscure1
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'Mínimo 8 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        const Text('Confirmar contraseña',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        PetfyTextField(
                          controller: pass2Ctrl,
                          hint: 'Confirma tu contraseña',
                          prefix: const Icon(Icons.lock_outline),
                          obscure: _obscure2,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
                            icon: Icon(_obscure2
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                          validator: (v) =>
                              (v != passCtrl.text) ? 'No coincide' : null,
                        ),
                        const SizedBox(height: 16),

                        const Text('Teléfono',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: PetfyDropdown<String>(
                                value: _countryCode,
                                hint: 'Prefijo',
                                items: _stringItems(
                                    const ['+57 (Colombia)']), // <-- items correctos
                                onChanged: (_) {},
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 10,
                              child: PetfyTextField(
                                controller: phoneCtrl,
                                hint: 'Número de teléfono',
                                keyboard: TextInputType.phone, // <-- nombre correcto
                                prefix: const Icon(Icons.call_outlined),
                                validator: (v) {
                                  final t = v?.trim() ?? '';
                                  if (t.isEmpty) return 'Ingresa tu teléfono';
                                  if (t.length < 7) return 'Teléfono inválido';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Departamento',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        PetfyDropdown<String>(
                          value: _deptSel,
                          hint: 'Selecciona departamento',
                          items: _stringItems(_deptNames), // <-- items correctos
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _deptSel = val);
                            _loadCities(val);
                          },
                        ),
                        const SizedBox(height: 12),

                        const Text('Ciudad',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        PetfyDropdown<String>(
                          value: _citySel,
                          hint: _deptSel == null
                              ? 'Selecciona un departamento primero'
                              : 'Selecciona ciudad',
                          items: _stringItems(_cityNames), // <-- items correctos
                          onChanged: (val) => setState(() => _citySel = val),
                        ),
                        const SizedBox(height: 16),

                        const Text('Mi ubicación',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        PetfyButton(
                          text: '📍  $_latLngText',
                          onPressed: () {
                            if (_isSubmitting) return;
                            _pickLocation();
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Checkbox(
                              value: _termsOk,
                              onChanged: (v) =>
                                  setState(() => _termsOk = v ?? false),
                            ),
                            const Text('Acepto los '),
                            GestureDetector(
                              onTap: _showTerms,
                              child: const Text(
                                'términos y condiciones',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        PetfyButton(
                          text: _isSubmitting ? 'Registrando…' : 'Registrarme',
                          onPressed: () {
                            if (_isSubmitting) return;
                            _submit(); // callback no-nullable
                          },
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: GestureDetector(
                            onTap: () {
                              final r = GoRouter.of(context);
                              if (r.canPop()) {
                                r.pop();
                              } else {
                                r.go('/login');
                              }
                            },
                            child: const Text(
                              '¿Ya tienes cuenta? Inicia sesión',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520, maxWidth: 560),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('Términos y Condiciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Divider(),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Última actualización: 20/06/2025\n\n'
                    '1. Descripción del Servicio\n'
                    'PetfyCo permite publicar mascotas en adopción y reportar mascotas perdidas o encontradas.\n\n'
                    '2. Aceptación de Términos\n'
                    'El uso de la app implica la aceptación de estos términos.\n\n'
                    '3. Responsabilidad del Usuario\n'
                    'La información debe ser veraz y actualizada.\n\n'
                    '4. Publicación de Contenido\n'
                    'Podemos moderar o remover contenido que infrinja estos términos.\n\n'
                    '5. Uso Adecuado\n'
                    'Se prohíbe el uso fraudulento o que afecte a terceros.\n\n'
                    '6. Responsabilidad\n'
                    'PetfyCo no se responsabiliza por acuerdos entre usuarios fuera de la app.\n\n'
                    '7. Modificaciones\n'
                    'Podremos actualizar estos términos.\n\n'
                    '8. Legislación Aplicable\n'
                    'Colombia.\n\n'
                    '9. Contacto\n'
                    'Sección de ayuda.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: PetfyButton(
                        text: 'Aceptar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
