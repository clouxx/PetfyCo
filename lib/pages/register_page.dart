import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final phoneCtrl = TextEditingController();

  // ---- Prefijo país (solo Colombia) ----
  String _countryCode = '+57';

  // ---- Departamentos/Ciudades (BD) ----
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities = [];
  int? _selectedDeptId;
  int? _selectedCityId;
  bool _isLoadingDeps = false;
  bool _isLoadingCities = false;

  // ---- Estado de envío / ubicación / términos ----
  bool _isSubmitting = false;
  double? _lat;
  double? _lng;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  // ================== DATA ==================
  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDeps = true);
    try {
      final res =
          await supabase.from('departments').select('id, name').order('name');
      _departments = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      _snack('No se pudieron cargar los departamentos');
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
    } catch (_) {
      _snack('No se pudieron cargar las ciudades');
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  String? _deptNameById(int? id) {
    if (id == null) return null;
    final m =
        _departments.firstWhere((d) => d['id'] == id, orElse: () => {});
    return m.isEmpty ? null : m['name'] as String?;
  }

  String? _cityNameById(int? id) {
    if (id == null) return null;
    final m = _cities.firstWhere((c) => c['id'] == id, orElse: () => {});
    return m.isEmpty ? null : m['name'] as String?;
  }

  // ================== SUBMIT ==================
  Future<void> _onSubmit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_selectedDeptId == null || _selectedCityId == null) {
      _snack('Selecciona departamento y ciudad');
      return;
    }
    if (!_acceptedTerms) {
      _snack('Debes aceptar los términos y condiciones');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // 1) Crear usuario
      final authRes = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      final userId = authRes.user?.id;
      if (userId == null) throw Exception('No se pudo crear el usuario');

      // 2) Guardar perfil
      await supabase.from('profiles').upsert({
        'id': userId,
        'display_name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty
            ? null
            : '$_countryCode ${phoneCtrl.text.trim()}',
        'depto': _deptNameById(_selectedDeptId),
        'municipio': _cityNameById(_selectedCityId),
        'lat': _lat,
        'lng': _lng,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _snack('¡Cuenta creada! Revisa tu correo.');
        Navigator.of(context).pop(); // volver al login
      }
    } catch (e) {
      _snack('Error al registrarse: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const spacing = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset('assets/logo/petfyco_logo_full.png', height: 92),
                  const SizedBox(height: 12),
                  Text('Crear cuenta', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),

                  PetfyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre
                        Text('Nombre', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        PetfyTextField(
                          controller: nameCtrl,
                          hint: 'Ingresa tu nombre',
                          prefix: const Icon(Icons.person_outline),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu nombre'
                                  : null,
                        ),
                        spacing,

                        // Correo
                        Text('Correo electrónico',
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        PetfyTextField(
                          controller: emailCtrl,
                          hint: 'Ingresa tu correo',
                          prefix: const Icon(Icons.mail_outline),
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            final email = (v ?? '').trim();
                            final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(email);
                            return ok ? null : 'Correo inválido';
                          },
                        ),
                        spacing,

                        // Contraseña
                        Text('Contraseña', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        _ObscureField(
                          controller: passCtrl,
                          hint: 'Ingresa tu contraseña',
                          validator: (v) =>
                              (v != null && v.length >= 8)
                                  ? null
                                  : 'Mínimo 8 caracteres',
                        ),
                        spacing,

                        // Confirmar contraseña
                        Text('Confirmar contraseña',
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        _ObscureField(
                          controller: pass2Ctrl,
                          hint: 'Confirma tu contraseña',
                          validator: (v) =>
                              v == passCtrl.text ? null : 'No coincide',
                        ),
                        spacing,

                        // Teléfono
                        Text('Teléfono', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Prefijo fijo 🇨🇴 +57
                            Expanded(
                              flex: 4,
                              child: PetfyDropdown<String>(
                                value: _countryCode,
                                items: const [
                                  DropdownMenuItem(
                                    value: '+57',
                                    child:
                                        Text('🇨🇴  +57 (Colombia)'),
                                  ),
                                ],
                                onChanged: (v) {},
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: PetfyTextField(
                                controller: phoneCtrl,
                                hint: 'Número de teléfono',
                                keyboard: TextInputType.phone,
                                prefix: const Icon(Icons.phone_outlined),
                              ),
                            ),
                          ],
                        ),
                        spacing,

                        // Departamento
                        Text('Departamento',
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        _isLoadingDeps
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              )
                            : PetfyDropdown<int>(
                                value: _selectedDeptId,
                                items: _departments
                                    .map((m) => DropdownMenuItem<int>(
                                          value: m['id'] as int,
                                          child: Text(m['name'] as String),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDeptId = val;
                                  });
                                  if (val != null) _loadCities(val);
                                },
                              ),
                        spacing,

                        // Ciudad
                        Text('Ciudad', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        _isLoadingCities
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              )
                            : PetfyDropdown<int>(
                                value: _selectedCityId,
                                items: _cities
                                    .map((m) => DropdownMenuItem<int>(
                                          value: m['id'] as int,
                                          child: Text(m['name'] as String),
                                        ))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedCityId = val),
                              ),
                        spacing,

                        // Ubicación
                        Text('Mi ubicación', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        PetfyButton(
                          text: _lat != null && _lng != null
                              ? '📍  Ubicación seleccionada ($_lat, $_lng)'
                              : '📍  Seleccionar ubicación en el mapa',
                          onPressed: () {
                            // TODO: integrar mapa real
                            setState(() {
                              _lat = 6.2518;   // Medellín
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
                              onChanged: (v) =>
                                  setState(() => _acceptedTerms = v ?? false),
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
                                        color: theme.colorScheme.primary,
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
                        PetfyButton(
                          text: 'Registrarme',
                          loading: _isSubmitting,
                          onPressed: _onSubmit,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
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
      builder: (_) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: const SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text(
              'Última actualización: 20/06/2025\n\n'
              '1. Descripción del Servicio …\n'
              '2. Aceptación de Términos …\n'
              '3. Registro y Responsabilidad del Usuario …\n'
              '4. Publicación de Contenido …\n'
              '5. Uso Adecuado …\n'
              '6. Responsabilidad …\n'
              '7. Modificaciones …\n'
              '8. Cancelación de Cuenta …\n'
              '9. Legislación Aplicable …\n'
              '10. Contacto …\n',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
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
}

// ===== Campo de contraseña con “ojo” reutilizable =====
class _ObscureField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  const _ObscureField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  State<_ObscureField> createState() => _ObscureFieldState();
}

class _ObscureFieldState extends State<_ObscureField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return PetfyTextField(
      controller: widget.controller,
      hint: widget.hint,
      prefix: const Icon(Icons.lock_outline),
      obscure: _obscure,        // <-- así lo espera PetfyTextField
      validator: widget.validator,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      ),
    );
  }
}
