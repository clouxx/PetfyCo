import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Si moviste el selector de mapa a otro archivo, importa tu widget.
/// Para simplificar, aquí usamos un diálogo mínimo que “simula” un selector
/// y devuelve la coordenada que ya tengas en memoria.
Future<LatLng?> _pickOnMap(BuildContext context, LatLng? initial) async {
  // TODO: Reemplaza por tu MapPicker real (google_maps_flutter / flutter_map)
  return showDialog<LatLng>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Seleccionar en el mapa'),
        content: const Text(
          'Integra tu mapa aquí. Este diálogo solo simula la selección.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              // Devuelve la ubicación inicial o un valor de ejemplo.
              Navigator.of(ctx).pop(initial ?? const LatLng(6.2518, -75.5636));
            },
            child: const Text('Usar ejemplo'),
          ),
        ],
      );
    },
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Datos ubicación/selección
  String _countryCode = '+57 (Colombia)';
  int? _selectedDeptId;
  int? _selectedCityId;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities = [];
  bool _loadingDeps = true;
  bool _loadingCities = false;

  // Mapa
  LatLng? _pickedPoint;
  double? _lat;
  double? _lng;

  bool _acceptTerms = false;
  bool _busy = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDeps = true;
      _departments = [];
    });
    try {
      final supa = Supabase.instance.client;
      final res = await supa
          .from('departments')
          .select('id, name')
          .order('name', ascending: true); // ✅ asc
      _departments = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      _departments = [];
    } finally {
      if (mounted) setState(() => _loadingDeps = false);
    }
  }

  Future<void> _loadCities(int deptId) async {
    setState(() {
      _loadingCities = true;
      _cities = [];
      _selectedCityId = null;
    });
    try {
      final supa = Supabase.instance.client;
      final res = await supa
          .from('cities')
          .select('id, name, department_id')
          .eq('department_id', deptId)
          .order('name', ascending: true); // ✅ asc
      _cities = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      _cities = [];
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _useMyLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicación denegado')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _pickedPoint = LatLng(pos.latitude, pos.longitude);
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _pickOnMapTap() async {
    final p = await _pickOnMap(context, _pickedPoint);
    if (p != null) {
      setState(() {
        _pickedPoint = p;
        _lat = p.latitude;
        _lng = p.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeptId == null || _selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona departamento y ciudad')),
      );
      return;
    }
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final supa = Supabase.instance.client;

      final authRes = await supa.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final uid = authRes.user?.id;
      if (uid == null) {
        throw Exception('No se pudo obtener el usuario');
      }

      // Guarda perfil extendido
      await supa.from('profiles').upsert({
        'id': uid,
        'display_name': _nameCtrl.text.trim(),
        'phone': '${_countryCode.split(' ').first} ${_phoneCtrl.text.trim()}',
        'depto': _departments
            .firstWhere((d) => d['id'] == _selectedDeptId)['name'],
        'municipio':
            _cities.firstWhere((c) => c['id'] == _selectedCityId)['name'],
        'lat': _lat,
        'lng': _lng,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );
      context.go('/login'); // ✅ volver de forma segura
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error inesperado al registrar')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.asset(
                      'assets/logo/petfyco_logo_full.png',
                      height: 86,
                    ),
                  ),
                  Text('Crear cuenta',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),

                  // Nombre
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ingresa tu nombre',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Ingresa tu nombre'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'Ingresa tu correo',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return 'Ingresa tu correo';
                      if (!val.contains('@')) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Contraseña
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure1,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      hintText: 'Mínimo 8 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure1 = !_obscure1),
                        icon: Icon(
                            _obscure1 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8)
                            ? 'Mínimo 8 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // Confirmar contraseña
                  TextFormField(
                    controller: _pass2Ctrl,
                    obscureText: _obscure2,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure2 = !_obscure2),
                        icon: Icon(
                            _obscure2 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) =>
                        (v != _passCtrl.text) ? 'No coincide' : null,
                  ),
                  const SizedBox(height: 16),

                  // Teléfono (prefijo fijo + número)
                  Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: DropdownButtonFormField<String>(
                          value: _countryCode,
                          items: const [
                            DropdownMenuItem(
                              value: '+57 (Colombia)',
                              child: Row(
                                children: [
                                  Text('🇨🇴'),
                                  SizedBox(width: 8),
                                  Text('+57 (Colombia)'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (_) {},
                          decoration: const InputDecoration(
                            labelText: 'Prefijo',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 13,
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Número de teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu teléfono'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Departamento
                  DropdownButtonFormField<int>(
                    value: _selectedDeptId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Departamento',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: _loadingDeps
                        ? const []
                        : _departments
                            .map((d) => DropdownMenuItem<int>(
                                  value: d['id'] as int,
                                  child: Text((d['name'] as String).trim()),
                                ))
                            .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDeptId = val;
                      });
                      if (val != null) _loadCities(val);
                    },
                    validator: (v) =>
                        v == null ? 'Selecciona un departamento' : null,
                  ),
                  const SizedBox(height: 12),

                  // Ciudad
                  DropdownButtonFormField<int>(
                    value: _selectedCityId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: _loadingCities
                        ? const []
                        : _cities
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text((c['name'] as String).trim()),
                                ))
                            .toList(),
                    onChanged: (val) => setState(() {
                      _selectedCityId = val;
                    }),
                    validator: (v) => v == null ? 'Selecciona una ciudad' : null,
                  ),
                  const SizedBox(height: 16),

                  // Ubicación
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mi ubicación',
                        style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.tonalIcon(
                      onPressed: _pickOnMapTap,
                      icon: const Icon(Icons.place_outlined),
                      label: Text(_pickedPoint == null
                          ? 'Seleccionar en el mapa'
                          : 'Ubicación seleccionada (${_pickedPoint!.latitude.toStringAsFixed(4)}, ${_pickedPoint!.longitude.toStringAsFixed(4)})'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _useMyLocation,
                      icon: const Icon(Icons.my_location_outlined),
                      label: const Text('📡 Usar mi ubicación actual'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Términos
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (v) =>
                            setState(() => _acceptTerms = v ?? false),
                      ),
                      Flexible(
                        child: Wrap(
                          children: [
                            const Text('Acepto los '),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title:
                                        const Text('Términos y condiciones'),
                                    content: const SingleChildScrollView(
                                      child: Text(
                                          'Aquí va tu contenido de términos y condiciones…'),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('Aceptar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text(
                                'términos y condiciones',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Botón registrar
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrarme'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/login'), // ✅ sin pop
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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
