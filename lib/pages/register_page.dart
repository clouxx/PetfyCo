import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/petfy_widgets.dart';
import '../ui/map_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  final _phone = TextEditingController();

  // Ubicación
  final List<String> _deptNames = [];
  final List<String> _cityNames = [];
  String? _deptSel;
  String? _citySel;

  // Prefijo fijo para Colombia
  final String _countryCode = '+57';

  // Mapa
  LatLng? _pickedPoint;
  double? _lat;
  double? _lng;

  bool _ob1 = true;
  bool _ob2 = true;
  bool _sending = false;
  bool _accepted = false;

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
      final data = await sb
          .from('departments')
          .select('name')
          .order('name', ascending: true);
      
      setState(() {
        _deptNames.clear();
        _deptNames.addAll(data.map((e) => e['name'] as String));
      });
    } catch (e) {
      debugPrint('Error cargando departamentos: $e');
    }
  }

  Future<void> _loadCities(String dept) async {
    try {
      final sb = Supabase.instance.client;
      final data = await sb
          .from('cities')
          .select('name')
          .eq('department_name', dept)
          .order('name', ascending: true);
      
      setState(() {
        _cityNames.clear();
        _cityNames.addAll(data.map((e) => e['name'] as String));
      });
    } catch (e) {
      debugPrint('Error cargando ciudades: $e');
    }
  }

  List<DropdownMenuItem<String>> _ddItems(List<String> src) {
    return src
        .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
        .toList();
  }

  Future<void> _pickOnMap() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => MapPickerDialog(initial: _pickedPoint),
    );
    if (result != null) {
      setState(() {
        _pickedPoint = result;
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor activa los servicios de ubicación'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _pickedPoint = LatLng(_lat!, _lng!);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación obtenida exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_sending) return;

    // Validar términos
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y Condiciones'),
        ),
      );
      return;
    }

    // Validar departamento y ciudad
    if (_deptSel == null || _citySel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona departamento y ciudad'),
        ),
      );
      return;
    }

    // Validar formulario
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;
      final email = _email.text.trim();
      final pass = _pass1.text;
      final name = _name.text.trim();
      final phone = _phone.text.trim();

      // Registrar usuario
      final auth = await sb.auth.signUp(
        email: email,
        password: pass,
      );
      
      final uid = auth.user?.id;
      if (uid != null) {
        // Crear perfil
        await sb.from('profiles').upsert({
          'id': uid,
          'name': name,
          'email': email,
          'country_code': _countryCode,
          'phone': phone,
          'province': _deptSel,
          'city': _citySel,
          'lat': _lat,
          'lng': _lng,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Revisa tu correo.'),
          backgroundColor: Colors.green,
        ),
      );
      
      context.go('/login'); // ✅ CORREGIDO
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrarse: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: PetfyCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Image.asset(
                        'assets/logo/petfyco_logo_full.png',
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Nombre
                    PetfyTextField(
                      controller: _name,
                      hint: 'Nombre completo',
                      prefix: const Icon(Icons.person_outline),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) 
                              ? 'Ingresa tu nombre' 
                              : null,
                    ),
                    const SizedBox(height: 10),

                    // Email
                    PetfyTextField(
                      controller: _email,
                      hint: 'Correo electrónico',
                      keyboardType: TextInputType.emailAddress,
                      prefix: const Icon(Icons.mail_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!v.contains('@')) {
                          return 'Email inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Contraseña
                    PetfyTextField(
                      controller: _pass1,
                      hint: 'Contraseña',
                      obscureText: _ob1,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(
                          _ob1 ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _ob1 = !_ob1),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                    ),
                    const SizedBox(height: 10),

                    // Confirmación
                    PetfyTextField(
                      controller: _pass2,
                      hint: 'Confirmar contraseña',
                      obscureText: _ob2,
                      prefix: const Icon(Icons.lock_reset),
                      suffix: IconButton(
                        icon: Icon(
                          _ob2 ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _ob2 = !_ob2),
                      ),
                      validator: (v) =>
                          (v != _pass1.text) ? 'No coincide' : null,
                    ),
                    const SizedBox(height: 16),

                    // Teléfono
                    PetfyTextField(
                      controller: _phone,
                      hint: 'Número de teléfono (ej: 3001234567)',
                      keyboardType: TextInputType.phone,
                      prefix: Text(
                        '  $_countryCode ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa tu teléfono';
                        }
                        if (v.length < 10) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Departamento / Ciudad
                    Row(
                      children: [
                        Expanded(
                          child: PetfyDropdown<String>(
                            value: _deptSel,
                            items: _ddItems(_deptNames),
                            hint: 'Departamento',
                            onChanged: (val) {
                              setState(() {
                                _deptSel = val;
                                _citySel = null;
                                _cityNames.clear();
                              });
                              if (val != null) _loadCities(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PetfyDropdown<String>(
                            value: _citySel,
                            items: _ddItems(_cityNames),
                            hint: 'Ciudad/Municipio',
                            onChanged: (val) => setState(() => _citySel = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ubicación
                    Row(
                      children: [
                        Expanded(
                          child: PetfyButton(
                            text: _pickedPoint == null
                                ? '📍 Elegir en mapa'
                                : '📍 Cambiar ubicación',
                            onPressed: _pickOnMap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PetfyButton(
                            text: '📡 Mi ubicación',
                            onPressed: _getCurrentLocation,
                          ),
                        ),
                      ],
                    ),
                    if (_lat != null && _lng != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_lat!.toStringAsFixed(6)}  '
                        'Lng: ${_lng!.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Términos
                    Row(
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                        ),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Acepto '),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text(
                                        'Términos y Condiciones',
                                      ),
                                      content: const SingleChildScrollView(
                                        child: Text(
                                          'Aquí van tus términos y condiciones...',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cerrar'),
                                        )
                                      ],
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Términos y Condiciones',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Botón
                    PetfyButton(
                      text: 'Registrarse',
                      loading: _sending,
                      onPressed: _sending ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    
                    Center(
                      child: PetfyLink(
                        text: '¿Ya tienes cuenta? Inicia sesión',
                        onTap: () => context.go('/login'), // ✅ CORREGIDO
                      ),
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
