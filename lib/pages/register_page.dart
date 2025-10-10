import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/map_picker.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  final _phone = TextEditingController();

  bool _sending = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  // Prefijo fijo: Colombia
  String _countryCode = '+57';

  // Ubicación
  LatLng? _picked;
  double? _lat;
  double? _lng;

  // Deptos/Ciudades
  String? _dept;
  String? _city;
  List<String> _deptNames = const [];
  List<String> _cityNames = const [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass1.dispose();
    _pass2.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final sb = Supabase.instance.client;
      // SIN genéricos: retorna List<Map<String,dynamic>>
      final List<dynamic> rows = await sb
          .from('departments')
          .select('name')
          .order('name', ascending: true);

      final names = rows
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .where((e) => e.trim().isNotEmpty)
          .cast<String>()
          .toList();

      setState(() {
        _deptNames = names;
      });
    } catch (e) {
      // No romper UI si falla
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar departamentos: $e')),
      );
    }
  }

  Future<void> _loadCitiesFor(String deptName) async {
    try {
      final sb = Supabase.instance.client;
      final List<dynamic> rows = await sb
          .from('cities')
          .select('name')
          .eq('department_name', deptName)
          .order('name', ascending: true);

      final names = rows
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .where((e) => e.trim().isNotEmpty)
          .cast<String>()
          .toList();

      setState(() {
        _cityNames = names;
        _city = null; // reset
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar ciudades: $e')),
      );
    }
  }

  Future<void> _pickOnMap() async {
    final LatLng? result = await showDialog<LatLng?>(
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

  Future<void> _useCurrentLocation() async {
    // Para Web, sólo funciona si el navegador da permiso; en móvil usa permisos nativos (ya agregaste en Android/iOS).
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicación denegado')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _picked = LatLng(pos.latitude, pos.longitude);
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_dept == null || _city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona departamento y ciudad')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;

      // 1) SignUp
      final email = _email.text.trim();
      final pass = _pass1.text;

      final res = await sb.auth.signUp(email: email, password: pass);
      final uid = res.user?.id;

      if (uid == null) {
        throw 'No se pudo crear el usuario.';
      }

      // 2) Upsert perfil (usa tu función/tabla según tu esquema)
      // Aquí voy contra public.profiles (ajústalo a tu helper si ya lo tienes)
      await sb.from('profiles').upsert({
        'id': uid,
        'display_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'depto': _dept,
        'municipio': _city,
        'lat': _lat,
        'lng': _lng,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Revisa tu correo para confirmar.')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PetfyCard(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo (asegúrate en pubspec.yaml)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Image.asset(
                        'assets/logo/petfyco_logo_full.png',
                        height: 64,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Text('Registrarse',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    // Nombre
                    PetfyTextField(
                      controller: _name,
                      label: 'Nombre',
                      prefix: const Icon(Icons.person_outline),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    PetfyTextField(
                      controller: _email,
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
                      controller: _pass1,
                      label: 'Contraseña',
                      obscureText: _obscure1,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                        tooltip: _obscure1 ? 'Mostrar' : 'Ocultar',
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 12),

                    // Confirmación
                    PetfyTextField(
                      controller: _pass2,
                      label: 'Confirmar contraseña',
                      obscureText: _obscure2,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure2 = !_obscure2),
                        tooltip: _obscure2 ? 'Mostrar' : 'Ocultar',
                      ),
                      validator: (v) =>
                          (v != _pass1.text) ? 'No coincide la contraseña' : null,
                    ),
                    const SizedBox(height: 16),

                    // Teléfono (prefijo fijo +57 y campo número)
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: PetfyDropdown<String>(
                            items: const ['+57 (Colombia)'],
                            value: '+57 (Colombia)',
                            onChanged: (_) {
                              setState(() => _countryCode = '+57');
                            },
                            label: 'Prefijo',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 10,
                          child: PetfyTextField(
                            controller: _phone,
                            label: 'Número de teléfono',
                            keyboardType: TextInputType.phone,
                            prefix: const Icon(Icons.phone_outlined),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Departamento / Ciudad
                    Row(
                      children: [
                        Expanded(
                          child: PetfyDropdown<String>(
                            items: _deptNames,
                            value: _dept,
                            onChanged: (val) {
                              setState(() {
                                _dept = val;
                                _city = null;
                                _cityNames = const [];
                              });
                              if (val != null) _loadCitiesFor(val);
                            },
                            label: 'Departamento',
                            hint: 'Seleccionar',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PetfyDropdown<String>(
                            items: _cityNames,
                            value: _city,
                            onChanged: (val) => setState(() => _city = val),
                            label: 'Ciudad',
                            hint: 'Seleccionar',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ubicación (mapa + usar mi ubicación)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: PetfyButton(
                            text: '🗺️ Elegir en el mapa',
                            onPressed: _pickOnMap,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: PetfyButton(
                            text: '📡 Usar mi ubicación actual',
                            onPressed: kIsWeb
                                ? _useCurrentLocation // en Web también puede funcionar si el navegador da permiso
                                : _useCurrentLocation,
                          ),
                        ),
                        if (_lat != null && _lng != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Lat: ${_lat!.toStringAsFixed(5)}, Lng: ${_lng!.toStringAsFixed(5)}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón Registrar
                    PetfyButton(
                      text: 'Registrarse',
                      loading: _sending,
                      onPressed: _sending ? null : () => _submit(),
                    ),
                    const SizedBox(height: 12),

                    // Volver a login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes cuenta?'),
                        const SizedBox(width: 8),
                        PetfyLink(
                          text: 'Iniciar sesión',
                          onTap: () => context.go('/login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
