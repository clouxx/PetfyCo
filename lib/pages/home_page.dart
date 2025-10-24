import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class PetDetailPage extends StatefulWidget {
  final String id;
  const PetDetailPage({super.key, required this.id});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _pet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // pets + owner profile (full_name, phone)
      final data = await _sb
          .from('pets')
          .select('''
            id, owner_id, nombre, especie, municipio, estado, talla, temperamento, edad_meses, descripcion,
            pet_photos(url, position),
            profiles:owner_id ( full_name, phone )
          ''')
          .eq('id', widget.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _pet = data as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pet == null) {
      return const Scaffold(
        body: Center(child: Text('Mascota no encontrada')),
      );
    }

    final pet = _pet!;
    final photos = (pet['pet_photos'] as List?)
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    photos.sort((a, b) =>
        (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
    final imageUrl = photos.isNotEmpty ? photos.first['url'] as String? : null;

    final owner = pet['profiles'] as Map<String, dynamic>?;
    final ownerName = (owner?['full_name'] as String?) ?? 'Sin nombre';
    final ownerPhone = (owner?['phone'] as String?) ?? 'Sin teléfono';

    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(pet['nombre'] ?? 'Mascota'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.blue.withOpacity(0.12),
                      child: const Center(
                        child: Icon(Icons.pets,
                            size: 40, color: AppColors.navy),
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            // Título + ubicación
            Text(
              pet['nombre'] ?? 'Sin nombre',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: AppColors.pink),
                const SizedBox(width: 4),
                Text((pet['municipio'] as String?)?.trim().isNotEmpty == true
                    ? pet['municipio']
                    : 'Colombia'),
              ],
            ),
            const SizedBox(height: 12),

            // Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(' ${pet['especie'] == 'perro' ? 'Perro' : 'Gato'} '),
                if (edadAnios != null)
                  _chip(' $edadAnios año${edadAnios == 1 ? '' : 's'} '),
                if ((pet['talla'] as String?)?.isNotEmpty == true)
                  _chip(' ${pet['talla']} '),
                if ((pet['temperamento'] as String?)?.isNotEmpty == true)
                  _chip(' ${pet['temperamento']} '),
              ],
            ),

            const SizedBox(height: 20),
            Text('Descripción',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              (pet['descripcion'] as String?)?.trim().isNotEmpty == true
                  ? pet['descripcion']
                  : 'Sin descripción',
            ),

            const SizedBox(height: 20),
            // CONTACTO DEL DUEÑO
            Text('Contacto',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _contactRow(Icons.person_outline, ownerName),
            const SizedBox(height: 6),
            _contactRow(Icons.phone_outlined, ownerPhone),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // aquí podrías lanzar un intent tel: si estás en móvil nativo
                      // o copiar al portapapeles en web
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // abrir WhatsApp si quieres (web: wa.me)
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
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
}
