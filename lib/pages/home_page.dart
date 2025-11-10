import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Filtros visibles arriba
  String _filter = 'todos';
  String _statusFilter = 'todos';
  int _lostCount = 0;

  // Filtros del modal
  String? _selDepto;
  String? _selCiudad;
  String? _sizeFilter; // pequeño | mediano | grande
  String? _typeFilter; // perro | gato

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
            temperamento, edad_meses, created_at, depto,
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

      _lostCount = allPets.where((p) => (p['estado'] ?? '') == 'perdido').length;

      // ----- FILTROS EN MEMORIA -----
      List<Map<String, dynamic>> filtered = allPets.where((pet) {
        final estado = (pet['estado'] ?? '').toString().toLowerCase();
        final especie = (pet['especie'] ?? '').toString().toLowerCase();
        final talla = (pet['talla'] ?? '').toString().toLowerCase();
        final depto = (pet['depto'] ?? '').toString().trim().toLowerCase();
        final muni = (pet['municipio'] ?? '').toString().trim().toLowerCase();

        final estadoOk = _statusFilter == 'todos'
            ? true
            : estado == _statusFilter.toLowerCase();

        final especieChipOk =
            _filter == 'todos' ? true : especie == _filter.toLowerCase();

        final especieModalOk =
            _typeFilter == null ? true : especie == _typeFilter!.toLowerCase();

        final tallaOk =
            _sizeFilter == null ? true : talla == _sizeFilter!.toLowerCase();

        final deptoOk = (_selDepto == null || _selDepto!.isEmpty)
            ? true
            : depto == _selDepto!.trim().toLowerCase();

        final ciudadOk = (_selCiudad == null || _selCiudad!.isEmpty)
            ? true
            : muni == _selCiudad!.trim().toLowerCase();

        return estadoOk &&
            especieChipOk &&
            especieModalOk &&
            tallaOk &&
            deptoOk &&
            ciudadOk;
      }).toList();

      // Orden: perdidos primero cuando status = todos; luego por fecha desc.
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
          final r = estadoRank((a['estado'] ?? '').toString()) -
              estadoRank((b['estado'] ?? '').toString());
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

  void _goEdit(String petId) => context.push('/publish?editId=$petId');

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mascota eliminada')));
    } else {
      try {
        await _sb.from('pets').update({'estado': 'publicado'}).eq('id', petId);
        await _loadPets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcado como encontrado.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- Abre modal “Gracias” y si confirman, lanza WhatsApp al dueño
  Future<void> _intentAdopt(Map<String, dynamic> pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _AdoptConfirmDialog(petName: pet['nombre'] ?? 'tu mascota'),
    );
    if (ok != true) return;

    try {
      final ownerId = pet['owner_id'] as String?;
      if (ownerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener contacto del dueño.')),
        );
        return;
      }

      // Ajusta los campos según tu tabla profiles
      final profile = await _sb
          .from('profiles')
          .select('whatsapp, phone, full_name')
          .eq('id', ownerId)
          .single();

      final rawPhone =
          (profile['whatsapp'] ?? profile['phone'] ?? '').toString().trim();
      if (rawPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El dueño no tiene WhatsApp registrado.')),
        );
        return;
      }

      final msg =
          '¡Hola! Vi a *${pet['nombre']}* en PetfyCo y me gustaría adoptar. ¿Podemos hablar?';
      final uri =
          Uri.parse('https://wa.me/$rawPhone?text=${Uri.encodeComponent(msg)}');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pude abrir WhatsApp en este dispositivo.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // — Marca adoptado (solo dueño)
  Future<void> _markAdopted(String petId) async {
    try {
      await _sb.from('pets').update({'estado': 'adoptado'}).eq('id', petId);
      await _loadPets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcado como adoptado.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ---------- Abrir hoja de búsqueda/filtros
  Future<void> _openSearchSheet() async {
    final result = await showModalBottomSheet<_SearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SearchFiltersSheet(
        sb: _sb,
        initialDepto: _selDepto,
        initialCity: _selCiudad,
        initialType: _typeFilter ?? (_filter == 'todos' ? null : _filter),
        initialSize: _sizeFilter,
      ),
    );
    if (result == null) return;

    setState(() {
      _selDepto = result.depto;
      _selCiudad = result.city;
      _typeFilter = result.type;
      _sizeFilter = result.size;
      if (result.type != null) _filter = result.type!;
    });

    await _loadPets();
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

            // Panel filtros
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: '🐾 Todos',
                            selected: _filter == 'todos',
                            onTap: () {
                              setState(() {
                                _filter = 'todos';
                                _typeFilter = null;
                              });
                              _loadPets();
                            },
                          ),
                          _FilterChip(
                            label: '🐶 Perros',
                            selected: _filter == 'perro',
                            onTap: () {
                              setState(() {
                                _filter = 'perro';
                                _typeFilter = null;
                              });
                              _loadPets();
                            },
                          ),
                          _FilterChip(
                            label: '🐱 Gatos',
                            selected: _filter == 'gato',
                            onTap: () {
                              setState(() {
                                _filter = 'gato';
                                _typeFilter = null;
                              });
                              _loadPets();
                            },
                          ),
                          _SearchIconChip(onTap: _openSearchSheet),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                Icon(Icons.campaign,
                                    size: 16, color: Colors.red),
                                SizedBox(width: 6),
                                Text(
                                  'Perdidos',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                    ],
                  ),
                ),
              ),
            ),

            // Grid
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
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
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
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
                        onFound: () =>
                            _markFoundAndAskDelete(pet['id'] as String),
                        // — no dueño → intención de adopción (WhatsApp)
                        onAdopt: () => _intentAdopt(pet),
                        // — dueño → marcar adoptado
                        onOwnerAdopted: () => _markAdopted(pet['id'] as String),
                        onOwnerDelete: () async {
                          await _sb
                              .from('pets')
                              .delete()
                              .eq('id', pet['id'] as String);
                          _loadPets();
                        },
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
      checkmarkColor: AppColors.navy,
      shape: const StadiumBorder(side: BorderSide(color: Colors.black12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
          color:
              selected ? AppColors.blue.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppColors.blue, width: 2)
              : Border.all(color: Colors.black12),
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

// Chip de búsqueda (lupa)
class _SearchIconChip extends StatelessWidget {
  const _SearchIconChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Colors.black12)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(Icons.search, size: 20, color: AppColors.navy),
        ),
      ),
    );
  }
}

