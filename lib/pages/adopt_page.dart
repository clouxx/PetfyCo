import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class AdoptPage extends StatefulWidget {
  const AdoptPage({super.key});

  @override
  State<AdoptPage> createState() => _AdoptPageState();
}

class _AdoptPageState extends State<AdoptPage> {
  final _sb = Supabase.instance.client;

  List<Map<String, dynamic>> _pets = [];
  List<Map<String, dynamic>> _myAdoptions = [];
  bool _loading = true;
  bool _loadingMy = false;

  String _tabFilter = 'descubrir'; // 'descubrir' | 'mis_adopciones'
  String _speciesFilter = 'todos';

  // Filtros activos
  String? _filterDepto;
  String? _filterCiudad;
  String? _filterTalla;

  int get _activeFilterCount =>
      [_filterDepto, _filterCiudad, _filterTalla].where((f) => f != null && f.isNotEmpty).length;

  @override
  void initState() {
    super.initState();
    _loadPets();
    _loadMyAdoptions();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    try {
      var query = _sb.from('pets').select('''
        id, owner_id, nombre, especie, municipio, depto, estado, talla,
        temperamento, edad_meses, sexo, created_at,
        pet_photos(url, position)
      ''').eq('estado', 'publicado').order('created_at', ascending: false).limit(100);

      final data = await query.timeout(const Duration(seconds: 15));
      List<Map<String, dynamic>> allPets = List<Map<String, dynamic>>.from(data);

      if (_speciesFilter != 'todos') {
        allPets = allPets
            .where((p) => (p['especie'] ?? '').toString().toLowerCase() == _speciesFilter)
            .toList();
      }
      if (_filterDepto != null && _filterDepto!.isNotEmpty) {
        final d = _filterDepto!.trim().toLowerCase();
        allPets = allPets.where((p) => (p['depto'] ?? '').toString().toLowerCase() == d).toList();
      }
      if (_filterCiudad != null && _filterCiudad!.isNotEmpty) {
        final c = _filterCiudad!.trim().toLowerCase();
        allPets =
            allPets.where((p) => (p['municipio'] ?? '').toString().toLowerCase() == c).toList();
      }
      if (_filterTalla != null && _filterTalla!.isNotEmpty) {
        final t = _filterTalla!.trim().toLowerCase();
        allPets = allPets.where((p) => (p['talla'] ?? '').toString().toLowerCase() == t).toList();
      }

      setState(() {
        _pets = allPets;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _loadMyAdoptions() async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _loadingMy = true);
    try {
      final data = await _sb
          .from('adoption_interests')
          .select('''
            id, created_at,
            pets!inner(id, nombre, especie, municipio, depto, estado, talla, edad_meses, sexo, owner_id,
              pet_photos(url, position))
          ''')
          .eq('user_id', me)
          .order('created_at', ascending: false);
      setState(() {
        _myAdoptions = List<Map<String, dynamic>>.from(data);
        _loadingMy = false;
      });
    } catch (_) {
      setState(() => _loadingMy = false);
    }
  }

  Future<void> _showSearchSheet() async {
    final result = await showModalBottomSheet<_AdoptSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdoptSearchSheet(
        sb: _sb,
        initialDepto: _filterDepto,
        initialCiudad: _filterCiudad,
        initialTalla: _filterTalla,
      ),
    );
    if (result == null) return;
    setState(() {
      _filterDepto = result.depto;
      _filterCiudad = result.ciudad;
      _filterTalla = result.talla;
    });
    _loadPets();
  }

  Future<void> _intentAdopt(Map<String, dynamic> pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AdoptDialog(petName: pet['nombre'] ?? 'esta mascota'),
    );
    if (ok != true) return;

    try {
      final me = _sb.auth.currentUser?.id;
      final ownerId = pet['owner_id'];
      if (ownerId == null) return;

      // Guardar interés de adopción
      if (me != null) {
        await _sb.from('adoption_interests').upsert(
          {'user_id': me, 'pet_id': pet['id']},
          onConflict: 'user_id,pet_id',
        );
        _loadMyAdoptions();
      }

      final profile = await _sb
          .from('profiles')
          .select('whatsapp, phone, display_name')
          .eq('id', ownerId)
          .single();
      final phone = (profile['whatsapp'] ?? profile['phone'] ?? '').toString().trim();
      if (phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('El dueño no tiene WhatsApp.')));
        }
        return;
      }
      final msg =
          '¡Hola! Vi a *${pet['nombre']}* en PetfyCo y me gustaría adoptarlo. ¿Podemos hablar?';
      final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          boxShadow: [
            BoxShadow(
              color: AppColors.blue,
              blurRadius: 90,
              spreadRadius: -40,
              offset: Offset(0, -20),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('¡Tu nuevo amigo te espera!',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => context.push('/publish'),
                          icon: const Icon(Icons.favorite_border,
                              size: 16, color: AppColors.purple),
                          label: const Text('Dar en adopción',
                              style: TextStyle(color: AppColors.purple, fontSize: 13)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tabs
                    Row(
                      children: ['descubrir', 'mis_adopciones'].map((tab) {
                        final label =
                            tab == 'descubrir' ? 'Descubrir' : 'Mis adopciones';
                        final isSelected = _tabFilter == tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _tabFilter = tab);
                              if (tab == 'mis_adopciones') _loadMyAdoptions();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.purple
                                    : const Color(0xFFF5F5F7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.purple
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Species chips + filter icon (solo en Descubrir)
                    if (_tabFilter == 'descubrir')
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _SpeciesChip(
                                      emoji: '🐾',
                                      label: 'Todos',
                                      selected: _speciesFilter == 'todos',
                                      onTap: () {
                                        setState(() => _speciesFilter = 'todos');
                                        _loadPets();
                                      }),
                                  const SizedBox(width: 8),
                                  _SpeciesChip(
                                      emoji: '🐶',
                                      label: 'Perros',
                                      selected: _speciesFilter == 'perro',
                                      onTap: () {
                                        setState(() => _speciesFilter = 'perro');
                                        _loadPets();
                                      }),
                                  const SizedBox(width: 8),
                                  _SpeciesChip(
                                      emoji: '🐱',
                                      label: 'Gatos',
                                      selected: _speciesFilter == 'gato',
                                      onTap: () {
                                        setState(() => _speciesFilter = 'gato');
                                        _loadPets();
                                      }),
                                ],
                              ),
                            ),
                          ),
                          // Lupa con badge de filtros activos
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.tune,
                                  color: _activeFilterCount > 0
                                      ? AppColors.purple
                                      : Colors.grey.shade600,
                                ),
                                onPressed: _showSearchSheet,
                              ),
                              if (_activeFilterCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: AppColors.purple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$_activeFilterCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // ─── Contenido ──────────────────────────────────────
              Expanded(
                child: _tabFilter == 'descubrir'
                    ? _buildDescubrir()
                    : _buildMisAdopciones(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescubrir() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No hay mascotas disponibles', style: TextStyle(color: Colors.grey)),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterDepto = _filterCiudad = _filterTalla = null;
                  });
                  _loadPets();
                },
                child: const Text('Limpiar filtros'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/publish'),
                icon: const Icon(Icons.add),
                label: const Text('Publicar mascota'),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPets,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 280,
        ),
        itemCount: _pets.length,
        itemBuilder: (context, i) {
          final pet = _pets[i];
          final me = _sb.auth.currentUser?.id;
          final isOwner = me != null && me == pet['owner_id'];
          return _AdoptPetCard(
            pet: pet,
            isOwner: isOwner,
            onTap: () => context.push('/pet/${pet['id']}'),
            onAdopt: () => _intentAdopt(pet),
          );
        },
      ),
    );
  }

  Widget _buildMisAdopciones() {
    if (_loadingMy) return const Center(child: CircularProgressIndicator());

    if (_myAdoptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No tienes adopciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando contactes a un refugio para adoptar,\naparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _tabFilter = 'descubrir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Explorar mascotas'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyAdoptions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: _myAdoptions.length,
        itemBuilder: (context, i) {
          final item = _myAdoptions[i];
          final pet = item['pets'] as Map<String, dynamic>;
          return _MyAdoptionCard(
            pet: pet,
            onTap: () => context.push('/pet/${pet['id']}'),
            onContact: () => _intentAdopt(pet),
          );
        },
      ),
    );
  }
}

