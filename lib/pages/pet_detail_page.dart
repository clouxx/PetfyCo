import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class PetDetailPage extends StatefulWidget {
  final String petId;
  const PetDetailPage({super.key, required this.petId});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? _pet;
  Map<String, dynamic>? _owner; // perfil del dueño
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('pets')
          .select('''
            id, owner_id, nombre, especie, municipio, estado, talla,
            temperamento, edad_meses, descripcion,
            pet_photos(url, position)
          ''')
          .eq('id', widget.petId)
          .maybeSingle();

      if (data != null) {
        // ordenar fotos
        final photos = (data['pet_photos'] as List?)?.whereType<Map>().toList() ?? [];
        photos.sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
        data['pet_photos'] = photos;

        _pet = data;

        // cargar dueño (profiles)
        final ownerId = data['owner_id'] as String?;
        if (ownerId != null) {
          _owner = await _sb
              .from('profiles')
              .select('id, full_name, phone')
              .eq('id', ownerId)
              .maybeSingle();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adopt() async {
    try {
      await _sb.from('pets').update({'estado': 'adoptado'}).eq('id', widget.petId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('¡Gracias por adoptar!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _sb.auth.currentUser?.id;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pet == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: Text('Mascota no encontrada')),
      );
    }

    final pet = _pet!;
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? 'desconocido';
    final municipio = (pet['municipio'] as String?)?.trim() ?? 'Colombia';
    final estado = pet['estado'] as String? ?? 'publicado';
    final talla = pet['talla'] as String?;
    final temperamento = pet['temperamento'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);
    final isOwner = me != null && me == pet['owner_id'];

    String? imageUrl;
    final photos = (pet['pet_photos'] as List?)?.whereType<Map>().toList() ?? [];
    if (photos.isNotEmpty) imageUrl = photos.first['url'] as String?;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(nombre),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.pets))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto principal
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.blue.withOpacity(0.12),
                        child: const Center(
                          child: Icon(Icons.pets, size: 40, color: AppColors.navy),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Nombre + ubicación
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 16, color: AppColors.pink),
                          const SizedBox(width: 6),
                          Text(
                            municipio,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(' ${especie == "perro" ? "Perro" : "Gato"} '),
                if (edadAnios != null)
                  _chip(' $edadAnios año${edadAnios == 1 ? "" : "s"} '),
                if (talla != null && talla.isNotEmpty) _chip(' ${_cap(talla)} '),
                if (temperamento != null && temperamento.isNotEmpty)
                  _chip(' ${_cap(temperamento)} '),
                _estadoChip(estado),
              ],
            ),
            const SizedBox(height: 18),

            // Descripción
            Text('Descripción',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              (pet['descripcion'] as String?)?.trim().isNotEmpty == true
                  ? (pet['descripcion'] as String)
                  : 'Sin descripción',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),

            // --- NUEVO: Contacto del dueño ---
            if (_owner != null) _OwnerCard(owner: _owner!) else _OwnerCard(owner: {
              'full_name': 'No disponible',
              'phone': null,
            }),
            const SizedBox(height: 18),

            // Acciones
            Row(
              children: [
                if (!isOwner && estado == 'publicado')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _adopt,
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: const Text('Quiero adoptar'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/share/${pet['id']}'),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text.trim(), style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.withOpacity(0.10),
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _estadoChip(String estado) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (estado) {
      case 'perdido':
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.red.shade700;
        label = 'Perdido';
        break;
      case 'adoptado':
        bg = Colors.green.withOpacity(0.12);
        fg = Colors.green.shade700;
        label = 'Adoptado';
        break;
      default:
        bg = Colors.blueGrey.withOpacity(0.10);
        fg = Colors.blueGrey.shade700;
        label = 'Disponible';
    }

    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12, color: fg)),
      backgroundColor: bg,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _cap(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner});
  final Map<String, dynamic> owner;

  @override
  Widget build(BuildContext context) {
    final name = (owner['display_name'] as String?)?.trim();
    final phone = (owner['phone'] as String?)?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [
          AppColors.blue.withOpacity(0.12),
          AppColors.orange.withOpacity(0.10),
        ]),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.navy,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : 'Dueño',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  phone?.isNotEmpty == true ? phone! : 'Teléfono no disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (phone?.isNotEmpty == true)
            IconButton(
              tooltip: 'Llamar',
              onPressed: () {
                // si usas url_launcher, podrías lanzar: tel:$phone
              },
              icon: const Icon(Icons.phone),
            ),
        ],
      ),
    );
  }
}
