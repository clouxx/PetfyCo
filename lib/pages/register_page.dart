// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/petfy_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final supabase = Supabase.instance.client;

  // ---- Form ----
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();

  // ---- País (prefijo) fijo por ahora (Colombia +57) ----
  String _countryCode = '+57';

  // ---- Departamentos/Ciudades desde BD ----
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities = [];

  int? _selectedDeptId;
  int? _selectedCityId;

  bool _isLoadingDeps = false;
  bool _isLoadingCities = false;
  bool _isSubmitting = false;

  // ---- Ubicación simple (si ya la tienes con mapa, mantén tu lógica) ----
  double? _lat;
  double? _lng;

  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  // =============== DATA =================

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDeps = true);
    try {
      final res = await supabase.from('departments').select('id, name').order('name');
      _departments = List<Map<String, dynamic>>.from(res as List);
      // Si ya hay un seleccionado, refresca ciudades
      if (_selectedDeptId != null) {
        await _loadCities(_selectedDeptId!);
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los departamentos')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDeps = false);
    }
  }

  Future<void> _loadCities(int departmentId) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCityId = null;
    });
    try {
      final res = await supabase
          .from('cities')
          .select('id, name')
          .eq('department_id', departmentId)
          .order('name');
      _cities = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error loading cities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar las ciudades')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  String? _deptNameById(int? id) {
    if (id == null) return null;
    final m = _departments.firstWhere((d) => d['id'] == id, orElse: () => {});
    return (m.isNotEmpty) ? (m['name'] as String?) : null;
    }

  String? _cityNameById(int? id) {
    if (id == null) return null;
    final m = _cities.firstWhere((c) => c['id'] == id, orElse: () => {});
    return (m.isNotEmpty) ? (m['name'] as String?) : null;
  }

  // =============== SUBMIT =================

  Future<void> _onSubmit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selectedDeptId == null || _selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona departamento y ciudad')),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // 1) crear user en auth
      final authRes = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      final userId = authRes.user?.id;
      if (userId == null) {
        throw Exception('No se pudo crear el usuario.');
      }

      // 2) upsert perfil (usa tu función SQL si la tienes; aquí simple insert/update)
      await supabase.from('profiles').upsert({
        'id': userId,
        'display_name': nameCtrl.text.trim(),
        'phone': null, // si agregas teléfono, ajusta aquí
        'depto': _deptNameById(_selectedDeptId),
        'municipio': _cityNameById(_selectedCityId),
        'lat': _lat,
        'lng': _lng,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada! Revisa tu correo.')),
        );
        Navigator.of(context).pop(); // volver a login
      }
    } catch (e) {
      debugPrint('Register error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrarse: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // =============== UI =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = const SizedBox(height: 16);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Registrarse'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/logo/petfyco_logo_full.png',
                    height: 96,
                  ),
                  const SizedBox(height: 12),

                  // Card contenedora
                  PetfyCard(
                    child: Column(
                      children: [
                        // Nombre
                        PetfyTextField(
                          controller: nameCtrl,
                          label: 'Nombre',
                          prefix: const Icon(Icons.person_outline),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                        ),
                        spacing,

                        // Correo
                        PetfyTextField(
                          controller: emailCtrl,
                          label: 'Correo electrónico',
                          prefix: const Icon(Icons.mail_outline),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final email = v?.trim() ?? '';
                            final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
                            return ok ? null : 'Correo inválido';
                          },
                        ),
                        spacing,

                        // Contraseña
                        StatefulBuilder(
                          builder: (context, setSB) {
                            bool obscure = true;
                            return PetfyTextField(
                              controller: passCtrl,
                              label: 'Contraseña',
                              prefix: const Icon(Icons.lock_outline),
                              obscureText: obscure,
                              minLength: 8,
                              validator: (v) =>
                                  (v != null && v.length >= 8) ? null : 'Mínimo 8 caracteres',
                              suffix: IconButton(
                                onPressed: () {
                                  obscure = !obscure;
                                  setSB(() {});
                                },
                                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              ),
                            );
                          },
                        ),
                        spacing,

                        // Confirmar contraseña
                        StatefulBuilder(
                          builder: (context, setSB) {
                            bool obscure = true;
                            return PetfyTextField(
                              controller: pass2Ctrl,
                              label: 'Confirmar contraseña',
                              prefix: const Icon(Icons.lock_outline),
                              obscureText: obscure,
                              validator: (v) =>
                                  v == passCtrl.text ? null : 'No coincide',
                              suffix: IconButton(
                                onPressed: () {
                                  obscure = !obscure;
                                  setSB(() {});
                                },
                                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              ),
                            );
                          },
                        ),
                        spacing,

                        // País (prefijo)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PetfyDropdown<String>(
                                value: _countryCode,
                                items: const ['+57', '+593', '+58', '+51'],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _countryCode = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Teléfono - si lo quieres visible, añade un TextEditingController para phone
                            const Expanded(
                              flex: 7,
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                        spacing,

                        // Departamento
                        _isLoadingDeps
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : PetfyDropdown<int>(
                                value: _selectedDeptId,
                                items: _departments.map<int>((m) => m['id'] as int).toList(),
                                itemBuilder: (val) =>
                                    _departments.firstWhere((d) => d['id'] == val)['name']
                                        as String,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDeptId = val;
                                  });
                                  if (val != null) _loadCities(val);
                                },
                              ),
                        spacing,

                        // Ciudad
                        _isLoadingCities
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : PetfyDropdown<int>(
                                value: _selectedCityId,
                                items: _cities.map<int>((m) => m['id'] as int).toList(),
                                itemBuilder: (val) =>
                                    _cities.firstWhere((c) => c['id'] == val)['name'] as String,
                                onChanged: (val) => setState(() => _selectedCityId = val),
                              ),
                        spacing,

                        // Ubicación (placeholder botón)
                        PetfyButton(
                          text: _lat != null && _lng != null
                              ? 'Ubicación seleccionada ($_lat, $_lng)'
                              : 'Seleccionar ubicación en el mapa',
                          onPressed: () async {
                            // TODO: abre tu mapa. Por ahora guardamos un mock:
                            setState(() {
                              _lat = 6.2518;
                              _lng = -75.5636;
                            });
                          },
                        ),
                        spacing,

                        // Términos
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                            ),
                            Flexible(
                              child: Wrap(
                                children: [
                                  const Text('Acepto los '),
                                  GestureDetector(
                                    onTap: _showTerms,
                                    child: Text(
                                      'términos y condiciones',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        spacing,

                        // Submit
                        PetfyButton(
                          text: 'Registrarme',
                          onPressed: _isSubmitting ? null : _onSubmit,
                          loading: _isSubmitting,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  PetfyLink(
                    text: '¿Ya tienes cuenta? Inicia sesión',
                    onTap: () => Navigator.of(context).pop(),
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
      builder: (_) {
        return AlertDialog(
          title: const Text('Términos y Condiciones'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Última actualización: 20/06/2025\n\n'
                    '1. Descripción del Servicio\n'
                    '… (coloca aquí tu texto completo de T&C) …\n\n'
                    '2. Aceptación de Términos\n'
                    '…\n\n'
                    '3. Registro y Responsabilidad del Usuario\n'
                    '…\n\n'
                    '4. Publicación de Contenido\n'
                    '…\n\n'
                    '5. Uso Adecuado\n'
                    '…\n\n'
                    '6. Responsabilidad\n'
                    '…\n\n'
                    '7. Modificaciones\n'
                    '…\n\n'
                    '8. Cancelación de Cuenta\n'
                    '…\n\n'
                    '9. Legislación Aplicable\n'
                    '…\n\n'
                    '10. Contacto\n'
                    '…',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }
}
