import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';
import 'package:petfyco/ui/map_picker.dart'; // Asegúrate de que exista y se llame MapPickerDialog
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Estado
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _sending = false;

  // Prefijo país (solo Colombia +57 como pediste)
  String _countryCode = '+57 (Colombia)';

  // Departamentos / ciudades (cargados desde BD)
  String? _selectedDepto;
  String? _selectedCity;
  List<String> _deptNames = [];
  List<String> _cityNames = [];

  // Mapa / ubicación
  LatLng? _picked;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadDepartamentos();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartamentos() async {
    try {
      final res =
          await Supabase.instance.client.from('departments').select('name');
      final names = (res as List)
          .map((e) => (e['name'] as String).trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() => _deptNames = names);
    } catch (_) {
      // opcional: mostrar snackbar de error
    }
  }

  Future<void> _loadCitiesFor(String depto) async {
    try {
      final res = await Supabase.instance.client
          .from('cities')
          .select('name')
          .eq('department_name', depto);
      final names = (res as List)
          .map((e) => (e['name'] as String).trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() => _cityNames = names);
    } catch (_) {
      // opcional: mostrar snackbar de error
    }
  }

  Future<void> _pickOnMap() async {
    final result = await showDialog<LatLng>(
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
      _picked = LatLng(pos.latitude, pos.longitude);
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;

    if (_passCtrl.text.trim() != _confirmCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }
    if (_selectedDepto == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona departamento y ciudad')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // 1) Crear usuario (Supabase auth)
      final auth = Supabase.instance.client.auth;
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();
      final name = _nameCtrl.text.trim();

      final signUpRes = await auth.signUp(
        email: email,
        password: pass,
        // Si usas email confirm, considera el redirectTo
      );

      final user = signUpRes.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // 2) Upsert perfil
      await Supabase.instance.client.rpc('upsert_profile', params: {
        'p_id': user.id,
        'p_name': name,
        'p_email': email,
        'p_country_code': '+57',
        'p_phone': _phoneCtrl.text.trim(),
        'p_province': _selectedDepto!,
        'p_city': _selectedCity!,
        'p_lat': _lat,
        'p_lng': _lng,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/petfyco_logo_full.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(Icons.pets, size: 64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Registrarse',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta para ayudar y adoptar mascotas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  PetfyCard(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Nombre
                          PetfyTextField(
                            controller: _nameCtrl,
                            hint: 'Nombre completo',
                            prefix: const Icon(Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa tu nombre'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Correo
                          PetfyTextField(
                            controller: _emailCtrl,
                            hint: 'Correo electrónico',
                            keyboardType: TextInputType.emailAddress,
                            prefix: const Icon(Icons.mail_outline),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Ingresa tu correo';
                              if (!t.contains('@')) {
                                return 'Correo inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Contraseña
                          PetfyTextField(
                            controller: _passCtrl,
                            hint: 'Contraseña',
                            obscureText: _obscure1,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(_obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6)
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Confirmación
                          PetfyTextField(
                            controller: _confirmCtrl,
                            hint: 'Confirmar contraseña',
                            obscureText: _obscure2,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(_obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                            ),
                            validator: (v) => (v ?? '') != _passCtrl.text
                                ? 'No coincide'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Teléfono (prefijo + número)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                flex: 2,
                                child: PetfyDropdown<String>(
                                  hint: 'Prefijo',
                                  value: _countryCode,
                                  items: const [
                                    DropdownMenuItem(
                                      value: '+57 (Colombia)',
                                      child: Text('+57 (Colombia)'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _countryCode = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 5,
                                child: PetfyTextField(
                                  controller: _phoneCtrl,
                                  hint: 'Número de teléfono',
                                  keyboardType: TextInputType.phone,
                                  prefix: const Icon(Icons.phone_outlined),
                                  validator: (v) => (v == null ||
                                          v.trim().isEmpty ||
                                          v.trim().length < 7)
                                      ? 'Ingresa un teléfono válido'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Departamento
                          PetfyDropdown<String>(
                            hint: 'Departamento',
                            value: _selectedDepto,
                            items: _deptNames
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedDepto = v;
                                _selectedCity = null;
                                _cityNames = [];
                              });
                              if (v != null) {
                                _loadCitiesFor(v);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Ciudad
                          PetfyDropdown<String>(
                            hint: 'Ciudad / Municipio',
                            value: _selectedCity,
                            items: _cityNames
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCity = v),
                          ),
                          const SizedBox(height: 12),

                          // Ubicación (mapa)
                          Row(
                            children: [
                              Expanded(
                                child: PetfyButton(
                                  text: '🗺️ Elegir en el mapa',
                                  onPressed: () => _pickOnMap(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PetfyButton(
                                  text: '📡 Usar mi ubicación actual',
                                  onPressed: () => _useMyLocation(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _picked == null
                                  ? 'Sin ubicación seleccionada'
                                  : 'Ubicación: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          // Términos (marcar y ver)
                          Row(
                            children: [
                              Checkbox(
                                value: true,
                                onChanged: (_) {},
                              ),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('Acepto los '),
                                    PetfyLink(
                                      text: 'Términos y Condiciones',
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                                'Términos y Condiciones'),
                                            content: const SingleChildScrollView(
                                              child: Text(
                                                  'Contenido de términos y condiciones…'),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: const Text('Cerrar'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          PetfyButton(
                            text: _sending ? 'Creando…' : 'Crear cuenta',
                            onPressed: _sending ? null : () => _submit(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿Ya tienes cuenta? '),
                      PetfyLink(
                        text: 'Inicia sesión',
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
    );
  }
}
