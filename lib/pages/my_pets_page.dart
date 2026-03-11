import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class MyPetsPage extends StatefulWidget {
  const MyPetsPage({super.key});

  @override
  State<MyPetsPage> createState() => _MyPetsPageState();
}

class _MyPetsPageState extends State<MyPetsPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _pets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return;
      final data = await _sb
          .from('pets')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _pets = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error loading my pets: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String petId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar publicación?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _sb.from('pets').delete().eq('id', petId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicación eliminada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _estadoColor(String? estado) {
    switch (estado) {
      case 'perdido': return Colors.red;
      case 'encontrado': return Colors.green;
      case 'adoptado': return Colors.blue;
      default: return AppColors.orange;
    }
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case 'perdido': return 'Perdido';
      case 'encontrado': return 'Encontrado';
      case 'adoptado': return 'Adoptado';
      default: return 'En adopción';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis mascotas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/publish');
          _load();
        },
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _pets.length,
                    itemBuilder: (_, i) => _buildCard(_pets[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aún no has publicado ninguna mascota',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await context.push('/publish');
              _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Publicar una mascota'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> pet) {
    final fotos = pet['fotos'] as List<dynamic>?;
    final imageUrl = (fotos != null && fotos.isNotEmpty) ? fotos.first as String : null;
    final estado = pet['estado'] as String?;
    final nombre = pet['nombre'] ?? pet['name'] ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? '';
    final municipio = pet['municipio'] as String? ?? '';
    final depto = pet['depto'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/pet/${pet['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.pets, color: Colors.grey.shade400, size: 36),
                      ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _estadoColor(estado).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _estadoLabel(estado),
                            style: TextStyle(
                              color: _estadoColor(estado),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (especie.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(especie, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                    if (municipio.isNotEmpty || depto.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              [municipio, depto].where((s) => s.isNotEmpty).join(', '),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Acciones
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: AppColors.purple, size: 22),
                    onPressed: () async {
                      await context.push('/publish?editId=${pet['id']}');
                      _load();
                    },
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    onPressed: () => _delete(pet['id'] as String),
                    tooltip: 'Eliminar',
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
