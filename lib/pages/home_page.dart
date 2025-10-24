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

  String _filter = 'todos';
  String _statusFilter = 'todos';
  int _lostCount = 0;

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

      _lostCount = allPets.where((p) => p['estado'] == 'perdido').length;

      List<Map<String, dynamic>> filtered = allPets.where((pet) {
        final estadoOk = _statusFilter == 'todos' ? true : (pet['estado'] == _statusFilter);
        final especieOk = _filter == 'todos' ? true : (pet['especie'] == _filter);
        return estadoOk && especieOk;
      }).toList();

      int estadoRank(String e) => (e == 'perdido') ? 0 : 1;
      int compareDateDesc(a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      }

      if (_statusFilter == 'todos') {
        filtered.sort((a, b) {
          final r = estadoRank(a['estado'] ?? '') - estadoRank(b['estado'] ?? '');
          if (r != 0) return r;
          return compareDateDesc(a, b);
        });
      } else {
        filtered.sort(compareDateDesc);
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

  void _goEdit(String petId) => context.push('/publish?edit=$petId');

  Future<void> _markFoundAndAskDelete(String petId) async {
    final res = await showModalBottomSheet<_FoundAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FoundSheet(),
    );
    if (res == null) return;

    if (res == _FoundAction.deleteNow) {
      await _sb.from('pets').delete().eq('id', petId);
      await _loadPets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mascota eliminada')));
    } else {
      try {
        await _sb.from('pets').update({'estado': 'publicado'}).eq('id', petId);
        await _loadPets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marcado como encontrado.')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _adoptPet(String petId) async {
    try {
      await _sb.from('pets').update({'estado': 'adoptado'}).eq('id', petId);
      await _loadPets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por adoptar!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo/petfyco_logo_full.png', height: 40),
        actions: [
          IconButton(
            onPressed: () => context.push('/lost'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_lostCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        _lostCount > 99 ? '99+' : '$_lostCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _HeaderBanner(
                  onPublish: () => context.push('/publish'),
                  onLost: () => context.push('/publish?estado=perdido'),
                ),
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
                      label: 'Perros',
                      selected: _filter == 'perro',
                      onTap: () {
                        setState(() => _filter = 'perro');
                        _loadPets();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Gatos',
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
                        labelWidget: Row(
                          children: const [
                            Icon(Icons.campaign, size: 16, color: Colors.red),
                            SizedBox(width: 6),
                            Text('Perdidos',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        selected: _statusFilter == 'perdido',
                        onTap: () {
                          setState(() => _statusFilter = 'perdido');
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
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 360,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final pet = _pets[i];
                      final meId = me;
                      final isOwner = meId != null && meId == pet['owner_id'];
                      return _PetCard(
                        pet: pet,
                        isOwner: isOwner,
                        onEdit: () => _goEdit(pet['id'] as String),
                        onFound: () => _markFoundAndAskDelete(pet['id'] as String),
                        onAdopt: () => _adoptPet(pet['id'] as String),
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
            AppColors.orange.withOpacity(0.14)
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
    this.label,
    this.labelWidget,
    required this.selected,
    required this.onTap,
  }) : assert(label != null || labelWidget != null);

  final String? label;
  final Widget? labelWidget;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = labelWidget ?? Text(label!);
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
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.navy : Colors.grey.shade700,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ==================================================
// _PetCard: DISEÑO NUEVO (como en la imagen)
// ==================================================

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
    final municipio = (pet['municipio'] as String?)?.trim();
    final estado = pet['estado'] as String? ?? 'publicado';
    final talla = pet['talla'] as String?;
    final temperamento = pet['temperamento'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    String? imageUrl;
    final petPhotosRaw = pet['pet_photos'];
    if (petPhotosRaw is List && petPhotosRaw.isNotEmpty) {
      final casted = petPhotosRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = casted.first['url'] as String?;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // ¡CLAVE! Recorta la imagen al borde
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        borderRadius: BorderRadius.circular(16), // Ripple redondeado
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FOTO + CHIPS
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 180,
                child: ClipRRect(  // ← ¡AÑADIDO!
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                    Positioned.fill(
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                            )
                          : const _ImagePlaceholder(),
                    ),
                    // Degradado
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.45),
                              Colors.black.withOpacity(0.65),
                            ],
                            stops: const [0.4, 0.65, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Chips
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(context, especie == 'perro' ? 'Perro' : 'Gato'),
                          if (edadAnios != null) _chip(context, '$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                          if (talla != null && talla.isNotEmpty) _chip(context, _cap(talla)),
                          if (temperamento != null && temperamento.isNotEmpty) _chip(context, _cap(temperamento)),
                          _statusChipForCard(context, estado),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

            // SECCIÓN INFERIOR: sin Container extra → sin espacio blanco
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NOMBRE
                  Text(
                    nombre,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // UBICACIÓN
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          municipio?.isNotEmpty == true ? municipio! : 'Colombia',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // BOTONES
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOwner) ...[
                          _smallAction(context,
                              icon: Icons.edit_outlined,
                              label: 'Editar',
                              onTap: onEdit),
                          const SizedBox(width: 6),
                          if (estado == 'perdido')
                            _smallAction(context,
                                icon: Icons.campaign_outlined,
                                label: 'Encontrado',
                                onTap: onFound,
                                bg: AppColors.orange),
                        ] else if (estado == 'publicado') ...[
                          _smallAction(context,
                              icon: Icons.volunteer_activism_outlined,
                              label: 'Adoptar',
                              onTap: onAdopt,
                              bg: Colors.green.shade600),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === CHIPS Y BOTONES (sin cambios) ===
  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _statusChipForCard(BuildContext context, String estado) {
    if (estado == 'perdido') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text('Perdido',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
          ],
        ),
      );
    }
    if (estado == 'adoptado') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text('Adoptado',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
          ],
        ),
      );
    }
    return _chip(context, 'Disponible');
  }

  Widget _smallAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? bg,
  }) {
    return Material(
      color: bg ?? Colors.black87,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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

enum _FoundAction { markAndDeleteIn7Days, deleteNow }

class _FoundSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mascota encontrada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('¿Qué deseas hacer?', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Marcar como encontrada'),
              subtitle: const Text('Se quitará de “Perdidos”.'),
              onTap: () => Navigator.pop(context, _FoundAction.markAndDeleteIn7Days),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Eliminar ahora'),
              subtitle: const Text('Se eliminará de inmediato.'),
              onTap: () => Navigator.pop(context, _FoundAction.deleteNow),
            ),
          ],
        ),
      ),
    );
  }
}
