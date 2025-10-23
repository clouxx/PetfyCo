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

  String _filter = 'todos'; // todos | perro | gato
  String _statusFilter = 'publicado';

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    try {
      // Base query
      var query = _sb.from('pets').select('''
            *,
            profiles:owner_id(display_name, phone),
            pet_photos(url, position)
          ''');

      // Filtros SIEMPRE antes de order/limit
      query = query.eq('estado', _statusFilter);
      if (_filter != 'todos') {
        query = query.eq('especie', _filter);
      }

      // Orden + límite al final
      final data = await query.order('created_at', ascending: false).limit(20);

      setState(() {
        _pets = List<Map<String, dynamic>>.from(data);
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
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/profile')),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _HeaderBanner(),
              ),
            ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusChip(
                        label: 'Publicados',
                        selected: _statusFilter == 'publicado',
                        onTap: () {
                          setState(() => _statusFilter = 'publicado');
                          _loadPets();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusChip(
                        label: 'Adoptados',
                        selected: _statusFilter == 'adoptado',
                        onTap: () {
                          setState(() => _statusFilter = 'adoptado');
                          _loadPets();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusChip(
                        label: 'Reservados',
                        selected: _statusFilter == 'reservado',
                        onTap: () {
                          setState(() => _statusFilter = 'reservado');
                          _loadPets();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_pets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pets, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No hay mascotas disponibles',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/publish'),
                        icon: const Icon(Icons.add),
                        label: const Text('Publicar la primera'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.blue.withOpacity(0.18),
          AppColors.orange.withOpacity(0.14)
        ]),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
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
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
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
  const _StatusChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.blue.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.blue, width: 2) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.navy : Colors.grey.shade700,
            ),
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

    final petPhotos = pet['pet_photos'] as List<dynamic>?;
    String? imageUrl;
    if (petPhotos != null && petPhotos.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(petPhotos)
        ..sort((a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.blue.withOpacity(0.15),
                        child: const Icon(Icons.pets,
                            size: 48, color: AppColors.navy),
                      ),
                    )
                  : Container(
                      color: AppColors.blue.withOpacity(0.15),
                      child: const Center(
                          child: Icon(Icons.pets,
                              size: 48, color: AppColors.navy)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place,
                          size: 16, color: AppColors.pink),
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
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          especie == 'perro' ? 'Perro' : 'Gato',
                          style: const TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Chip(
                          label: Text(
                            _getEstadoLabel(estado),
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
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

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'publicado':
        return 'Disponible';
      case 'adoptado':
        return 'Adoptado';
      case 'reservado':
        return 'Reservado';
      default:
        return estado;
    }
  }
}
