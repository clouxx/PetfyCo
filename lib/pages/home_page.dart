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
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
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
    return Scaffold(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/publish'),
        icon: const Icon(Icons.add),
        label: const Text('Publicar mascota'),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
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
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
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
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    // Responsive: iPhone 14 Pro Max ≈ 430px → 2 columnas cómodas
                    int crossAxisCount = 1;
                    if (width >= 360) crossAxisCount = 2;
                    if (width >= 900) crossAxisCount = 3;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 16 / 20, // más alta para dejar sitio a la info
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _PetCard(pet: _pets[i]),
                        childCount: _pets.length,
                      ),
                    );
                  },
                ),
              ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue.withOpacity(0.18),
            AppColors.orange.withOpacity(0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset('assets/logo/petfyco_icon.png', height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Encuentra y publica mascotas en Colombia',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPublish,
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Dar en adopción'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onLost,
                  icon: const Icon(Icons.campaign),
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
          color: selected ? AppColors.blue.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.blue, width: 2) : null,
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
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? 'desconocido';
    final municipio = pet['municipio'] as String? ?? 'Colombia';
    final estado = pet['estado'] as String? ?? 'publicado';
    final talla = pet['talla'] as String?;
    final temperamento = pet['temperamento'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    // Primera foto
    String? imageUrl;
    final raw = pet['pet_photos'];
    if (raw is List && raw.isNotEmpty) {
      final photos = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = photos.first['url'] as String?;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        child: Stack(
          children: [
            // Imagen (16:10 para que quede algo alta en móvil)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _ImagePlaceholder(),
                      loadingBuilder: (context, child, loading) {
                        if (loading == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    )
                  : const _ImagePlaceholder(),
            ),

            // Degradado inferior para contraste
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x88000000),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Ciudad
                    Row(
                      children: [
                        const Icon(Icons.place, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            municipio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(especie == 'perro' ? 'Perro' : 'Gato'),
                        if (edadAnios != null)
                          _chip('$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                        if (talla != null && talla.isNotEmpty) _chip(_cap(talla)),
                        if (temperamento != null && temperamento.isNotEmpty)
                          _chip(_cap(temperamento)),
                        _chip(_estadoLabel(estado)),
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

  String _cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1).toLowerCase();

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

  Widget _chip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: Colors.black.withOpacity(0.35),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
