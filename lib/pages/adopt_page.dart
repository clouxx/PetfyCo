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
  bool _loading = true;

  String _tabFilter = 'descubrir'; // 'descubrir' | 'mis_adopciones'
  String _speciesFilter = 'todos';  // 'todos' | 'perro' | 'gato'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    try {
      var query = _sb.from('pets').select('''
        id, owner_id, nombre, especie, municipio, depto, estado, talla,
        temperamento, edad_meses, sexo, created_at,
        pet_photos(url, position)
      ''').eq('estado', 'publicado').order('created_at', ascending: false).limit(100);

      final data = await query;
      List<Map<String, dynamic>> allPets = List<Map<String, dynamic>>.from(data);

      // Apply species filter
      if (_speciesFilter != 'todos') {
        allPets = allPets.where((p) => (p['especie'] ?? '').toString().toLowerCase() == _speciesFilter).toList();
      }

      // Apply name search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        allPets = allPets.where((p) => (p['nombre'] ?? '').toString().toLowerCase().contains(q)).toList();
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

  Future<void> _intentAdopt(Map<String, dynamic> pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AdoptDialog(petName: pet['nombre'] ?? 'esta mascota'),
    );
    if (ok != true) return;

    try {
      final ownerId = pet['owner_id'];
      if (ownerId == null) return;
      final profile = await _sb.from('profiles').select('whatsapp, phone, display_name').eq('id', ownerId).single();
      final phone = (profile['whatsapp'] ?? profile['phone'] ?? '').toString().trim();
      if (phone.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El dueño no tiene WhatsApp.')));
        return;
      }
      final msg = '¡Hola! Vi a *${pet['nombre']}* en PetfyCo y me gustaría adoptarlo. ¿Podemos hablar?';
      final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header Area ────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('¡Tu nuevo amigo te espera!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/publish'),
                        icon: const Icon(Icons.favorite_border, size: 16, color: AppColors.purple),
                        label: const Text('Dar en adopción', style: TextStyle(color: AppColors.purple, fontSize: 13)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pill Tab Filters (Descubrir / Mis Adopciones)
                  Row(
                    children: ['descubrir', 'mis_adopciones'].map((tab) {
                      final label = tab == 'descubrir' ? 'Descubrir' : 'Mis adopciones';
                      final isSelected = _tabFilter == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _tabFilter = tab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.purple : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Species chip row  +  search icon
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _SpeciesChip(emoji: '🐾', label: 'Todos', selected: _speciesFilter == 'todos',
                                  onTap: () { setState(() => _speciesFilter = 'todos'); _loadPets(); }),
                              const SizedBox(width: 8),
                              _SpeciesChip(emoji: '🐶', label: 'Perros', selected: _speciesFilter == 'perro',
                                  onTap: () { setState(() => _speciesFilter = 'perro'); _loadPets(); }),
                              const SizedBox(width: 8),
                              _SpeciesChip(emoji: '🐱', label: 'Gatos', selected: _speciesFilter == 'gato',
                                  onTap: () { setState(() => _speciesFilter = 'gato'); _loadPets(); }),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: AppColors.purple),
                        onPressed: () async {
                          final q = await showSearch<String?>(context: context, delegate: _PetSearchDelegate(_pets));
                          if (q != null) setState(() => _searchQuery = q);
                          _loadPets();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ─── Pet List ────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _pets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.pets, size: 60, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No hay mascotas disponibles', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/publish'),
                                icon: const Icon(Icons.add),
                                label: const Text('Publicar mascota'),
                              )
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPets,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
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
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────── Widgets auxiliares ────────────────────────────────────────────

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({required this.emoji, required this.label, required this.selected, required this.onTap});
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
          color: selected ? AppColors.purple.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.purple : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: selected ? AppColors.purple : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }
}

class _AdoptPetCard extends StatelessWidget {
  const _AdoptPetCard({required this.pet, required this.isOwner, required this.onTap, required this.onAdopt});
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
      final sorted = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with gender badge
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                        : _ph(),
                  ),
                  if (sexo != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sexo.toLowerCase() == 'macho' ? Colors.blue.shade100 : Colors.pink.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sexo.toLowerCase() == 'macho' ? Icons.male : Icons.female,
                          size: 14,
                          color: sexo.toLowerCase() == 'macho' ? Colors.blue : Colors.pink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info Area
            Padding(
              padding: const EdgeInsets.all(10),
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (especie.isNotEmpty) _tag(especie == 'perro' ? '🐶 Perro' : '🐱 Gato'),
                      if (edadAnios != null) _tag('$edadAnios año${edadAnios == 1 ? '' : 's'}'),
                      if (talla != null && talla.isNotEmpty) _tag(talla[0].toUpperCase() + talla.substring(1)),
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

  Widget _ph() => Container(
        color: AppColors.purple.withOpacity(0.08),
        child: const Center(child: Icon(Icons.pets, size: 40, color: AppColors.purple)),
      );

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.purple, fontWeight: FontWeight.w600)),
    );
  }
}

class _AdoptDialog extends StatelessWidget {
  const _AdoptDialog({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('¡Te animaste! 🎉', textAlign: TextAlign.center),
      content: Text('Vamos a conectarte con el dueño de $petName por WhatsApp para comenzar el proceso de adopción.', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple, foregroundColor: Colors.white),
          child: const Text('Contactar por WhatsApp'),
        ),
      ],
    );
  }
}

class _PetSearchDelegate extends SearchDelegate<String?> {
  _PetSearchDelegate(this.pets);
  final List<Map<String, dynamic>> pets;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) { close(context, query); return const SizedBox(); }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = pets.where((p) => (p['nombre'] ?? '').toString().toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.pets),
        title: Text(filtered[i]['nombre'] ?? ''),
        onTap: () => close(context, filtered[i]['nombre'] as String?),
      ),
    );
  }
}
