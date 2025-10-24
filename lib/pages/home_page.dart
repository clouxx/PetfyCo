import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _sb = Supabase.instance.client;

  List<Map<String, dynamic>> _pets = [];
  bool _loading = true;

  // Filtros
  String _filter = 'todos'; // todos | perro | gato
  String _statusFilter = 'publicado'; // publicado | adoptado | reservado | perdido

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('pets')
          .select('''
            id, nombre, especie, municipio, estado, talla, temperamento, edad_meses,
            pet_photos(url, position)
          ''')
          .order('created_at', ascending: false)
          .limit(200);

      final List<Map<String, dynamic>> allPets = [];
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            allPets.add(Map<String, dynamic>.from(item as Map));
          }
        }
      }

      final filteredPets = allPets.where((pet) {
        final estadoOk = (pet['estado'] == _statusFilter);
        final especieOk = (_filter == 'todos') || (pet['especie'] == _filter);
        return estadoOk && especieOk;
      }).toList();

      setState(() {
        _pets = filteredPets;
        _loading = false;
      });

      if (_pets.isNotEmpty && _pets[0]['pet_photos'] != null) {
        debugPrint('📸 Fotos 1er item: ${_pets[0]['pet_photos']}');
      }
    } catch (e) {
      debugPrint('❌ Error cargando mascotas: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando mascotas: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _sb.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Limita el escalado para que la UI no “rompa” si el usuario sube mucho la letra
    final media = MediaQuery.of(context);
    final textScale =
        media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2);

    return MediaQuery(
      data: media.copyWith(textScaler: textScale),
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset('assets/logo/petfyco_logo_full.png', height: 40),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/lost'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/profile'),
            ),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),

        // FAB con SafeArea para no chocar con la barra inferior del iPhone
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: SafeArea(
          minimum: const EdgeInsets.only(bottom: 12, right: 8),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/publish'),
            icon: const Icon(Icons.add),
            label: const Text('Publicar mascota'),
            backgroundColor: AppColors.orange,
            foregroundColor: AppColors.white,
          ),
        ),

        body: RefreshIndicator(
          onRefresh: _loadPets,
          child: CustomScrollView(
            slivers: [
              // Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _HeaderBanner(
                    onPublish: () => context.push('/publish'),
                    onLost: () => context.push('/publish?estado=perdido'),
                  ),
                ),
              ),

              // Filtro por especie
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filter == 'todos',
                        onTap: () {
                          setState(() => _filter = 'todos');
                          _loadPets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '🐶 Perros',
                        selected: _filter == 'perro',
                        onTap: () {
                          setState(() => _filter = 'perro');
                          _loadPets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '🐱 Gatos',
                        selected: _filter == 'gato',
                        onTap: () {
                          setState(() => _filter = 'gato');
                          _loadPets();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Estados
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusChip(
                          label: 'Publicados',
                          selected: _statusFilter == 'publicado',
                          onTap: () {
                            setState(() => _statusFilter = 'publicado');
                            _loadPets();
                          },
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: 'Adoptados',
                          selected: _statusFilter == 'adoptado',
                          onTap: () {
                            setState(() => _statusFilter = 'adoptado');
                            _loadPets();
                          },
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: 'Reservados',
                          selected: _statusFilter == 'reservado',
                          onTap: () {
                            setState(() => _statusFilter = 'reservado');
                            _loadPets();
                          },
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: 'Perdidos',
                          selected: _statusFilter == 'perdido',
                          onTap: () {
                            setState(() => _statusFilter = 'perdido');
                            _loadPets();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_pets.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pets, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _statusFilter == 'perdido'
                              ? 'No hay reportes de mascotas perdidas'
                              : 'No hay mascotas disponibles',
                          style: const TextStyle(
                              fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/publish'),
                          icon: const Icon(Icons.add),
                          label: const Text('Publicar'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      // ✅ Grilla responsiva: 1 col <600, 2 col <900, 3 col desktop
                      crossAxisCount: switch (MediaQuery.sizeOf(context).width) {
                        < 600 => 1,
                        < 900 => 2,
                        _ => 3,
                      },
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent:
                          MediaQuery.sizeOf(context).width < 600 ? 300 : 320,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _PetCard(pet: _pets[i]),
                      childCount: _pets.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Widgets auxiliares ----------

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({this.onPublish, this.onLost});
  final VoidCallback? onPublish;
  final VoidCallback? onLost;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue.withOpacity(0.18),
            AppColors.orange.withOpacity(0.14)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.all(w < 600 ? 12 : 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/logo/petfyco_icon.png',
                  height: w < 600 ? 48 : 60),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Encuentra y publica mascotas en Colombia',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: w < 600 ? 16 : null,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onPublish,
                  icon: const Icon(Icons.favorite_outline, size: 18),
                  label: const Text('Dar en adopción'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onLost,
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Reportar perdido'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.grey.shade200,
      selectedColor: AppColors.blue.withOpacity(0.2),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.blue.withOpacity(0.15) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : Colors.transparent,
            width: selected ? 1.8 : 0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.navy : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? 'desconocido';
    final municipio = pet['municipio'] as String? ?? 'Colombia';
    final estado = pet['estado'] as String? ?? 'publicado';
    final talla = pet['talla'] as String?;
    final temperamento = pet['temperamento'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    String? imageUrl;
    final petPhotosRaw = pet['pet_photos'];
    if (petPhotosRaw != null && petPhotosRaw is List) {
      final photos = petPhotosRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      if (photos.isNotEmpty) imageUrl = photos.first['url'] as String?;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 4:3 en phone, 16:9 en pantallas grandes
            AspectRatio(
              aspectRatio: w < 600 ? 4 / 3 : 16 / 9,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                    )
                  : const _ImagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: w < 600 ? 18 : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: AppColors.pink),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          municipio,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildTag(especie == 'perro' ? 'Perro' : 'Gato'),
                      if (edadAnios != null)
                        _buildTag(
                            '$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                      if (talla != null && talla.isNotEmpty) _buildTag(talla),
                      if (temperamento != null && temperamento.isNotEmpty)
                        _buildTag(temperamento),
                      _buildTag(_estadoLabel(estado)),
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

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'publicado':
        return 'Disponible';
      case 'adoptado':
        return 'Adoptado';
      case 'reservado':
        return 'Reservado';
      case 'perdido':
        return 'Perdido';
      default:
        return estado;
    }
  }

  Widget _buildTag(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.blue.withOpacity(0.1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blue.withOpacity(0.12),
      child: const Center(
        child: Icon(Icons.pets, size: 40, color: AppColors.navy),
      ),
    );
  }
}
