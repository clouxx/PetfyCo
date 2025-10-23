import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class PetDetailPage extends StatefulWidget {
  final int petId;
  const PetDetailPage({super.key, required this.petId});

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
    _loadPet();
  }

  Future<void> _loadPet() async {
    try {
      final data = await _sb
          .from('pets')
          .select('''
            id, nombre, especie, municipio, descripcion, edad_meses,
            talla, temperamento, estado,
            pet_photos(url, position)
          ''')
          .eq('id', widget.petId)
          .maybeSingle();

      setState(() {
        _pet = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar detalles: $e')),
        );
      }
      setState(() => _loading = false);
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
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Mascota no encontrada')),
      );
    }

    final pet = _pet!;
    final nombre = pet['nombre'] ?? 'Sin nombre';
    final especie = pet['especie'] ?? 'Desconocido';
    final municipio = pet['municipio'] ?? 'Colombia';
    final descripcion = pet['descripcion'] ?? 'Sin descripción';
    final talla = pet['talla'];
    final temperamento = pet['temperamento'];
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    // Ordenar fotos
    final petPhotos = pet['pet_photos'] as List<dynamic>?;
    List<String> imageUrls = [];
    if (petPhotos != null && petPhotos.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(petPhotos)
        ..sort((a, b) =>
            ((a['position'] as int?) ?? 0)
                .compareTo(((b['position'] as int?) ?? 0)));
      imageUrls = sorted.map((e) => e['url'] as String).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(nombre),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galería de fotos
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) => Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _ImagePlaceholder(),
                        ),
                      )
                    : const _ImagePlaceholder(),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre y ubicación
            Row(
              children: [
                Expanded(
                  child: Text(
                    nombre,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  especie == 'perro' ? Icons.pets : Icons.pets_outlined,
                  color: AppColors.navy,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: AppColors.pink),
                const SizedBox(width: 4),
                Text(
                  municipio,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chips informativos
            Wrap(
              spacing: 8,
              runSpacing: -4,
              children: [
                Chip(
                  label: Text(
                    especie == 'perro' ? 'Perro' : 'Gato',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: AppColors.blue.withOpacity(0.1),
                ),
                if (edadAnios != null)
                  Chip(
                    label: Text(
                      '$edadAnios año${edadAnios == 1 ? "" : "s"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.blue.withOpacity(0.1),
                  ),
                if (talla != null && talla.isNotEmpty)
                  Chip(
                    label: Text(talla, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.blue.withOpacity(0.1),
                  ),
                if (temperamento != null && temperamento.isNotEmpty)
                  Chip(
                    label: Text(temperamento,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.blue.withOpacity(0.1),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Descripción
            Text(
              'Descripción',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.grey[800]),
            ),
            const SizedBox(height: 32),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Quiero adoptar'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Funcionalidad en desarrollo')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enlace copiado')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blue.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.pets, color: AppColors.navy, size: 60),
      ),
    );
  }
}
