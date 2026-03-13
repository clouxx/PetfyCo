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
  String? _avatarUrl;

  List<Map<String, dynamic>> _addresses = [];

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

          final rawAddresses = profile['delivery_addresses'];
          if (rawAddresses != null) {
            _addresses = List<Map<String, dynamic>>.from(rawAddresses as List);
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

  Future<void> _saveAddresses() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    await _sb.from('profiles').update({'delivery_addresses': _addresses}).eq('id', user.id);
  }

  Future<void> _addOrEditAddress({Map<String, dynamic>? existing, int? index}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddressFormDialog(initial: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _addresses[index] = result;
      } else {
        _addresses.add(result);
      }
    });
    try {
      await _saveAddresses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteAddress(int index) async {
    setState(() => _addresses.removeAt(index));
    try {
      await _saveAddresses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
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
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _BillingSheet(sb: _sb),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Mis Direcciones ──────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mis Direcciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () => _addOrEditAddress(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Agregar'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_addresses.isEmpty)
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
                              subtitle: const Text('Para recibir pedidos de la tienda'),
                              trailing: const Icon(Icons.add, color: AppColors.purple),
                              onTap: () => _addOrEditAddress(),
                            ),
                          )
                        else
                          ...List.generate(_addresses.length, (i) {
                            final addr = _addresses[i];
                            final alias = addr['alias'] as String? ?? 'Dirección';
                            final direccion = addr['direccion'] as String? ?? '';
                            final barrio = addr['barrio'] as String? ?? '';
                            final ciudad = addr['ciudad'] as String? ?? '';
                            final indicaciones = addr['indicaciones'] as String? ?? '';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purpleGlass),
                                      child: Icon(
                                        alias == 'Casa' ? Icons.home_outlined : alias == 'Trabajo' ? Icons.work_outline : Icons.location_on_outlined,
                                        color: AppColors.purple,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(alias, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(direccion, style: const TextStyle(fontSize: 13)),
                                          if (barrio.isNotEmpty || ciudad.isNotEmpty)
                                            Text(
                                              [barrio, ciudad].where((s) => s.isNotEmpty).join(', '),
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                            ),
                                          if (indicaciones.isNotEmpty)
                                            Text(indicaciones, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.purple),
                                          onPressed: () => _addOrEditAddress(existing: addr, index: i),
                                          tooltip: 'Editar',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          onPressed: () => _deleteAddress(i),
                                          tooltip: 'Eliminar',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
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
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Cambiar rol'),
                            content: Text(
                              nuevoRol == 'publicador'
                                  ? 'Cambiarás a Publicador: podrás dar mascotas en adopción y reportar mascotas perdidas.'
                                  : 'Cambiarás a Buscador: verás mascotas para adoptar y reportarás mascotas encontradas.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
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

// ─────────────────────────────────────────────────────────────────────────────
// Formulario para agregar / editar una dirección de entrega
// ─────────────────────────────────────────────────────────────────────────────
class _AddressFormDialog extends StatefulWidget {
  const _AddressFormDialog({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<_AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _direccionCtrl = TextEditingController();
  final _barrioCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _indicacionesCtrl = TextEditingController();

  String _alias = 'Casa';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final d = widget.initial!;
      _alias = d['alias'] as String? ?? 'Casa';
      _direccionCtrl.text = d['direccion'] as String? ?? '';
      _barrioCtrl.text = d['barrio'] as String? ?? '';
      _ciudadCtrl.text = d['ciudad'] as String? ?? '';
      _indicacionesCtrl.text = d['indicaciones'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _barrioCtrl.dispose();
    _ciudadCtrl.dispose();
    _indicacionesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.purple),
                    const SizedBox(width: 8),
                    Text(
                      widget.initial == null ? 'Nueva dirección' : 'Editar dirección',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Alias chips
                Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Casa', 'Trabajo', 'Otro'].map((label) {
                    final selected = _alias == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _alias = label),
                      selectedColor: AppColors.purpleGlass,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.purple : Colors.black87,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Dirección
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dirección*',
                    hintText: 'Ej: Calle 45 # 12-34 Apto 201',
                    prefixIcon: const Icon(Icons.home_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                // Barrio
                TextFormField(
                  controller: _barrioCtrl,
                  decoration: InputDecoration(
                    labelText: 'Barrio / Sector',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Ciudad
                TextFormField(
                  controller: _ciudadCtrl,
                  decoration: InputDecoration(
                    labelText: 'Ciudad*',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),

                // Indicaciones
                TextFormField(
                  controller: _indicacionesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Indicaciones adicionales',
                    hintText: 'Ej: Portón azul, llamar al llegar',
                    prefixIcon: const Icon(Icons.info_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(context, {
                          'alias': _alias,
                          'direccion': _direccionCtrl.text.trim(),
                          'barrio': _barrioCtrl.text.trim(),
                          'ciudad': _ciudadCtrl.text.trim(),
                          'indicaciones': _indicacionesCtrl.text.trim(),
                        });
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Guardar'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────── Sheet Datos de Facturación ──────────────────────────────────────

class _BillingSheet extends StatefulWidget {
  const _BillingSheet({required this.sb});
  final SupabaseClient sb;

  @override
  State<_BillingSheet> createState() => _BillingSheetState();
}

class _BillingSheetState extends State<_BillingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nitCtrl = TextEditingController();
  final _razonCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBilling();
  }

  @override
  void dispose() {
    _nitCtrl.dispose();
    _razonCtrl.dispose();
    _telCtrl.dispose();
    _dirCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBilling() async {
    final me = widget.sb.auth.currentUser?.id;
    if (me == null) { setState(() => _loading = false); return; }
    try {
      final data = await widget.sb
          .from('billing_data')
          .select()
          .eq('user_id', me)
          .maybeSingle();
      if (data != null) {
        _nitCtrl.text = data['nit_cedula'] ?? '';
        _razonCtrl.text = data['razon_social'] ?? '';
        _telCtrl.text = data['telefono'] ?? '';
        _dirCtrl.text = data['direccion'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final me = widget.sb.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _saving = true);
    try {
      await widget.sb.from('billing_data').upsert({
        'user_id': me,
        'nit_cedula': _nitCtrl.text.trim(),
        'razon_social': _razonCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
        'direccion': _dirCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos de facturación guardados')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 16),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Agregar Datos de Facturación',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _BillingField(
                      label: 'NIT o Cédula',
                      controller: _nitCtrl,
                      hint: 'Ingresa NIT o Cédula',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _BillingField(
                      label: 'Razón Social',
                      controller: _razonCtrl,
                      hint: 'Ingresa razón social',
                    ),
                    const SizedBox(height: 14),
                    _BillingField(
                      label: 'Teléfono',
                      controller: _telCtrl,
                      hint: 'Número de teléfono',
                      keyboardType: TextInputType.phone,
                      prefix: '🇨🇴 +57',
                    ),
                    const SizedBox(height: 14),
                    _BillingField(
                      label: 'Dirección',
                      controller: _dirCtrl,
                      hint: 'Ingresa tu dirección',
                    ),
                    const SizedBox(height: 14),
                    _BillingField(
                      label: 'Correo Electrónico',
                      controller: _emailCtrl,
                      hint: 'correo@ejemplo.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BillingField extends StatelessWidget {
  const _BillingField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.prefix,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix != null ? '$prefix  ' : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple),
            ),
          ),
        ),
      ],
    );
  }
}
