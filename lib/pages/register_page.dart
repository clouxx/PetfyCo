import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ----- Controllers -----
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ----- Estado UI -----
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;

  // Teléfono
  final String _countryCode = '+57 (Colombia)';

  // Supabase datos
  final _supabase = Supabase.instance.client;

  // Departamentos / ciudades (orden ascendente)
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _selectedDept;
  Map<String, dynamic>? _selectedCity;

  // Ubicación
  double? _lat;
  double? _lng;

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

  // ==========================
  // Supabase: cargar catálogos
  // ==========================
  Future<void> _loadDepartments() async {
    try {
      final data = await _supabase
          .from('departments')
          .select('id,name')
          .order('name', ascending: true);
      setState(() {
        _departments = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showSnack('Error al cargar departamentos: $e');
    }
  }

  Future<void> _loadCities(int departmentId) async {
    try {
      final data = await _supabase
          .from('cities')
          .select('id,name,department_id')
          .eq('department_id', departmentId)
          .order('name', ascending: true);

      setState(() {
        _cities = List<Map<String, dynamic>>.from(data);
        _selectedCity = null;
      });
    } catch (e) {
      _showSnack('Error al cargar ciudades: $e');
    }
  }

  // ==========================
  // Ubicación: actual / mapa
  // ==========================
  Future<void> _useMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack('Permiso de ubicación denegado');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _showSnack('No se pudo obtener la ubicación: $e');
    }
  }

  Future<void> _openMapPicker() async {
    final controller = MapController();
    final start = ll.LatLng(_lat ?? 4.7110, _lng ?? -74.0721); // Bogotá por defecto
    ll.LatLng? temp;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.80,
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text('Selecciona tu ubicación en el mapa',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: FlutterMap(
                    mapController: controller,
                    options: MapOptions(
                      initialCenter: start,
                      initialZoom: 12,
                      onTap: (tapPos, p) {
                        temp = p;
                        setState(() {}); // refresca marcador temporal
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.petfyco',
                      ),
                      MarkerLayer(
                        markers: [
                          if (_lat != null && _lng != null && temp == null)
                            Marker(
                              point: ll.LatLng(_lat!, _lng!),
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_pin, size: 36),
                            ),
                          if (temp != null)
                            Marker(
                              point: temp!,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.place, size: 36),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (temp != null) {
                              setState(() {
                                _lat = temp!.latitude;
                                _lng = temp!.longitude;
                              });
                            }
                            Navigator.pop(context);
                          },
                          child: const Text('Usar esta ubicación'),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================
  // Registro
  // ==========================
  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDept == null) {
      _showSnack('Selecciona el departamento');
      return;
    }
    if (_selectedCity == null) {
      _showSnack('Selecciona la ciudad');
      return;
    }
    if (_lat == null || _lng == null) {
      _showSnack('Selecciona tu ubicación (botón “📡” o “🗺️”)');
      return;
    }

    setState(() => _submitting = true);

    try {
      // 1) Crear usuario
      final res = await _supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final userId = res.user?.id;
      if (userId == null) {
        _showSnack('No se pudo crear la cuenta.');
        setState(() => _submitting = false);
        return;
      }

      // 2) Guardar perfil (usa tu RPC si lo tienes; aquí uso upsert directo)
      await _supabase.from('profiles').upsert({
        'id': userId,
        'display_name': _nameCtrl.text.trim(),
        'phone': '$_countryCode ${_phoneCtrl.text.trim()}',
        'depto': _selectedDept!['name'],
        'municipio': _selectedCity!['name'],
        'lat': _lat,
        'lng': _lng,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _showSnack('Cuenta creada. Revisa tu correo para confirmar.');
      if (mounted) Navigator.of(context).pop(); // volver al login
    } catch (e) {
      _showSnack('Error al registrar: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ==========================
  // UI Helpers
  // ==========================
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showTerms() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Bienvenido a PetfyCo. Al registrarte aceptas estos términos...',
                  style: TextStyle(height: 1.3),
                ),
                SizedBox(height: 12),
                Text('1. Descripción del servicio',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Publicar mascotas, reportar perdidas, contactar usuarios...'),
                SizedBox(height: 8),
                Text('2. Responsabilidad',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('La veracidad de publicaciones es responsabilidad de los usuarios.'),
                SizedBox(height: 8),
                Text('3. Uso adecuado',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Prohibido uso fraudulento/ilegal o suplantación.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          )
        ],
      ),
    );
  }

  // ==========================
  // Build
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nombre
          const Text('Nombre'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Ingresa tu nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 16),

          // Correo
          const Text('Correo electrónico'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              hintText: 'Ingresa tu correo',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t);
              return ok ? null : 'Correo no válido';
            },
          ),
          const SizedBox(height: 16),

          // Contraseña
          const Text('Contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure1,
            decoration: InputDecoration(
              hintText: 'Ingresa tu contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
          const SizedBox(height: 16),

          // Confirmar
          const Text('Confirmar contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _pass2Ctrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              hintText: 'Confirma tu contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (v) =>
                v == _passCtrl.text ? null : 'Las contraseñas no coinciden',
          ),
          const SizedBox(height: 20),

          // Teléfono
          const Text('Teléfono'),
          const SizedBox(height: 6),
          Row(
            children: [
              // Prefijo fijo
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  child: const Text('+57 (Colombia)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Número de teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Departamento
          const Text('Departamento'),
          const SizedBox(height: 6),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedDept,
            items: _departments
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedDept = val;
                _selectedCity = null;
                _cities.clear();
              });
              if (val != null) _loadCities(val['id'] as int);
            },
            decoration: const InputDecoration(
              hintText: 'Selecciona departamento',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            validator: (v) => v == null ? 'Selecciona el departamento' : null,
          ),
          const SizedBox(height: 16),

          // Ciudad
          const Text('Ciudad'),
          const SizedBox(height: 6),
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedCity,
            items: _cities
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedCity = val),
            decoration: const InputDecoration(
              hintText: 'Selecciona ciudad',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            validator: (v) => v == null ? 'Selecciona la ciudad' : null,
          ),
          const SizedBox(height: 20),

          // Ubicación
          const Text('Mi ubicación'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('📡 Usar mi ubicación actual'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('🗺️ Elegir en el mapa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_lat != null && _lng != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Ubicación seleccionada (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),

          // Términos
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              const Text('Acepto los '),
              InkWell(
                onTap: _showTerms,
                child: const Text(
                  'términos y condiciones',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón registrar
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _onSubmit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registrarme'),
            ),
          ),
          const SizedBox(height: 16),

          // Ir a login
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ),
        ],
      ),
    );
  }
}
