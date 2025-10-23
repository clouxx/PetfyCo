import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PetDetailPage extends StatefulWidget {
  const PetDetailPage({super.key, required this.petId});
  final String petId;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _pet;
  List<String> _photos = [];
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
            *,
            profiles:owner_id(display_name, phone),
            pet_photos(url, position)
          ''')
          .eq('id', widget.petId)
          .single();

      final petPhotos = data['pet_photos'] as List<dynamic>?;
      if (petPhotos != null && petPhotos.isNotEmpty) {
        final sortedPhotos = List<Map<String, dynamic>>.from(petPhotos);
        sortedPhotos.sort((a, b) =>
            (((a['position'] as int?) ?? 0)).compareTo(((b['position'] as int?) ?? 0)));
        _photos = sortedPhotos.map((p) => p['url'] as String).toList();
      }

      setState(() {
        _pet = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando mascota: $e')),
      );
    }
  }

  Future<void> _contactOwner() async {
    if (_pet == null) return;

    final profile = _pet!['profiles'] as Map<String, dynamic>?;
    if (profile == null) return;

    final phone = profile['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El dueño no tiene teléfono registrado')),
      );
      return;
    }

    final nombre = _pet!['nombre'];
    final message = Uri.encodeComponent(
      'Hola! Vi tu publicación de $nombre en PetfyCo y me gustaría saber más.',
    );
    final url = 'https://wa.me/+57$phone?text=$message';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_pet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Mascota no encontrada')),
      );
    }

    final nombre = _pet!['nombre'] as String? ?? 'Sin nombre';
    final especie = _pet!['especie'] as String? ?? 'desconocido';
    final raza = _pet!['raza'] as String?;
    final edadMeses = _pet!['edad_meses'] as int?;
    final talla = _pet!['talla'] as String?;
    final sexo = _pet!['sexo'] as String?;
    final temperamento = _pet!['temperamento'] as String?;
    final descripcion = _pet!['descripcion'] as String?;
    final estado = _pet!['estado'] as String? ?? 'publicado';
    final municipio = _pet!['municipio'] as String?;
    final profile = _pet!['profiles'] as Map<String, dynamic>?;
    final ownerName = (profile?['display_name'] as String?)?.trim();
    final ownerInitial = (ownerName?.isNotEmpty ?? false)
        ? ownerName![0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: compartir ficha
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_photos.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      _photos[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.blue.withOpacity(0.15),
                        child: const Icon(Icons.pets, size: 80),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 300,
                color: AppColors.blue.withOpacity(0.15),
                child: const Center(
                  child: Icon(Icons.pets, size: 80, color: AppColors.navy),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(
                        label: Text(_getEstadoLabel(estado)),
                        backgroundColor: _getEstadoColor(estado),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (municipio != null)
                    Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.pink),
                        const SizedBox(width: 8),
                        Text(
                          municipio,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalles',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.pets,
                            label: 'Especie',
                            value: especie == 'perro' ? 'Perro' : 'Gato',
                          ),
                          if (raza != null)
                            _DetailRow(
                              icon: Icons.category,
                              label: 'Raza',
                              value: raza,
                            ),
                          if (edadMeses != null)
                            _DetailRow(
                              icon: Icons.cake,
                              label: 'Edad',
                              value: _formatEdad(edadMeses),
                            ),
                          if (talla != null)
                            _DetailRow(
                              icon: Icons.straighten,
                              label: 'Talla',
                              value: talla,
                            ),
                          if (sexo != null)
                            _DetailRow(
                              icon: Icons.wc,
                              label: 'Sexo',
                              value: sexo == 'M' ? 'Macho' : 'Hembra',
                            ),
                          if (temperamento != null)
                            _DetailRow(
                              icon: Icons.emoji_emotions,
                              label: 'Temperamento',
                              value: temperamento,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (descripcion != null && descripcion.isNotEmpty) ...[
                    Text(
                      'Descripción',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          descripcion,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    'Publicado por',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(ownerInitial)),
                      title: Text(ownerName ?? 'Desconocido'),
                      subtitle: const Text('Ver perfil'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: navegar a perfil
                      },
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _contactOwner,
            icon: const Icon(Icons.chat),
            label: const Text('Contactar por WhatsApp'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Formatea edad desde meses (identificadores sin ñ)
  String _formatEdad(int meses) {
    if (meses < 12) {
      return '$meses ${meses == 1 ? 'mes' : 'meses'}';
    } else {
      final anios = meses ~/ 12;
      final mesesRestantes = meses % 12;
      if (mesesRestantes == 0) {
        return '$anios ${anios == 1 ? 'año' : 'años'}';
      } else {
        return '$anios ${anios == 1 ? 'año' : 'años'} y '
            '$mesesRestantes ${mesesRestantes == 1 ? 'mes' : 'meses'}';
      }
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'publicado':
        return 'Disponible';
      case 'adoptado':
        return 'Adoptado';
      case 'reservado':
        return 'Reservado';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'publicado':
        return AppColors.blue.withOpacity(0.2);
      case 'adoptado':
        return Colors.green.withOpacity(0.2);
      case 'reservado':
        return Colors.orange.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.blue),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
