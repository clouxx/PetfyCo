import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:petfyco/widgets/petfy_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petfyco/ui/map_picker.dart';

final _sb = Supabase.instance.client;

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

  // Dropdowns
  String _countryCode = '+57 (Colombia)';
  int? _deptId;
  int? _cityId;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities = [];

  // Ubicación
  LatLng? _picked;
  double? _lat, _lng;

  // Estado
  bool _obsc1 = true, _obsc2 = true, _accept = false, _sending = false;

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
    final res = await _sb
        .from('departments')
        .select()
        .order('name', ascending: true);
    setState(() {
      _departments = (res as List).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _loadCities(int deptId) async {
    final res = await _sb
        .from('cities')
        .select()
        .eq('department_id', deptId)
        .order('name', ascending: true);
    setState(() {
      _cities = (res as List).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _pickOnMap() async {
    final p = await showDialog<LatLng>(
      context: context,
      builder: (_) => MapPickerDialog(initial: _picked),
    );
    if (p != null) {
      setState(() {
        _picked = p;
        _lat = p.latitude;
        _lng = p.longitude;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
      }
      return;
    }
    final pos =
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _picked = LatLng(pos.latitude, pos.longitude);
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  String? _emailVal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Correo inválido';
    }

  String? _passVal(String? v) {
    if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  Future<void> _submit() async {
    if (_sending) return;
    final valid = formKey.currentState?.validate() ?? false;
    if (!valid || !_accept) {
      if (!_accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
        );
      }
      return;
    }
    setState(() => _sending = true);

    // TODO: Supabase signUp + upsert de perfil
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _sending = false);
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Registrarse'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/petfyco_logo_full.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (c, _, __) => const SizedBox(
                        width: 96,
                        height: 96,
                        child: Icon(Icons.pets, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Form(
                    key: formKey,
                    child: PetfyCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Nombre
                          PetfyTextField(
                            controller: nameCtrl,
                            label: 'Nombre',
                            hint: 'Ingresa tu nombre',
                            prefix: const Icon(Icons.person_outline),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),

                          // Correo
                          PetfyTextField(
                            controller: emailCtrl,
                            label: 'Correo electrónico',
                            hint: 'Ingresa tu correo',
                            keyboardType: TextInputType.emailAddress,
                            prefix: const Icon(Icons.mail_outline),
                            validator: _emailVal,
                          ),
                          const SizedBox(height: 12),

                          // Contraseña
                          PetfyTextField(
                            controller: passCtrl,
                            label: 'Contraseña',
                            hint: 'Ingresa tu contraseña',
                            obscureText: _obsc1,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(
                                  _obsc1 ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obsc1 = !_obsc1),
                            ),
                            validator: _passVal,
                          ),
                          const SizedBox(height: 12),

                          // Confirmación
                          PetfyTextField(
                            controller: pass2Ctrl,
                            label: 'Confirmar contraseña',
                            hint: 'Confirma tu contraseña',
                            obscureText: _obsc2,
                            prefix: const Icon(Icons.lock_outline),
                            suffix: IconButton(
                              icon: Icon(
                                  _obsc2 ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obsc2 = !_obsc2),
                            ),
                            validator: (v) =>
                                v == passCtrl.text ? null : 'No coincide',
                          ),
                          const SizedBox(height: 16),

                          // Teléfono (prefijo + número)
                          Row(
                            children: [
                              Expanded(
                                flex: 8,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  style: theme.textTheme.bodyMedium,
                                  menuMaxHeight: 300,
                                  itemHeight: 44,
                                  decoration: const InputDecoration(
                                    labelText: 'Prefijo',
                                    prefixIcon: Icon(Icons.flag_outlined),
                                  ),
                                  value: _countryCode,
                                  items: const [
                                    DropdownMenuItem(
                                        value: '+57 (Colombia)', child: Text('+57 (Colombia)')),
                                  ],
                                  onChanged: (v) => setState(() => _countryCode = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 16,
                                child: PetfyTextField(
                                  controller: phoneCtrl,
                                  label: 'Número de teléfono',
                                  hint: 'Número de teléfono',
                                  keyboardType: TextInputType.phone,
                                  prefix: const Icon(Icons.phone_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Departamento
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            menuMaxHeight: 320,
                            itemHeight: 44,
                            decoration: const InputDecoration(
                              labelText: 'Departamento',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            value: _deptId,
                            items: _departments
                                .map((d) => DropdownMenuItem<int>(
                                      value: d['id'] as int,
                                      child: Text((d['name'] as String).toUpperCase()),
                                    ))
                                .toList(),
                            onChanged: (v) async {
                              setState(() {
                                _deptId = v;
                                _cityId = null;
                                _cities = [];
                              });
                              if (v != null) await _loadCities(v);
                            },
                            validator: (v) => v == null ? 'Selecciona un departamento' : null,
                          ),
                          const SizedBox(height: 12),

                          // Ciudad
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            menuMaxHeight: 320,
                            itemHeight: 44,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            value: _cityId,
                            items: _cities
                                .map((c) => DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text(c['name'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _cityId = v),
                            validator: (v) => v == null ? 'Selecciona una ciudad' : null,
                          ),
                          const SizedBox(height: 16),

                          // Ubicación
                          Text('Mi ubicación',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: PetfyButton(
                                  text: _picked == null
                                      ? '📍 Seleccionar en el mapa'
                                      : '📍 Ubicación seleccionada (${_picked!.latitude.toStringAsFixed(4)}, ${_picked!.longitude.toStringAsFixed(4)})',
                                  onPressed: _pickOnMap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(Icons.my_location_outlined),
                              label: const Text('📡 Usar mi ubicación actual'),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Términos
                          Row(
                            children: [
                              Checkbox(
                                value: _accept,
                                onChanged: (v) => setState(() => _accept = v ?? false),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text('Acepto los '),
                                    PetfyLink(
                                      text: 'términos y condiciones',
                                      onTap: () => showDialog<void>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Términos y condiciones'),
                                          content: const SingleChildScrollView(
                                            child: Text(
                                              'Aquí van tus términos y condiciones…',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('Aceptar'),
                                            ),
                                          ],
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
                          PetfyButton(
                            text: _sending ? 'Registrando…' : 'Registrarme',
                            onPressed: _sending ? null : _submit,
                          ),

                          const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
