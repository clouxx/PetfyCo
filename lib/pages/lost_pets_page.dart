import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class LostPetsPage extends StatefulWidget {
  const LostPetsPage({super.key});

  @override
  State<LostPetsPage> createState() => _LostPetsPageState();
}

class _LostPetsPageState extends State<LostPetsPage>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _mapController = MapController();
  bool _loading = true;
  List<Map<String, dynamic>> _allPets = [];
  List<Map<String, dynamic>> _pets = [];
  String _tabFilter = 'busqueda';
  String _viewMode = 'lista';
  LatLng? _myLocation;

  // Filtros activos
  String? _filterDepto;
  String? _filterCiudad;
  String? _filterEspecie;
  String? _filterTalla;

  int get _activeFilterCount => [_filterDepto, _filterCiudad, _filterEspecie, _filterTalla]
      .where((f) => f != null && f.isNotEmpty).length;

  List<Map<String, dynamic>> get _nearbyPets {
    if (_myLocation == null) return _allPets;
    const maxDistKm = 100.0;
    final result = <Map<String, dynamic>>[];
    for (final pet in _allPets) {
      final lat = (pet['lat'] as num?)?.toDouble();
      final lng = (pet['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final dist = Geolocator.distanceBetween(
              _myLocation!.latitude, _myLocation!.longitude, lat, lng) /
          1000;
      if (dist <= maxDistKm) result.add({...pet, '_distKm': dist});
    }
    result.sort((a, b) =>
        (a['_distKm'] as double).compareTo(b['_distKm'] as double));
    return result;
  }

  // Alertas
  List<Map<String, dynamic>> _alerts = [];
  bool _loadingAlerts = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    setState(() => _loadingAlerts = true);
    try {
      final data = await _sb
          .from('pet_alerts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _alerts = List<Map<String, dynamic>>.from(data));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _createAlert(Map<String, String?> data) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    try {
      await _sb.from('pet_alerts').insert({
        'user_id': user.id,
        if (data['especie'] != null) 'especie': data['especie'],
        if (data['talla'] != null) 'talla': data['talla'],
        if (data['depto'] != null) 'depto': data['depto'],
        if (data['municipio'] != null) 'municipio': data['municipio'],
      });
      await _loadAlerts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta creada'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await _sb.from('pet_alerts').delete().eq('id', alertId);
      await _loadAlerts();
    } catch (_) {}
  }

  Future<void> _openCreateAlertSheet() async {
    final result = await showModalBottomSheet<_LostSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LostSearchSheet(
        sb: _sb,
        title: 'Crear alerta',
        actionLabel: 'Crear alerta',
      ),
    );
    if (result == null) return;
    await _createAlert({
      'especie': result.especie,
      'talla': result.talla,
      'depto': result.depto,
      'municipio': result.ciudad,
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _sb.from('pets').select('''
        id, owner_id, nombre, especie, municipio, depto, estado,
        edad_meses, talla, lat, lng, created_at,
        profiles:owner_id(display_name, phone),
        pet_photos(url, position)
      ''').eq('estado', 'perdido').order('created_at', ascending: false).limit(50);

      setState(() {
        _allPets = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _applyFilters() {
    _pets = _allPets.where((pet) {
      final especie = (pet['especie'] as String? ?? '').toLowerCase();
      final talla = (pet['talla'] as String? ?? '').toLowerCase();
      final depto = (pet['depto'] as String? ?? '').trim().toLowerCase();
      final muni = (pet['municipio'] as String? ?? '').trim().toLowerCase();

      if (_filterEspecie != null && especie != _filterEspecie!.toLowerCase()) return false;
      if (_filterTalla != null && talla != _filterTalla!.toLowerCase()) return false;
      if (_filterDepto != null && _filterDepto!.isNotEmpty && depto != _filterDepto!.trim().toLowerCase()) return false;
      if (_filterCiudad != null && _filterCiudad!.isNotEmpty && muni != _filterCiudad!.trim().toLowerCase()) return false;
      return true;
    }).toList();
  }

  Future<void> _openSearchSheet() async {
    final result = await showModalBottomSheet<_LostSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LostSearchSheet(
        sb: _sb,
        initialDepto: _filterDepto,
        initialCiudad: _filterCiudad,
        initialEspecie: _filterEspecie,
        initialTalla: _filterTalla,
      ),
    );
    if (result == null) return;
    setState(() {
      _filterDepto = result.depto;
      _filterCiudad = result.ciudad;
      _filterEspecie = result.especie;
      _filterTalla = result.talla;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mascotas Perdidas',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Ayuda a encontrar a estos peluditos',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 14),

                  // ─── 3 Top Tabs ─────────────────────────────
                  Row(
                    children: [
                      // Búsqueda abre el sheet de filtros
                      GestureDetector(
                        onTap: () {
                          setState(() => _tabFilter = 'busqueda');
                          _openSearchSheet();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _tabFilter == 'busqueda' ? AppColors.purple : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _tabFilter == 'busqueda' ? AppColors.purple : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 14,
                                  color: _tabFilter == 'busqueda' ? Colors.white : Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text('Búsqueda',
                                  style: TextStyle(
                                    color: _tabFilter == 'busqueda' ? Colors.white : Colors.grey.shade600,
                                    fontWeight: _tabFilter == 'busqueda' ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  )),
                              if (_activeFilterCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _tabFilter == 'busqueda' ? Colors.white : AppColors.purple,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('$_activeFilterCount',
                                      style: TextStyle(
                                        color: _tabFilter == 'busqueda' ? AppColors.purple : Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TabBtn(
                        icon: Icons.campaign,
                        label: 'Alertas',
                        active: _tabFilter == 'alertas',
                        onTap: () => setState(() => _tabFilter = 'alertas'),
                      ),
                      const SizedBox(width: 8),
                      _TabBtn(
                        icon: Icons.location_on,
                        label: 'Cerca',
                        active: _tabFilter == 'cerca',
                        onTap: () {
                          setState(() => _tabFilter = 'cerca');
                          _goToMyLocation();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ─── List / Map Toggle ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tabFilter == 'cerca'
                            ? '${_nearbyPets.length} cerca de ti'
                            : _tabFilter == 'alertas'
                                ? '${_alerts.length} alertas'
                                : '${_pets.length} reportes',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      Row(
                        children: [
                          _ViewToggle(
                            icon: Icons.list,
                            label: 'Lista',
                            selected: _viewMode == 'lista',
                            onTap: () => setState(() => _viewMode = 'lista'),
                          ),
                          const SizedBox(width: 6),
                          _ViewToggle(
                            icon: Icons.map_outlined,
                            label: 'Mapa',
                            selected: _viewMode == 'mapa',
                            onTap: () => setState(() => _viewMode = 'mapa'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ─── Body ────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tabFilter == 'alertas' && _viewMode == 'lista'
                      ? _buildAlertas()
                      : _viewMode == 'mapa'
                          ? _buildMap(_tabFilter == 'cerca')
                          : _tabFilter == 'cerca'
                              ? _buildCercaList()
                              : _buildList(),
            ),
          ],
        ),
      ),

      // ─── Floating Action Button ──────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: _tabFilter == 'alertas'
            ? FloatingActionButton.extended(
                onPressed: _openCreateAlertSheet,
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                elevation: 2,
                icon: const Icon(Icons.add_alert),
                label: const Text('Crear alerta', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : FloatingActionButton.extended(
                onPressed: () => context.push('/publish?estado=perdido'),
                backgroundColor: _tabFilter == 'cerca'
                    ? AppColors.purple
                    : AppColors.orange.withOpacity(0.15),
                foregroundColor: _tabFilter == 'cerca' ? Colors.white : AppColors.orange,
                elevation: _tabFilter == 'cerca' ? 2 : 0,
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('¡Encontré una mascota!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAlertas() {
    if (_loadingAlerts) return const Center(child: CircularProgressIndicator());
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_alert_outlined, size: 48, color: AppColors.purple.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            const Text('No has creado ninguna alerta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 8),
            Text('Te avisaremos cuando aparezca una mascota\nque coincida con tus criterios.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _alerts.length,
        itemBuilder: (_, i) {
          final alert = _alerts[i];
          final parts = <String>[];
          if (alert['especie'] != null) parts.add(_cap(alert['especie'] as String));
          if (alert['talla'] != null) parts.add(_cap(alert['talla'] as String));
          if (alert['municipio'] != null) parts.add(alert['municipio'] as String);
          if (alert['depto'] != null) parts.add(alert['depto'] as String);
          final subtitle = parts.isEmpty ? 'Cualquier mascota perdida' : parts.join(' · ');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.purple.withOpacity(0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, color: AppColors.purple, size: 22),
              ),
              title: Text('Alerta activa', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteAlert(alert['id'] as String),
              ),
            ),
          );
        },
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildList() {
    if (_pets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No hay mascotas perdidas reportadas 🎉', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/publish?estado=perdido'),
              icon: const Icon(Icons.campaign),
              label: const Text('Reportar mascota perdida'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange.withOpacity(0.15),
                foregroundColor: AppColors.orange,
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 280,
        ),
        itemCount: _pets.length,
        itemBuilder: (_, i) => _LostListCard(pet: _pets[i]),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = latlng);
      _mapController.move(latlng, 13);
    } catch (_) {}
  }

  void _showPetBottomSheet(Map<String, dynamic> pet) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final municipio = (pet['municipio'] as String?)?.trim() ?? '';
    final especie = (pet['especie'] as String?)?.toLowerCase() ?? '';
    final edadMeses = pet['edad_meses'] as int?;
    final talla = pet['talla'] as String?;

    String? imageUrl;
    final photos = pet['pet_photos'];
    if (photos is List && photos.isNotEmpty) {
      final sorted = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GestureDetector(
        onTap: () {
          Navigator.pop(context);
          context.push('/pet/${pet['id']}');
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80, height: 80,
                  child: imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(color: Colors.red.shade50, child: const Icon(Icons.pets, color: Colors.redAccent)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.campaign, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text('PERDIDO', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.place, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(municipio, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, children: [
                      if (especie.isNotEmpty) _smallChip(especie == 'perro' ? 'Perro' : 'Gato'),
                      if (edadMeses != null) _smallChip('${edadMeses ~/ 12} años'),
                      if (talla != null && talla.isNotEmpty) _smallChip(talla[0].toUpperCase() + talla.substring(1)),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _buildCercaList() {
    if (_myLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_outlined, size: 48, color: AppColors.purple.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            const Text('Activa tu ubicación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 8),
            Text('Para ver mascotas perdidas cerca de ti\nnecesitamos tu ubicación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToMyLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Usar mi ubicación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    final pets = _nearbyPets;
    if (pets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No hay mascotas perdidas cerca 🎉',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: pets.length,
        itemBuilder: (_, i) => _CercaCard(pet: pets[i]),
      ),
    );
  }

  Widget _buildMap([bool cerca = false]) {
    final source = cerca ? _nearbyPets : _pets;
    final petsWithLocation = source.where((p) => p['lat'] != null && p['lng'] != null).toList();
    final center = _myLocation ??
        (petsWithLocation.isNotEmpty
            ? LatLng((petsWithLocation.first['lat'] as num).toDouble(), (petsWithLocation.first['lng'] as num).toDouble())
            : const LatLng(4.7110, -74.0721));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.petfyco.app',
            ),
            MarkerLayer(
              markers: [
                // Marcadores de mascotas perdidas
                ...petsWithLocation.map((pet) {
                  final lat = (pet['lat'] as num).toDouble();
                  final lng = (pet['lng'] as num).toDouble();
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showPetBottomSheet(pet),
                      child: Stack(
                        children: [
                          Icon(Icons.location_pin, color: cerca ? AppColors.purple : Colors.red, size: 44),
                          Positioned(
                            top: 2, left: 6,
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.pets, size: 14, color: cerca ? AppColors.purple : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Mi ubicación
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blue, width: 2),
                      ),
                      child: const Icon(Icons.person_pin_circle, color: AppColors.blue, size: 22),
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Botón mi ubicación
        Positioned(
          right: 16, bottom: 100,
          child: FloatingActionButton.small(
            heroTag: 'my_location',
            backgroundColor: Colors.white,
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location, color: AppColors.blue),
          ),
        ),
        // Leyenda sin ubicación
        if (petsWithLocation.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Text('Ninguna mascota tiene ubicación registrada', style: TextStyle(fontSize: 13)),
            ),
          ),
        // Contador
        Positioned(
          top: 12, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cerca ? AppColors.purple : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.pets, color: cerca ? Colors.white : Colors.red, size: 14),
              const SizedBox(width: 4),
              Text(
                cerca
                    ? '${petsWithLocation.length} mascota${petsWithLocation.length == 1 ? '' : 's'} perdida${petsWithLocation.length == 1 ? '' : 's'}'
                    : '${petsWithLocation.length} en el mapa',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cerca ? Colors.white : Colors.black87),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────── Tab Button ─────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.purple : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.purple : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade600,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────── View Toggle ────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.purple : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.purple : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────── Lost Pet List Card ─────────────────────────────────────────────

class _LostListCard extends StatelessWidget {
  const _LostListCard({required this.pet});
  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final municipio = (pet['municipio'] as String?)?.trim() ?? '';
    final especie = (pet['especie'] as String?)?.toLowerCase() ?? '';
    final edadMeses = pet['edad_meses'] as int?;
    final talla = pet['talla'] as String?;
    final createdAt = pet['created_at'] as String?;

    final edadLabel = edadMeses == null ? null : '${edadMeses ~/ 12} años';
    final days = createdAt != null
        ? DateTime.now().difference(DateTime.parse(createdAt)).inDays
        : null;

    String? imageUrl;
    final photos = pet['pet_photos'];
    if (photos is List && photos.isNotEmpty) {
      final sorted = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return GestureDetector(
      onTap: () => context.push('/pet/${pet['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlaid chips
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                        : _ph(),
                  ),
                  // Translucent chips bottom
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (especie.isNotEmpty) _overlayTag(especie == 'perro' ? 'Perro' : 'Gato'),
                            if (edadLabel != null) _overlayTag(edadLabel),
                            if (talla != null && talla.isNotEmpty) _overlayTag(talla[0].toUpperCase() + talla.substring(1)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Perdido badge
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.red.withOpacity(0.85),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.campaign, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                const Text('Perdido', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                if (days != null) ...[
                                  const SizedBox(width: 4),
                                  Text('· $days d', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Info Area
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(child: Text(municipio, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(color: Colors.red.shade50, child: const Center(child: Icon(Icons.pets, color: Colors.redAccent, size: 36)));

  Widget _overlayTag(String label) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.white.withOpacity(0.72),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
    ),
  );
}

// ─────────── Cerca Card ──────────────────────────────────────────────────────

class _CercaCard extends StatelessWidget {
  const _CercaCard({required this.pet});
  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final municipio = (pet['municipio'] as String?)?.trim() ?? '';
    final especie = (pet['especie'] as String?)?.toLowerCase() ?? '';
    final edadMeses = pet['edad_meses'] as int?;
    final talla = pet['talla'] as String?;
    final distKm = pet['_distKm'] as double?;

    String? imageUrl;
    final photos = pet['pet_photos'];
    if (photos is List && photos.isNotEmpty) {
      final sorted = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    final especieLabel = especie == 'perro' ? 'Perro' : especie == 'gato' ? 'Gato' : null;
    final edadLabel = edadMeses != null ? '${edadMeses ~/ 12} años' : null;
    final tallaLabel = talla != null && talla.isNotEmpty ? talla[0].toUpperCase() + talla.substring(1) : null;
    final distLabel = distKm != null ? '${distKm.toStringAsFixed(1)} km' : null;

    return GestureDetector(
      onTap: () => context.push('/pet/${pet['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Photo
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _ph())
                      : _ph(),
                  if (especieLabel != null)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(especieLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    if (edadLabel != null)
                      Text(edadLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (tallaLabel != null)
                      Text(tallaLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (municipio.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.place, size: 10, color: Colors.red.shade600),
                              const SizedBox(width: 2),
                              Text(municipio,
                                  style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        if (distLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(distLabel,
                                style: const TextStyle(fontSize: 11, color: AppColors.purple, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(color: Colors.red.shade50, child: const Center(child: Icon(Icons.pets, color: Colors.redAccent, size: 36)));
}

// ─────────── Resultado del sheet de búsqueda ────────────────────────────────

class _LostSearchResult {
  final String? depto;
  final String? ciudad;
  final String? especie;
  final String? talla;
  _LostSearchResult({this.depto, this.ciudad, this.especie, this.talla});
}

// ─────────── Sheet de Búsqueda y Filtros ────────────────────────────────────

class _LostSearchSheet extends StatefulWidget {
  const _LostSearchSheet({
    required this.sb,
    this.initialDepto,
    this.initialCiudad,
    this.initialEspecie,
    this.initialTalla,
    this.title = 'Búsqueda y Filtros',
    this.actionLabel = 'Buscar',
  });
  final SupabaseClient sb;
  final String? initialDepto;
  final String? initialCiudad;
  final String? initialEspecie;
  final String? initialTalla;
  final String title;
  final String actionLabel;

  @override
  State<_LostSearchSheet> createState() => _LostSearchSheetState();
}

class _LostSearchSheetState extends State<_LostSearchSheet> {
  List<String> _deptos = [];
  final Map<String, List<String>> _citiesCache = {};
  bool _loadingDeptos = true;
  bool _loadingCities = false;

  String? _depto;
  String? _ciudad;
  String? _especie;
  String? _talla;

  final _tipos = const ['perro', 'gato'];
  final _tallas = const ['pequeño', 'mediano', 'grande'];

  @override
  void initState() {
    super.initState();
    _depto = widget.initialDepto;
    _ciudad = widget.initialCiudad;
    _especie = widget.initialEspecie;
    _talla = widget.initialTalla;
    _loadDeptos().then((_) {
      if (_depto != null && _depto!.isNotEmpty) _loadCities(_depto!);
    });
  }

  Future<void> _loadDeptos() async {
    setState(() => _loadingDeptos = true);
    try {
      final res = await widget.sb.from('departments').select('name').order('name');
      final set = <String>{};
      if (res is List) {
        for (final row in res) {
          final v = (row['name'] as String?)?.trim();
          if (v != null && v.isNotEmpty) set.add(v);
        }
      }
      if (set.isEmpty) {
        final res2 = await widget.sb.from('pets').select('depto').eq('estado', 'perdido');
        if (res2 is List) {
          for (final row in res2) {
            final v = (row['depto'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
      }
      setState(() {
        _deptos = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _loadingDeptos = false;
      });
    } catch (_) {
      setState(() => _loadingDeptos = false);
    }
  }

  Future<void> _loadCities(String depto) async {
    if (_citiesCache.containsKey(depto)) return;
    setState(() => _loadingCities = true);
    try {
      List<String> list = [];
      try {
        final res = await widget.sb
            .from('cities')
            .select('name, departments!inner(name)')
            .eq('departments.name', depto)
            .order('name');
        if (res is List && res.isNotEmpty) {
          final set = <String>{};
          for (final row in res) {
            final v = (row['name'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
          list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      } catch (_) {}

      if (list.isEmpty) {
        final res2 = await widget.sb.from('pets').select('municipio').eq('depto', depto).eq('estado', 'perdido');
        final set = <String>{};
        if (res2 is List) {
          for (final row in res2) {
            final v = (row['municipio'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
        list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      setState(() {
        _citiesCache[depto] = list;
        _loadingCities = false;
      });
    } catch (_) {
      setState(() => _loadingCities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = (_depto != null && _citiesCache[_depto!] != null) ? _citiesCache[_depto!]! : <String>[];
    final screenH = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenH * 0.82,
      child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Text(widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),

            // — Ubicación
            Text('¿Dónde quieres buscar?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
            const SizedBox(height: 10),

            // Departamento
            _Dropdown(
              value: _depto,
              hint: _loadingDeptos ? 'Cargando...' : 'Departamento',
              icon: Icons.place_outlined,
              items: _deptos,
              enabled: !_loadingDeptos,
              onChanged: (v) {
                setState(() { _depto = v; _ciudad = null; });
                if (v != null && v.isNotEmpty) _loadCities(v);
              },
            ),
            const SizedBox(height: 10),

            // Ciudad
            _Dropdown(
              value: _ciudad,
              hint: _loadingCities ? 'Cargando...' : 'Ciudad / Municipio',
              icon: Icons.location_city_outlined,
              items: cities,
              enabled: !_loadingCities && _depto != null,
              onChanged: (v) => setState(() => _ciudad = v),
            ),

            const SizedBox(height: 20),

            // — Filtros
            Text('Filtros',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Dropdown(
                    value: _especie,
                    hint: 'Tipo de mascota',
                    icon: Icons.pets_outlined,
                    items: _tipos,
                    onChanged: (v) => setState(() => _especie = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dropdown(
                    value: _talla,
                    hint: 'Tamaño',
                    icon: Icons.straighten_outlined,
                    items: _tallas,
                    onChanged: (v) => setState(() => _talla = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // — Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() { _depto = _ciudad = _especie = _talla = null; });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.purple),
                      foregroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _LostSearchResult(
                      depto: _depto, ciudad: _ciudad, especie: _especie, talla: _talla,
                    )),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}

// ─────────── Dropdown helper ────────────────────────────────────────────────

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.icon,
    this.enabled = true,
  });
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: AppColors.purple, size: 20) : null,
        hintText: hint,
        filled: true,
        fillColor: AppColors.purple.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.purple.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.purple.withOpacity(0.3)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e[0].toUpperCase() + e.substring(1), style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
