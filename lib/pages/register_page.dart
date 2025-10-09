// lib/pages/register_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng; // si no usas mapa aún, conserva el tipo
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/petfy_widgets.dart';
import '../theme/app_theme.dart'; // solo por colores/espaciados si los usas en tus widgets

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // UI state
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = false;
  bool _submitting = false;

  // Ubicación (manual/actual)
  LatLng? _pickedPoint;
  double? _lat;
  double? _lng;

  // Catálogos
  final _sb = Supabase.instance.client;
  List<DropdownMenuItem<String>> _deptItems = [];
  List<DropdownMenuItem<String>> _cityItems = [];
  String? _selectedDept;
  String? _selectedCity;

  // Prefijo fijo CO
  final String _countryDisplay = '+57 (Colombia)';
  final String _countryCode = '+57';

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final rows =
          await _sb.from('departments').select('name').order('name', ascending: true);
      final items = (rows as List)
          .map((e) => DropdownMenuItem<String>(
                value: (e['name'] as String),
                child: Text((e['name'] as String)),
              ))
          .toList();
      setState(() {
        _deptItems = items;
      });
    } catch (e) {
      _toast('No pude cargar departamentos');
    }
  }

  Future<void> _loadCities(String deptName) async {
    try {
      // Busca el id por nombre y luego ciudades de ese id (ASC)
      final deptRow = await _sb
          .from('departments')
          .select('id')
          .eq('name', deptName)
          .maybeSingle();

      if (deptRow == null) {
        setState(() {
          _cityItems = [];
          _selectedCity = null;
        });
        return;
      }

      final deptId = deptRow['id'] as int;
      final rows = await _sb
          .from('cities')
          .select('name')
          .eq('department_id', deptId)
          .order('name', ascending: true);

      final items = (rows as List)
          .map((e) => DropdownMenuItem<String>(
                value: (e['name'] as String),
                child: Text((e['name'] as String)),
              ))
          .toList();

      setState(() {
        _cityItems = items;
        _selectedCity = null;
      });
    } catch (e) {
      _toast('No pude cargar ciudades');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ========= BOTÓN: usar ubicación actual (geolocator) =========
  Future<void> _useMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _toast('Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _pickedPoint = LatLng(pos.latitude, pos.longitude);
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _toast('Ubicación: (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})');
    } catch (_) {
      _toast('No pude obtener tu ubicación');
    }
  }

  // ========= Registrar =========
  Future<void> _onSubmit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        pass.isEmpty ||
        pass2.isEmpty ||
        !_agree ||
        _selectedDept == null ||
        _selectedCity == null) {
      _toast('Completa todos los campos y acepta T&C');
      return;
    }
    if (pass != pass2) {
      _toast('Las contraseñas no coinciden');
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1) Sign up
      final res = await _sb.auth.signUp(
        email: email,
        password: pass,
      );
      final user = res.user;
      if (user == null) {
        _toast('No se pudo crear la cuenta');
        setState(() => _submitting = false);
        return;
      }

      // 2) Upsert perfil con helpers de tu schema
      await _sb.rpc('upsert_profile', params: {
        'p_id': user.id,
        'p_name': name,
        'p_email': email,
        'p_country_code': _countryCode,
        'p_phone': phone,
        'p_province': _selectedDept!,
        'p_city': _selectedCity!,
        'p_lat': _lat,
        'p_lng': _lng,
      });

      _toast('Cuenta creada. Revisa tu correo de verificación.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    // Nota: tus widgets Petfy* ya aplican estilos. Los labels los pongo arriba con Text.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const SizedBox(height: 8),
          // Nombre
          const Text('Nombre'),
          const SizedBox(height: 6),
          PetfyTextField(
            controller: _nameCtrl,
            hint: 'Ingresa tu nombre',
            prefix: const Icon(Icons.person_outline),
          ),
          const SizedBox(height: 14),

          // Correo
          const Text('Correo electrónico'),
          const SizedBox(height: 6),
          PetfyTextField(
            controller: _emailCtrl,
            hint: 'Ingresa tu correo',
            keyboard: TextInputType.emailAddress,
            prefix: const Icon(Icons.mail_outline),
          ),
          const SizedBox(height: 14),

          // Contraseña
          const Text('Contraseña'),
          const SizedBox(height: 6),
          PetfyTextField(
            controller: _passCtrl,
            hint: 'Ingresa tu contraseña',
            obscure: _obscure1,
            prefix: const Icon(Icons.lock_outline),
            suffix: IconButton(
              onPressed: () => setState(() => _obscure1 = !_obscure1),
              icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
            ),
          ),
          const SizedBox(height: 14),

          // Confirmar contraseña
          const Text('Confirmar contraseña'),
          const SizedBox(height: 6),
          PetfyTextField(
            controller: _pass2Ctrl,
            hint: 'Confirma tu contraseña',
            obscure: _obscure2,
            prefix: const Icon(Icons.lock_outline),
            suffix: IconButton(
              onPressed: () => setState(() => _obscure2 = !_obscure2),
              icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
            ),
          ),
          const SizedBox(height: 16),

          // Teléfono (prefijo fijo +57)
          const Text('Teléfono'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 7,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  child: Row(
                    children: [
                      const Text('🇨🇴'),
                      const SizedBox(width: 8),
                      Text(_countryDisplay),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 13,
                child: PetfyTextField(
                  controller: _phoneCtrl,
                  hint: 'Número de teléfono',
                  keyboard: TextInputType.phone,
                  prefix: const Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Departamento
          const Text('Departamento'),
          const SizedBox(height: 6),
          PetfyDropdown<String>(
            value: _selectedDept,
            items: _deptItems,
            onChanged: (val) {
              setState(() {
                _selectedDept = val;
                _selectedCity = null;
                _cityItems = [];
              });
              if (val != null) _loadCities(val);
            },
          ),
          const SizedBox(height: 14),

          // Ciudad
          const Text('Ciudad'),
          const SizedBox(height: 6),
          PetfyDropdown<String>(
            value: _selectedCity,
            items: _cityItems,
            onChanged: (val) => setState(() => _selectedCity = val),
          ),
          const SizedBox(height: 16),

          // Botón: usar mi ubicación actual
          PetfyButton(
            text: '📡 Usar mi ubicación actual',
            onPressed: _useMyLocation,
          ),
          const SizedBox(height: 10),

          // Estado de ubicación elegida (si ya hay lat/lng)
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

          // Términos y condiciones
          Row(
            children: [
              Checkbox(
                value: _agree,
                onChanged: (v) => setState(() => _agree = v ?? false),
              ),
              const Text('Acepto los '),
              GestureDetector(
                onTap: _showTerms,
                child: Text(
                  'términos y condiciones',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Botón Registrar
          PetfyButton(
            text: _submitting ? 'Registrando…' : 'Registrarme',
            onPressed: _submitting ? null : _onSubmit,
          ),
          const SizedBox(height: 16),

          // Volver a login
          Center(
            child: GestureDetector(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  // si no hay ruta previa, empuja /login con tu router
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text(
                '¿Ya tienes cuenta? Inicia sesión',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: const SingleChildScrollView(
          child: Text(
              'Aquí van tus términos y condiciones. Puedes pegar el contenido largo que me mostraste.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar'))
        ],
      ),
    );
  }
}