// ─────────── Widgets auxiliares ────────────────────────────────────────────

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue.withOpacity(0.15) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.blue : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.navy : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptPetCard extends StatelessWidget {
  const _AdoptPetCard(
      {required this.pet,
      required this.isOwner,
      required this.onTap,
      required this.onAdopt});
  final Map<String, dynamic> pet;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? '';
    final municipio = pet['municipio'] as String? ?? '';
    final talla = pet['talla'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : edadMeses ~/ 12;
    final sexo = pet['sexo'] as String?;

    String? imageUrl;
    final photos = pet['pet_photos'];
    if (photos is List && photos.isNotEmpty) {
      final sorted = photos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ph())
                        : _ph(),
                  ),
                  if (sexo != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sexo.toLowerCase() == 'macho'
                              ? Colors.blue.shade100
                              : Colors.pink.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sexo.toLowerCase() == 'macho'
                              ? Icons.male
                              : Icons.female,
                          size: 14,
                          color: sexo.toLowerCase() == 'macho'
                              ? Colors.blue
                              : Colors.pink,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (especie.isNotEmpty)
                          _overlayTag(especie == 'perro' ? 'Perro' : 'Gato'),
                        if (edadAnios != null)
                          _overlayTag(
                              '$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                        if (talla != null && talla.isNotEmpty)
                          _overlayTag(
                              talla[0].toUpperCase() + talla.substring(1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                          child: Text(municipio,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (!isOwner) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onAdopt,
                        icon: const Icon(Icons.volunteer_activism, size: 14),
                        label: const Text('Adoptar',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(
        color: AppColors.purple.withOpacity(0.08),
        child: const Center(
            child: Icon(Icons.pets, size: 40, color: AppColors.purple)),
      );

  Widget _overlayTag(String label) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.white.withOpacity(0.72),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600)),
        ),
      );
}

// ─────────── Card de mis adopciones ─────────────────────────────────────────

class _MyAdoptionCard extends StatelessWidget {
  const _MyAdoptionCard(
      {required this.pet, required this.onTap, required this.onContact});
  final Map<String, dynamic> pet;
  final VoidCallback onTap;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? '';
    final municipio = pet['municipio'] as String? ?? '';
    final estado = pet['estado'] as String? ?? '';

    String? imageUrl;
    final photos = pet['pet_photos'];
    if (photos is List && photos.isNotEmpty) {
      final sorted = photos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: imageUrl != null
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (estado == 'adoptado')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Adoptado',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      especie == 'perro' ? '🐶 Perro' : '🐱 Gato',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(municipio,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onContact,
                        icon: const Icon(Icons.chat_bubble_outline, size: 14),
                        label: const Text('Contactar',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          side:
                              const BorderSide(color: AppColors.purple),
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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

  Widget _ph() => Container(
        color: AppColors.purple.withOpacity(0.08),
        child: const Center(
            child: Icon(Icons.pets, size: 32, color: AppColors.purple)),
      );
}

// ─────────── Dialog adoptar ──────────────────────────────────────────────────

class _AdoptDialog extends StatelessWidget {
  const _AdoptDialog({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('¡Te animaste! 🎉', textAlign: TextAlign.center),
      content: Text(
          'Vamos a conectarte con el dueño de $petName por WhatsApp para comenzar el proceso de adopción.',
          textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white),
          child: const Text('Contactar por WhatsApp'),
        ),
      ],
    );
  }
}

// ─────────── Sheet de Búsqueda y Filtros ─────────────────────────────────────

class _AdoptSearchResult {
  final String? depto, ciudad, talla;
  _AdoptSearchResult({this.depto, this.ciudad, this.talla});
}

class _AdoptSearchSheet extends StatefulWidget {
  const _AdoptSearchSheet({
    required this.sb,
    this.initialDepto,
    this.initialCiudad,
    this.initialTalla,
  });
  final SupabaseClient sb;
  final String? initialDepto;
  final String? initialCiudad;
  final String? initialTalla;

  @override
  State<_AdoptSearchSheet> createState() => _AdoptSearchSheetState();
}

class _AdoptSearchSheetState extends State<_AdoptSearchSheet> {
  List<String> _deptos = [];
  final Map<String, List<String>> _citiesCache = {};
  bool _loadingDeptos = true;
  bool _loadingCities = false;

  String? _depto;
  String? _ciudad;
  String? _talla;

  final _tallas = const ['pequeño', 'mediano', 'grande'];

  @override
  void initState() {
    super.initState();
    _depto = widget.initialDepto;
    _ciudad = widget.initialCiudad;
    _talla = widget.initialTalla;
    _loadDeptos().then((_) {
      if (_depto != null && _depto!.isNotEmpty) _loadCities(_depto!);
    });
  }

  Future<void> _loadDeptos() async {
    setState(() => _loadingDeptos = true);
    try {
      final set = <String>{};
      try {
        final res = await widget.sb.from('departments').select('name').order('name');
        if (res is List) {
          for (final row in res) {
            final v = (row['name'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
      } catch (_) {}
      if (set.isEmpty) {
        final res2 = await widget.sb.from('pets').select('depto').eq('estado', 'publicado');
        if (res2 is List) {
          for (final row in res2) {
            final v = (row['depto'] as String?)?.trim();
            if (v != null && v.isNotEmpty) set.add(v);
          }
        }
      }
      setState(() {
        _deptos = set.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
        final res2 = await widget.sb
            .from('pets')
            .select('municipio')
            .eq('depto', depto)
            .eq('estado', 'publicado');
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
    final cities =
        (_depto != null && _citiesCache[_depto!] != null) ? _citiesCache[_depto!]! : <String>[];
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Título
              Row(
                children: [
                  const Text('Búsqueda y Filtros',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),

              // Ubicación
              Text('¿Dónde quieres buscar?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple)),
              const SizedBox(height: 10),

              _AdoptDropdown(
                value: _depto,
                hint: _loadingDeptos ? 'Cargando...' : 'Departamento',
                icon: Icons.place_outlined,
                items: _deptos,
                enabled: !_loadingDeptos,
                onChanged: (v) {
                  setState(() {
                    _depto = v;
                    _ciudad = null;
                  });
                  if (v != null && v.isNotEmpty) _loadCities(v);
                },
              ),
              const SizedBox(height: 10),

              _AdoptDropdown(
                value: _ciudad,
                hint: _loadingCities ? 'Cargando...' : 'Ciudad / Municipio',
                icon: Icons.location_city_outlined,
                items: cities,
                enabled: !_loadingCities && _depto != null,
                onChanged: (v) => setState(() => _ciudad = v),
              ),

              const SizedBox(height: 20),

              // Filtros
              Text('Filtros',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple)),
              const SizedBox(height: 10),

              _AdoptDropdown(
                value: _talla,
                hint: 'Tamaño',
                icon: Icons.straighten_outlined,
                items: _tallas,
                onChanged: (v) => setState(() => _talla = v),
              ),

              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _depto = _ciudad = _talla = null;
                        });
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
                      onPressed: () => Navigator.pop(
                          context,
                          _AdoptSearchResult(
                              depto: _depto, ciudad: _ciudad, talla: _talla)),
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
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

// ─────────── Dropdown helper ──────────────────────────────────────────────────

class _AdoptDropdown extends StatelessWidget {
  const _AdoptDropdown({
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
        prefixIcon:
            icon != null ? Icon(icon, color: AppColors.purple, size: 20) : null,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purple),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (value != null && items.contains(value)) ? value : null,
          hint: Text(hint,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: enabled ? onChanged : null,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('— Todos —',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            ),
            ...items.map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
