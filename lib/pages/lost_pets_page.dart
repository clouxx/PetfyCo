import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class LostPetsPage extends StatefulWidget {
  const LostPetsPage({super.key});

  @override
  State<LostPetsPage> createState() => _LostPetsPageState();
}

class _LostPetsPageState extends State<LostPetsPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = _sb.from('pets').select('''
        *,
        profiles:owner_id(display_name, phone),
        pet_photos(url, position)
      ''');

      q = q.eq('estado', 'perdido');

      final data = await q.order('created_at', ascending: false).limit(40);

      setState(() {
        _pets = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando perdidos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Reportes de perdidos'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
              ? const Center(child: Text('No hay reportes de mascotas perdidas'))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 320,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: _pets.length,
                    itemBuilder: (_, i) => _LostCard(pet: _pets[i]),
                  ),
                ),
    );
  }
}

class _LostCard extends StatelessWidget {
  const _LostCard({required this.pet});
  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final municipio = pet['municipio'] as String? ?? 'Colombia';

    final photos = pet['pet_photos'] as List<dynamic>?;
    String? imageUrl;
    if (photos != null && photos.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(photos)
        ..sort((a, b) => ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
      imageUrl = sorted.first['url'] as String?;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pet/${pet['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                  : _ph(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text('PERDIDO', style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nombre,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: AppColors.pink),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(municipio, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _ph() => Container(
        color: AppColors.blue.withOpacity(0.12),
        child: const Center(child: Icon(Icons.pets, size: 40, color: AppColors.navy)),
      );
}