// ==================================================
// _PetCard
// ==================================================

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.isOwner,
    required this.onEdit,
    required this.onFound,
    required this.onAdopt,
    required this.onOwnerAdopted,
    required this.onOwnerDelete,
  });

  final Map<String, dynamic> pet;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onFound;
  final VoidCallback onAdopt; // no-dueño (WhatsApp)
  final VoidCallback onOwnerAdopted; // dueño marca adoptado
  final VoidCallback onOwnerDelete; // dueño elimina

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? 'desconocido';
    final municipio = (pet['municipio'] as String?)?.trim();
    final depto = (pet['depto'] as String?)?.trim();
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
        ..sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = casted.first['url'] as String?;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 180,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, __, ___) =>
                                    const _ImagePlaceholder(),
                              )
                            : const _ImagePlaceholder(),
                      ),
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
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(context, especie == 'perro' ? 'Perro' : 'Gato'),
                            if (edadAnios != null)
                              _chip(context,
                                  '$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                            if (talla != null && talla.isNotEmpty)
                              _chip(context, _cap(talla)),
                            if (temperamento != null && temperamento.isNotEmpty)
                              _chip(context, _cap(temperamento)),
                            _statusChipForCard(context, estado),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    children: [
                      Icon(Icons.place, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (municipio != null && municipio.isNotEmpty)
                              ? municipio
                              : (depto != null && depto.isNotEmpty
                                  ? depto
                                  : 'Colombia'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          const SizedBox(width: 6),
                          if (estado == 'publicado' || estado == 'reservado')
                            _smallAction(context,
                                icon: Icons.check_circle_outline,
                                label: 'Adoptado',
                                onTap: onOwnerAdopted,
                                bg: Colors.green.shade700),
                          const SizedBox(width: 6),
                          if (estado == 'adoptado')
                            _smallAction(context,
                                icon: Icons.delete_forever,
                                label: 'Eliminar',
                                onTap: onOwnerDelete,
                                bg: Colors.redAccent),
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

  String _cap(String s) =>
      s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
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

// --------- Bottom sheet para acción "Encontrado" ---------

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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('¿Qué deseas hacer?', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Marcar como encontrada'),
              subtitle: const Text('Se quitará de “Perdidos”.'),
              onTap: () =>
                  Navigator.pop(context, _FoundAction.markAndDeleteIn7Days),
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

/// --------- Modal de confirmación de adopción (no dueño) ---------
class _AdoptConfirmDialog extends StatelessWidget {
  const _AdoptConfirmDialog({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo/petfyco_icon.png', height: 64),
            const SizedBox(height: 8),
            Text('¡Muchas gracias!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            Text(
              'La adopción es un acto de amor y responsabilidad. '
              'Si deseas continuar, te llevaré al WhatsApp del dueño para hablar sobre ${'' + petName}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.chat), // <- reemplazo de whatsapp
                    label: const Text('Continuar'),
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------
/// Búsqueda y Filtros (modal) con datos de BD
/// ----------------------

class _SearchResult {
  final String? depto;
  final String? city;
  final String? type; // perro | gato
  final String? size; // pequeño | mediano | grande
  _SearchResult({this.depto, this.city, this.type, this.size});
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({
    required this.sb,
    this.initialDepto,
    this.initialCity,
    this.initialType,
    this.initialSize,
  });

  final SupabaseClient sb;
  final String? initialDepto;
  final String? initialCity;
  final String? initialType;
  final String? initialSize;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  List<String> _deptos = const [];
  final Map<String, List<String>> _citiesCache = {};

  String? _depto;
  String? _city;
  String? _type;
  String? _size;

  final List<String> _tipos = const ['perro', 'gato'];
  final List<String> _tallas = const ['pequeño', 'mediano', 'grande'];

  bool _loadingDeptos = true;
  bool _loadingCities = false;

  @override
  void initState() {
    super.initState();
    _depto = widget.initialDepto;
    _city = widget.initialCity;
    _type = widget.initialType;
    _size = widget.initialSize;

    _loadDeptos().then((_) {
      if (_depto != null && _depto!.isNotEmpty) {
        _loadCities(_depto!);
      }
    });
  }

  Future<void> _loadDeptos() async {
    setState(() => _loadingDeptos = true);
    try {
      final res =
          await widget.sb.from('departments').select('name').order('name');
      final set = <String>{};
      if (res is List) {
        for (final row in res) {
          final v = (row['name'] as String?)?.trim();
          if (v != null && v.isNotEmpty) set.add(v);
        }
      }
      final list = set.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _deptos = list;
        _loadingDeptos = false;
      });
    } catch (_) {
      try {
        final res2 =
            await widget.sb.from('pets').select('depto').order('depto');
        final set = <String>{};
        if (res2 is List) {
          for (final row in res2) {
            final v = (row['depto'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
        final list = set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _deptos = list;
        });
      } finally {
        setState(() => _loadingDeptos = false);
      }
    }
  }

  Future<void> _loadCities(String depto) async {
    if (_citiesCache.containsKey(depto)) return;
    setState(() => _loadingCities = true);
    List<String> list = [];
    try {
      // Intentar cities (si existe)
      try {
        final res = await widget.sb
            .from('cities')
            .select('name, departments!inner(name)')
            .eq('departments.name', depto)
            .order('name');
        final set = <String>{};
        if (res is List && res.isNotEmpty) {
          for (final row in res) {
            final v = (row['name'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
          list = set.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      } catch (_) {
        // ignore
      }

      // Fallback por pets
      if (list.isEmpty) {
        final resPets = await widget.sb
            .from('pets')
            .select('municipio')
            .eq('depto', depto)
            .order('municipio');
        final set = <String>{};
        if (resPets is List) {
          for (final row in resPets) {
            final v = (row['municipio'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
        list = set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cityItems = (_depto != null && _citiesCache[_depto!] != null)
        ? _citiesCache[_depto!]!
        : const <String>[];

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Búsqueda y Filtros',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('¿Dónde quieres buscar?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),

              _DropdownField<String>(
                value: _depto,
                icon: Icons.place_outlined,
                hint: _loadingDeptos ? 'Cargando...' : 'Departamento',
                items: _deptos,
                enabled: !_loadingDeptos,
                onChanged: (v) {
                  setState(() {
                    _depto = v;
                    _city = null;
                  });
                  if (v != null && v.isNotEmpty) {
                    _loadCities(v);
                  }
                },
              ),
              const SizedBox(height: 12),

              _DropdownField<String>(
                value: _city,
                icon: Icons.location_city_outlined,
                hint: _loadingCities ? 'Cargando...' : 'Ciudad / Municipio',
                items: cityItems,
                enabled:
                    !_loadingCities && (_depto != null && _depto!.isNotEmpty),
                onChanged: (v) => setState(() => _city = v),
              ),

              const SizedBox(height: 20),
              Text('Filtros',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _DropdownField<String>(
                      value: _type,
                      icon: Icons.pets_outlined,
                      hint: 'Tipo de mascota',
                      items: _tipos,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField<String>(
                      value: _size,
                      icon: Icons.straighten_outlined,
                      hint: 'Tamaño',
                      items: _tallas,
                      onChanged: (v) => setState(() => _size = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _depto = _city = _type = _size = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Restablecer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _SearchResult(
                            depto: _depto,
                            city: _city,
                            type: _type,
                            size: _size,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Buscar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dropdown estilizado reutilizable
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.icon,
    this.enabled = true,
  });

  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        prefixIcon:
            icon != null ? Icon(icon, color: Colors.grey.shade700) : null,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(
                      e.toString().isEmpty
                          ? ''
                          : (e.toString()[0].toUpperCase() +
                              e.toString().substring(1)),
                    ),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
