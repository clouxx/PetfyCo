import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _loading = true;
  List<Map<String, dynamic>> _pets = [];
  String _tabFilter = 'busqueda'; // 'busqueda' | 'alertas' | 'cerca'
  String _viewMode = 'lista'; // 'lista' | 'mapa'

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
        edad_meses, talla, created_at,
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
                      ? _buildMapPlaceholder()
                      : _buildList(),
            ),
          ],
        ),
      ),

      // ─── Floating Action Button ──────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/publish?estado=perdido'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('¡Encontré una mascota!', style: TextStyle(fontWeight: FontWeight.bold)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _pets.length,
        itemBuilder: (_, i) => _LostListCard(pet: _pets[i]),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map, size: 40, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          const Text('Vista de Mapa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Próximamente podrás ver las mascotas\nperdidas en el mapa interactivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
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
    final depto = (pet['depto'] as String?)?.trim() ?? '';
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: SizedBox(
                width: 110, height: 120,
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign, size: 12, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text('PERDIDO', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          if (days != null) ...[
                            const SizedBox(width: 4),
                            Text('• hace $days días', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 14, color: AppColors.pink),
                        const SizedBox(width: 4),
                        Expanded(child: Text('$municipio, $depto', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (especie.isNotEmpty) _chip(especie == 'perro' ? '🐶 Perro' : '🐱 Gato'),
                        if (edadLabel != null) _chip(edadLabel),
                        if (talla != null && talla.isNotEmpty) _chip(talla[0].toUpperCase() + talla.substring(1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(color: Colors.red.shade50, child: const Center(child: Icon(Icons.pets, color: Colors.redAccent, size: 36)));

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  );
}
