import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Textos
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  final _phone = TextEditingController();

  // ubicación / listas
  final List<String> _deptNames = [];
  final List<String> _cityNames = [];
  String? _deptSel;
  String? _citySel;

  // prefijo (solo Colombia)
  final String _countryCode = '+57 (Colombia)';

  // mapa
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
      // data es List<dynamic> con maps
      _deptNames
        ..clear()
        ..addAll(data.map((e) => (e['name'] as String)).toList());
      setState(() {});
    } catch (e) {
      // no rompas la pantalla si falla
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
      _cityNames
        ..clear()
        ..addAll(data.map((e) => (e['name'] as String)).toList());
      setState(() {});
    } catch (e) {
      // ignora para no romper UI
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

  Future<void> _submit() async {
    if (_sending) return;
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar Términos y Condiciones')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;
      final email = _email.text.trim();
      final pass = _pass1.text;
      final name = _name.text.trim();
      final phone = _phone.text.trim();

      final auth = await sb.auth.signUp(email: email, password: pass);
      final uid = auth.user?.id;
      if (uid != null) {
        await sb.rpc('upsert_profile', params: {
          'p_id': uid,
          'p_name': name,
          'p_email': email,
          'p_country_code': '+57',
          'p_phone': phone,
          'p_province': _deptSel,
          'p_city': _citySel,
          'p_lat': _lat,
          'p_lng': _lng,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Revisa tu correo.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrarse: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _req(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    // encabezado
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
                      validator: (v) => _req(v, 'Ingresa tu nombre'),
                    ),
                    const SizedBox(height: 10),

                    // Email
                    PetfyTextField(
                      controller: _email,
                      hint: 'Correo electrónico',
                      keyboardType: TextInputType.emailAddress,
                      prefix: const Icon(Icons.mail_outline),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Email inválido' : null,
                    ),
                    const SizedBox(height: 10),

                    // Contraseña
                    PetfyTextField(
                      controller: _pass1,
                      hint: 'Contraseña',
                      obscure: _ob1,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        icon: Icon(_ob1 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ob1 = !_ob1),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 10),

                    // Confirmación
                    PetfyTextField(
                      controller: _pass2,
                      hint: 'Confirmar contraseña',
                      obscure: _ob2,
                      prefix: const Icon(Icons.lock_reset),
                      suffix: IconButton(
                        icon: Icon(_ob2 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ob2 = !_ob2),
                      ),
                      validator: (v) =>
                          (v != _pass1.text) ? 'No coincide' : null,
                    ),
                    const SizedBox(height: 16),

                    // Teléfono (prefijo fijo +57)
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: PetfyTextField(
                            controller: TextEditingController(text: _countryCode),
                            hint: 'Prefijo',
                            prefix: const Icon(Icons.flag_outlined),
                            // Solo lectura del prefijo fijo
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 6,
                          child: PetfyTextField(
                            controller: _phone,
                            hint: 'Número de teléfono',
                            keyboardType: TextInputType.phone,
                            prefix: const Icon(Icons.phone_outlined),
                            validator: (v) =>
                                _req(v, 'Ingresa tu teléfono'),
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

                    // Mapa + usar ubicación
                    Row(
                      children: [
                        Expanded(
                          child: PetfyButton(
                            text: _pickedPoint == null
                                ? '📍 Elegir en el mapa'
                                : '📍 Cambiar ubicación',
                            onPressed: () => _pickOnMap(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PetfyButton(
                            text: '📡 Usar mi ubicación actual',
                            onPressed: () async {
                              // Llama a geolocator si lo agregaste en móvil; en web puede no pedir permiso
                              try {
                                // import dinámico simple para no romper si no está en web móvil
                                // (si ya añadiste geolocator en pubspec, puedes importar normal y usarlo)
                                // Aquí dejamos el botón como “hook” para tu implementación real.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Implementa Geolocator en móvil (OK).'),
                                  ),
                                );
                              } catch (_) {}
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_lat != null && _lng != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_lat!.toStringAsFixed(6)}  Lng: ${_lng!.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Términos
                    Row(
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) => setState(() => _accepted = v ?? false),
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
                                      title: const Text('Términos y Condiciones'),
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
                      onPressed: _sending ? null : () => _submit(),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: PetfyLink(
                        text: '¿Ya tienes cuenta? Inicia sesión',
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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
