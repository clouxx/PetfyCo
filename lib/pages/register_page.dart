import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';
import 'package:petfyco/ui/map_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String _countryCode = '+57 (Colombia)';
  String? _dept;
  String? _city;

  LatLng? _picked;
  double? _lat;
  double? _lng;

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _sending = false;
  bool _terms = false;

  // datos desde BD (ajusta con tus queries reales)
  List<String> _deptNames = [];
  List<String> _cityNames = [];

  @override
  void initState() {
    super.initState();
    _loadDeps();
  }

  Future<void> _loadDeps() async {
    // Carga departamentos desde Supabase
    // Asumo tablas public.departments(name) y public.cities(name, dept_name)
    final sb = Supabase.instance.client;

    final deps = await sb.from('departments').select<List<Map<String, dynamic>>>('name');
    _deptNames = deps.map((e) => (e['name'] as String)).toList();
    _deptNames.sort((a, b) => a.compareTo(b)); // ascendente

    setState(() {});
  }

  Future<void> _loadCities(String deptName) async {
    final sb = Supabase.instance.client;
    final rows = await sb
        .from('cities')
        .select<List<Map<String, dynamic>>>('name')
        .eq('dept_name', deptName);

    _cityNames = rows.map((e) => (e['name'] as String)).toList();
    _cityNames.sort((a, b) => a.compareTo(b)); // ascendente
    setState(() {});
  }

  Future<void> _pickOnMap() async {
    final result = await showDialog<LatLng?>(
      context: context,
      builder: (_) => MapPickerDialog(initial: _picked),
    );
    if (result != null) {
      setState(() {
        _picked = result;
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acepta los términos')));
      return;
    }
    setState(() => _sending = true);
    try {
      // 1) registro
      final auth = Supabase.instance.client.auth;
      final res = await auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );

      final userId = res.user?.id;
      if (userId == null) throw 'No se pudo registrar';

      // 2) upsert del perfil
      await Supabase.instance.client.rpc('upsert_profile', params: {
        'p_id': userId,
        'p_name': nameCtrl.text.trim(),
        'p_email': emailCtrl.text.trim(),
        'p_country_code': _countryCode,
        'p_phone': phoneCtrl.text.trim(),
        'p_province': _dept,
        'p_city': _city,
        'p_lat': _lat,
        'p_lng': _lng,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );
      context.go('/'); // volver a login
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: PetfyCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 120, height: 120, fit: BoxFit.contain),
                  const SizedBox(height: 8),
                  const Text('Registrarse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  // Nombre
                  PetfyTextField(
                    controller: nameCtrl,
                    label: 'Nombre',
                    prefix: const Icon(Icons.person_outline),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  PetfyTextField(
                    controller: emailCtrl,
                    label: 'Correo electrónico',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Icon(Icons.mail_outline),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Ingresa tu correo';
                      if (!t.contains('@')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Contraseña
                  PetfyTextField(
                    controller: passCtrl,
                    label: 'Contraseña',
                    obscureText: _obscure1,
                    prefix: const Icon(Icons.lock_outline),
                    suffix: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),

                  // Confirmar contraseña
                  PetfyTextField(
                    controller: pass2Ctrl,
                    label: 'Confirmar contraseña',
                    obscureText: _obscure2,
                    prefix: const Icon(Icons.lock_outline),
                    suffix: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                    validator: (v) => (v != passCtrl.text) ? 'No coincide' : null,
                  ),
                  const SizedBox(height: 12),

                  // Teléfono
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PetfyDropdown<String>(
                          value: _countryCode,
                          items: const ['+57 (Colombia)'],
                          label: 'Prefijo',
                          onChanged: (v) => setState(() => _countryCode = v ?? _countryCode),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 10,
                        child: PetfyTextField(
                          controller: phoneCtrl,
                          label: 'Número de teléfono',
                          keyboardType: TextInputType.phone,
                          prefix: const Icon(Icons.phone_outlined),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Departamento
                  PetfyDropdown<String>(
                    value: _dept,
                    items: _deptNames,
                    label: 'Departamento',
                    onChanged: (v) {
                      setState(() {
                        _dept = v;
                        _city = null;
                      });
                      if (v != null) {
                        _loadCities(v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Ciudad
                  PetfyDropdown<String>(
                    value: _city,
                    items: _cityNames,
                    label: 'Ciudad',
                    onChanged: (v) => setState(() => _city = v),
                  ),
                  const SizedBox(height: 12),

                  // Ubicación
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickOnMap,
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            _picked == null
                                ? 'Elegir en el mapa'
                                : 'Lat: ${_picked!.latitude.toStringAsFixed(5)}, Lng: ${_picked!.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Términos
                  Row(
                    children: [
                      Checkbox(
                        value: _terms,
                        onChanged: (v) => setState(() => _terms = v ?? false),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Acepto los '),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Términos y condiciones'),
                                    content: const SingleChildScrollView(
                                      child: Text('Aquí van tus términos...'),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                                    ],
                                  ),
                                );
                              },
                              child: const Text(
                                'términos y condiciones',
                                style: TextStyle(decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botón registrar
                  PetfyButton(
                    text: 'Registrarse',
                    loading: _sending,
                    onPressed: _sending ? null : () => _submit(),
                  ),
                  const SizedBox(height: 8),

                  PetfyLink(
                    text: '¿Ya tienes cuenta? Inicia sesión',
                    onTap: () => context.pop(),
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
