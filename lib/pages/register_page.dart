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
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  final _phone = TextEditingController();

  // Ubicación - ADAPTADO a tu BD
  final List<Map<String, dynamic>> _departments = [];
  final List<String> _cityNames = [];
  int? _deptId; // ID del departamento seleccionado
  String? _deptName; // Nombre del departamento
  String? _cityName; // Nombre de la ciudad

  final String _countryCode = '+57';
  LatLng? _pickedPoint;
  double? _lat;
  double? _lng;

  bool _ob1 = true;
  bool _ob2 = true;
  bool _sending = false;
  bool _accepted = false;
  String _rol = 'buscador'; // 'buscador' | 'publicador'

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

  // ADAPTADO: Cargar departamentos con ID
  Future<void> _loadDepartments() async {
    try {
      final sb = Supabase.instance.client;
      final data = await sb
          .from('departments')
          .select('id, name')
          .order('name', ascending: true);
      
      setState(() {
        _departments.clear();
        _departments.addAll(List<Map<String, dynamic>>.from(data));
      });
    } catch (e) {
      debugPrint('Error cargando departamentos: $e');
    }
  }

  // ADAPTADO: Cargar ciudades por department_id
  Future<void> _loadCities(int deptId) async {
    try {
      final sb = Supabase.instance.client;
      final data = await sb
          .from('cities')
          .select('name')
          .eq('department_id', deptId)
          .order('name', ascending: true);
      
      setState(() {
        _cityNames.clear();
        _cityNames.addAll(data.map((e) => e['name'] as String));
      });
    } catch (e) {
      debugPrint('Error cargando ciudades: $e');
    }
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

    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y Condiciones'),
        ),
      );
      return;
    }

    if (_deptName == null || _cityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona departamento y ciudad'),
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    try {
      final sb = Supabase.instance.client;
      final email = _email.text.trim();
      final pass = _pass1.text;
      final displayName = _name.text.trim();
      final phone = _phone.text.trim();

      // Registrar usuario
      final auth = await sb.auth.signUp(
        email: email,
        password: pass,
      );
      
      final uid = auth.user?.id;
      if (uid != null) {
        // ADAPTADO: Insertar en profiles con TUS columnas
        // Upsert profile — try with rol first, fall back without it if column doesn't exist yet
        try {
          await sb.from('profiles').upsert({
            'id': uid,
            'display_name': displayName,
            'email': email,
            'phone': phone,
            'depto': _deptName,
            'municipio': _cityName,
            'lat': _lat,
            'lng': _lng,
            'rol': _rol,
          });
        } catch (_) {
          await sb.from('profiles').upsert({
            'id': uid,
            'display_name': displayName,
            'email': email,
            'phone': phone,
            'depto': _deptName,
            'municipio': _cityName,
            'lat': _lat,
            'lng': _lng,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Revisa tu correo.'),
          backgroundColor: Colors.green,
        ),
      );
      
      context.go('/login');
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

                    // Departamento / Ciudad - ADAPTADO
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _deptId,
                            decoration: InputDecoration(
                              labelText: 'Departamento',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            items: _departments.map((dept) {
                              return DropdownMenuItem<int>(
                                value: dept['id'] as int,
                                child: Text(dept['name'] as String),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final selectedDept = _departments.firstWhere(
                                  (d) => d['id'] == val,
                                );
                                setState(() {
                                  _deptId = val;
                                  _deptName = selectedDept['name'] as String;
                                  _cityName = null;
                                  _cityNames.clear();
                                });
                                _loadCities(val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _cityName,
                            decoration: InputDecoration(
                              labelText: 'Ciudad',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            items: _cityNames.map((city) {
                              return DropdownMenuItem<String>(
                                value: city,
                                child: Text(city),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _cityName = val),
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

                    // Rol
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Cómo usarás PetfyCo?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RolOption(
                      value: 'buscador',
                      groupValue: _rol,
                      icon: Icons.search,
                      title: 'Quiero adoptar o encontrar mascotas',
                      subtitle: 'Busca mascotas perdidas o en adopción',
                      onChanged: (v) => setState(() => _rol = v!),
                    ),
                    const SizedBox(height: 6),
                    _RolOption(
                      value: 'publicador',
                      groupValue: _rol,
                      icon: Icons.campaign,
                      title: 'Tengo mascotas para publicar',
                      subtitle: 'Dar en adopción o reportar mascota perdida',
                      onChanged: (v) => setState(() => _rol = v!),
                    ),
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
                                          '''Última actualización: 23/10/2025

Bienvenido a PetfyCo. Al utilizar nuestra aplicación móvil, usted acepta los siguientes Términos y Condiciones de uso. Por favor, léalos cuidadosamente.

1. Descripción del Servicio
PetfyCo es una plataforma digital que permite a los usuarios:

Publicar mascotas disponibles para adopción.
Reportar mascotas perdidas o encontradas.
Contactarse con otros usuarios con el fin de ayudar en la localización, adopción o cuidado de animales.

2. Aceptación de Términos
El uso de la aplicación implica la aceptación total de estos Términos y Condiciones. Si no está de acuerdo con ellos, le recomendamos no utilizar la aplicación.

3. Registro y Responsabilidad del Usuario
Para utilizar ciertas funcionalidades, es posible que deba registrarse y proporcionar información veraz y actualizada. Usted es responsable de mantener la confidencialidad de sus credenciales de acceso.

Usted acepta que:

No publicará información falsa, ofensiva o engañosa.
No utilizará la plataforma para fines comerciales sin autorización expresa.
Toda información sobre mascotas deberá ser real, precisa y actualizada.

4. Publicación de Contenido
Usted conserva los derechos sobre el contenido que publique, pero al hacerlo otorga a PetfyCo una licencia gratuita, no exclusiva y mundial para mostrar, distribuir y modificar dicho contenido únicamente con fines relacionados con el funcionamiento de la aplicación.
Nos reservamos el derecho a eliminar contenido que consideremos inapropiado o que infrinja estos Términos.

5. Uso Adecuado
Está prohibido:

Utilizar la app con fines ilegales, fraudulentos o que afecten a terceros.
Suplantar la identidad de otra persona o entidad.
Interferir con el funcionamiento de la app o intentar acceder a áreas restringidas.

6. Responsabilidad
PetfyCo no se responsabiliza por:
La veracidad o exactitud de las publicaciones realizadas por los usuarios.
Acuerdos o transacciones realizadas entre usuarios fuera de la aplicación.
Daños derivados del uso o imposibilidad de uso de la app.

7. Modificaciones
Nos reservamos el derecho de actualizar estos Términos y Condiciones en cualquier momento. Le notificaremos sobre cambios importantes a través de la app o correo electrónico. El uso continuo del servicio implica la aceptación de los términos actualizados.

8. Cancelación de Cuenta
Podemos suspender o cancelar su cuenta si se detecta uso indebido, violación de estos términos o actividades sospechosas.

9. Legislación Aplicable
Estos Términos se regirán por las leyes de Colombia, sin perjuicio de los derechos que le asistan como consumidor bajo la legislación aplicable.

10. Contacto
Si tiene dudas o consultas sobre estos Términos, puede contactarnos en:

Correo electrónico: support@petfyco.org

Teléfono de contacto: +573177931145''',
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
                        onTap: () => context.go('/login'),
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

class _RolOption extends StatelessWidget {
  const _RolOption({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });
  final String value;
  final String groupValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final color = selected ? const Color(0xFF7C3AED) : Colors.grey.shade400;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED).withOpacity(0.06) : Colors.transparent,
          border: Border.all(color: selected ? const Color(0xFF7C3AED) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF7C3AED),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? const Color(0xFF7C3AED) : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
