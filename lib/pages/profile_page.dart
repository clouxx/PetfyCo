import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import '../ui/map_picker.dart';
import '../widgets/petfy_widgets.dart';
import '../theme/app_theme.dart';
import '../providers/role_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final List<Map<String, dynamic>> _departments = [];
  final List<String> _cityNames = [];
  int? _deptId;
  String? _deptName;
  String? _cityName;

  double? _lat;
  double? _lng;
  LatLng? _pickedPoint;
  String? _avatarUrl; // Para mostrar la foto actual

  bool _loading = true;
  bool _saving = false;
  
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      // 1. Load departments
      final deptsData = await _sb.from('departments').select('id, name').order('name', ascending: true);
      _departments.addAll(List<Map<String, dynamic>>.from(deptsData));

      // 2. Load profile
      final user = _sb.auth.currentUser;
      if (user != null) {
        final profile = await _sb.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null) {
          _nameCtrl.text = profile['display_name'] ?? '';
          _emailCtrl.text = profile['email'] ?? user.email ?? '';
          _phoneCtrl.text = profile['phone'] ?? '';
          _deptName = profile['depto'];
          _cityName = profile['municipio'];
          _avatarUrl = profile['avatar_url']; // <--- Carga de la foto
          
          if (_deptName != null) {
            final match = _departments.where((d) => d['name'] == _deptName).toList();
            if (match.isNotEmpty) {
              _deptId = match.first['id'] as int;
              await _loadCities(_deptId!); // populate cities
            }
          }

          if (profile['lat'] != null && profile['lng'] != null) {
            _lat = (profile['lat'] as num).toDouble();
            _lng = (profile['lng'] as num).toDouble();
            _pickedPoint = LatLng(_lat!, _lng!);
          }
        } else {
          _emailCtrl.text = user.email ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCities(int deptId) async {
    try {
      final data = await _sb
          .from('cities')
          .select('name')
          .eq('department_id', deptId)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _cityNames.clear();
          _cityNames.addAll(data.map((e) => e['name'] as String));
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activa la ubicación')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _pickedPoint = LatLng(_lat!, _lng!);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación obtenida'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    
    setState(() => _saving = true);
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return;

      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();
      
      // Asegúrate de tener un bucket llamado 'avatars' en Supabase Storage
      await _sb.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      final publicUrl = _sb.storage.from('avatars').getPublicUrl(path);
      
      await _sb.from('profiles').update({'avatar_url': publicUrl}).eq('id', user.id);
      
      if (mounted) {
        setState(() => _avatarUrl = publicUrl);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deptName == null || _cityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona departamento y ciudad')));
      return;
    }

    setState(() => _saving = true);
    try {
      final user = _sb.auth.currentUser;
      if (user != null) {
        await _sb.from('profiles').upsert({
          'id': user.id,
          'display_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'depto': _deptName,
          'municipio': _cityName,
          'lat': _lat,
          'lng': _lng,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: PetfyCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                child: _avatarUrl == null
                                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _saving ? null : _pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        PetfyTextField(
                          controller: _nameCtrl,
                          hint: 'Nombre completo',
                          prefix: const Icon(Icons.person_outline),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 12),

                        PetfyTextField(
                          controller: _emailCtrl,
                          hint: 'Correo electrónico',
                          prefix: const Icon(Icons.mail_outline),
                          readOnly: true, // El correo no se cambia desde aquí fácilmente en Supabase
                        ),
                        const SizedBox(height: 12),

                        PetfyTextField(
                          controller: _phoneCtrl,
                          hint: 'Número de teléfono',
                          keyboardType: TextInputType.phone,
                          prefix: const Icon(Icons.phone_outlined),
                          validator: (v) => (v == null || v.trim().length < 10) ? 'Número inválido' : null,
                        ),
                        const SizedBox(height: 16),

                        // Departamento / Ciudad
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _deptId,
                                decoration: InputDecoration(
                                  labelText: 'Departamento',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                    final selectedDept = _departments.firstWhere((d) => d['id'] == val);
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                text: _pickedPoint == null ? '📍 Elegir mapa' : '📍 Cambiar',
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
                          Text('Lat: ${_lat!.toStringAsFixed(6)} Lng: ${_lng!.toStringAsFixed(6)}',
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(height: 24),

                        PetfyButton(
                          text: 'Guardar cambios',
                          loading: _saving,
                          onPressed: _saving ? null : _saveProfile,
                        ),
                        const SizedBox(height: 24),

                        // ── Datos de Facturación ─────────────────────
                        Align(alignment: Alignment.centerLeft, child: Text('Datos de Facturación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purpleGlass),
                              child: const Icon(Icons.add_circle_outline, color: AppColors.purple),
                            ),
                            title: const Text('Agregar Datos De Facturación'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente: Datos de facturación'))),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Mis Direcciones ──────────────────────────
                        Align(alignment: Alignment.centerLeft, child: Text('Mis Direcciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purpleGlass),
                              child: const Icon(Icons.location_on_outlined, color: AppColors.purple),
                            ),
                            title: const Text('Agregar Dirección de Entrega'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente: Mis direcciones'))),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Mi rol ──────────────────────────────────
                        Align(alignment: Alignment.centerLeft, child: Text('Mi rol en PetfyCo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        _RolCard(onRolChanged: () => ref.read(rolProvider.notifier).refresh()),
                        const SizedBox(height: 16),

                        // ── Cerrar sesión ────────────────────────────
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _sb.auth.signOut();
                            if (mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 100),

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

class _RolCard extends ConsumerWidget {
  const _RolCard({required this.onRolChanged});
  final VoidCallback onRolChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolAsync = ref.watch(rolProvider);
    final rol = rolAsync.valueOrNull ?? 'buscador';
    final esPublicador = rol == 'publicador';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: esPublicador ? AppColors.orange.withOpacity(0.12) : AppColors.purpleGlass,
                  ),
                  child: Icon(
                    esPublicador ? Icons.campaign : Icons.search,
                    color: esPublicador ? AppColors.orange : AppColors.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esPublicador ? 'Publicador' : 'Buscador',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        esPublicador
                            ? 'Publicas mascotas en adopción o reportas perdidas'
                            : 'Buscas mascotas perdidas o quieres adoptar',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: rolAsync.isLoading
                    ? null
                    : () async {
                        final nuevoRol = esPublicador ? 'buscador' : 'publicador';
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cambiar rol'),
                            content: Text(
                              nuevoRol == 'publicador'
                                  ? 'Cambiarás a Publicador: podrás dar mascotas en adopción y reportar mascotas perdidas.'
                                  : 'Cambiarás a Buscador: verás mascotas para adoptar y reportarás mascotas encontradas.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
                                child: const Text('Cambiar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await ref.read(rolProvider.notifier).setRole(nuevoRol);
                        onRolChanged();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Rol cambiado a ${nuevoRol == 'publicador' ? 'Publicador' : 'Buscador'}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.purple),
                ),
                child: rolAsync.isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'Cambiar a ${esPublicador ? 'Buscador' : 'Publicador'}',
                        style: const TextStyle(color: AppColors.purple),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
