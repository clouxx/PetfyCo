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
  List<Map<String, dynamic>> _pets = [];
  String _tabFilter = 'busqueda';
  String _viewMode = 'lista';
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _load();
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
        _pets = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
                      _TabBtn(
                        icon: Icons.search,
                        label: 'Búsqueda',
                        active: _tabFilter == 'busqueda',
                        onTap: () => setState(() => _tabFilter = 'busqueda'),
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
                        onTap: () => setState(() => _tabFilter = 'cerca'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ─── List / Map Toggle ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_pets.length} reportes',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                  : _viewMode == 'mapa'
                      ? _buildMap()
                      : _buildList(),
            ),
          ],
        ),
      ),

      // ─── Floating Action Button ──────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/publish?estado=perdido'),
          backgroundColor: AppColors.orange.withOpacity(0.15),
          foregroundColor: AppColors.orange,
          elevation: 0,
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('¡Encontré una mascota!', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

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

  Widget _buildMap() {
    final petsWithLocation = _pets.where((p) => p['lat'] != null && p['lng'] != null).toList();
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
                          const Icon(Icons.location_pin, color: Colors.red, size: 44),
                          Positioned(
                            top: 2, left: 6,
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.pets, size: 14, color: Colors.red),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_pin, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text('${petsWithLocation.length} en el mapa', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
