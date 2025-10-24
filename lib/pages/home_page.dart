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
  String _statusFilter = 'todos'; // "Publicados" == todos

  // notificaciones (cuenta de perdidos del conjunto cargado)
  int get _lostCount => _pets.where((p) => p['estado'] == 'perdido').length;

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
            id, owner_id, nombre, especie, municipio, estado, talla,
            temperamento, edad_meses, created_at,
            pet_photos(url, position)
          ''')
          .order('created_at', ascending: false)
          .limit(300);

      final List<Map<String, dynamic>> allPets = [];
      if (data is List) {
        for (final item in data) {
          if (item is Map) allPets.add(Map<String, dynamic>.from(item as Map));
        }
      }

      // Filtrado en memoria
      final filtered = allPets.where((pet) {
        final estadoOk =
            _statusFilter == 'todos' ? true : (pet['estado'] == _statusFilter);
        final especieOk =
            (_filter == 'todos') ? true : (pet['especie'] == _filter);
        return estadoOk && especieOk;
      }).toList();

      // Orden especial: En "Publicados" (todos) primero perdidos y luego por fecha
      if (_statusFilter == 'todos') {
        filtered.sort((a, b) {
          final aLost = a['estado'] == 'perdido';
          final bLost = b['estado'] == 'perdido';
          if (aLost != bLost) return aLost ? -1 : 1;

          final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da); // desc
        });
      }

      setState(() {
        _pets = filtered;
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

  // ----- Acciones -----

  void _goEdit(String petId) {
    context.push('/publish?edit=$petId');
  }

  Future<void> _markFound(String petId) async {
    try {
      await _sb.from('pets').update({
        'estado': 'adoptado',
        // Si quieras borrado automático: agrega columna found_at y crea job en BD.
      }).eq('id', petId);
      await _loadPets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcada como encontrada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _markAdopted(String petId) async {
    try {
      await _sb.from('pets').update({
        'estado': 'adoptado',
        // Para borrado a 7 días, igual: columna adopted_at + job en BD
      }).eq('id', petId);
      await _loadPets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por adoptar 🧡')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo/petfyco_logo_full.png', height: 40),
        actions: [
          // Campana con badge rojo a la derecha
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/lost'),
              ),
              if (_lostCount > 0)
                Positioned(
                  right: 8,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_lostCount',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white)),
                  ),
                ),
            ],
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

            // Estados (Publicados, Perdidos, Adoptados)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(
                        label: 'Publicados',
                        selected: _statusFilter == 'todos',
                        onTap: () {
                          setState(() => _statusFilter = 'todos');
                          _loadPets();
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        // rojo + bocina como pediste
                        label: '📢 Perdidos',
                        selected: _statusFilter == 'perdido',
                        onTap: () {
                          setState(() => _statusFilter = 'perdido');
                          _loadPets();
                        },
                        selectedColor: Colors.red.shade50,
                        textColor: Colors.red.shade600,
                        borderColor: Colors.red.shade300,
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
                            : 'No hay mascotas para mostrar',
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
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 340,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final pet = _pets[i];
                      final meId = _sb.auth.currentUser?.id;
                      final bool isOwner =
                          meId != null && meId == (pet['owner_id'] as String?);
                      return _PetCard(
                        pet: pet,
                        isOwner: isOwner,
                        onEdit: () => _goEdit(pet['id'] as String),
                        onFound: () => _markFound(pet['id'] as String),
                        onAdopt: () => _markAdopted(pet['id'] as String),
                      );
                    },
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
    this.selectedColor,
    this.textColor,
    this.borderColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final baseSelectedColor = selectedColor ?? AppColors.blue.withOpacity(0.2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? baseSelectedColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? (borderColor ?? AppColors.blue) : Colors.transparent,
              width: selected ? 2 : 0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? (textColor ?? AppColors.navy) : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.isOwner,
    required this.onEdit,
    required this.onFound,
    required this.onAdopt,
  });

  final Map<String, dynamic> pet;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onFound;
  final VoidCallback onAdopt;

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

    // Foto principal
    String? imageUrl;
    final petPhotosRaw = pet['pet_photos'];
    if (petPhotosRaw is List && petPhotosRaw.isNotEmpty) {
      final casted = petPhotosRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      casted.sort((a, b) => (a['position'] as int? ?? 0)
          .compareTo((b['position'] as int? ?? 0)));
      imageUrl = casted.first['url'] as String?;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen arriba (sin overlay de texto para que el título sea negro)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),

          // Texto en negro
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppColors.pink),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        municipio,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .copyWith(color: Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Gradiente suave + chips de info
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black12.withOpacity(0.06),
                    Colors.black26.withOpacity(0.08),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(especie == 'perro' ? 'Perro' : 'Gato'),
                    if (edadAnios != null)
                      _chip('$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                    if (talla != null && talla.isNotEmpty) _chip(talla),
                    if (temperamento != null && temperamento.isNotEmpty)
                      _chip(temperamento),
                    _chipEstado(estado),
                  ],
                ),
              ),
            ),
          ),

          // Botones por estado/rol
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (isOwner)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ),
                if (isOwner && estado == 'perdido') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onFound,
                      icon: const Icon(Icons.campaign_rounded),
                      label: const Text('Encontrado'),
                    ),
                  ),
                ],
                if (!isOwner && estado == 'publicado') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdopt,
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: const Text('Adoptar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      backgroundColor: Colors.blue.withOpacity(0.10),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _chipEstado(String estado) {
    Color bg;
    Color fg;
    String label;
    switch (estado) {
      case 'perdido':
        bg = Colors.red.withOpacity(0.10);
        fg = Colors.red.shade700;
        label = 'Perdido';
        break;
      case 'adoptado':
        bg = Colors.green.withOpacity(0.10);
        fg = Colors.green.shade700;
        label = 'Adoptado';
        break;
      case 'reservado':
        bg = Colors.orange.withOpacity(0.10);
        fg = Colors.orange.shade700;
        label = 'Reservado';
        break;
      default:
        bg = Colors.blue.withOpacity(0.10);
        fg = Colors.blueGrey.shade700;
        label = 'Disponible';
    }
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: fg)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
