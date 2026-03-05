import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import '../ui/map_picker.dart';
import '../widgets/petfy_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
