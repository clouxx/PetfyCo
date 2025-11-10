import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // No traemos datos sensibles del dueño aquí
      final data = await _sb
          .from('pets')
          .select('''
            id, owner_id, nombre, especie, municipio, estado,
            talla, temperamento, edad_meses, descripcion,
            pet_photos(url, position)
          ''')
          .eq('id', widget.petId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _pet = data as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando: $e')),
      );
    }
  }

  Future<void> _contactOwner() async {
    final pet = _pet;
    if (pet == null) return;

    // 1) Diálogo de confirmación (igual a adoptar)
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AdoptConfirmDialog(petName: pet['nombre'] ?? 'la mascota'),
    );
    if (ok != true) return;

    // 2) Buscar contacto del dueño SIN mostrarlo
    try {
      final ownerId = pet['owner_id'] as String?;
      if (ownerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener contacto del dueño.')),
        );
        return;
      }

      final profile = await _sb
          .from('profiles')
          .select('whatsapp, phone')
          .eq('id', ownerId)
          .single();

      final number =
          (profile['whatsapp'] ?? profile['phone'] ?? '').toString().trim();

      if (number.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El dueño no tiene contacto registrado.')),
        );
        return;
      }

      final msg =
          '¡Hola! Vi a *${pet['nombre']}* en PetfyCo y me gustaría adoptar. ¿Podemos hablar?';

      // Preferimos WhatsApp; si falla intentamos tel:
      final wa = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(wa)) {
        await launchUrl(wa, mode: LaunchMode.externalApplication);
        return;
      }

      final tel = Uri.parse('tel:$number');
      if (await canLaunchUrl(tel)) {
        await launchUrl(tel, mode: LaunchMode.externalApplication);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pude abrir una app de contacto en este dispositivo.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al contactar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pet == null) {
      return const Scaffold(body: Center(child: Text('Mascota no encontrada')));
    }

    final pet = _pet!;
    final photos = (pet['pet_photos'] as List?)
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    photos.sort((a, b) =>
        (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
    final imageUrl = photos.isNotEmpty ? photos.first['url'] as String? : null;

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
                        child: Icon(Icons.pets, size: 40, color: AppColors.navy),
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
            // Mensaje genérico (sin datos del dueño)
            Text('Contacto',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Para cuidar la privacidad, no mostramos los datos del dueño. '
              'Usa los botones para enviar tu intención de adopción.',
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _contactOwner, // hace lo mismo que adoptar
                    icon: const Icon(Icons.call),
                    label: const Text('Llamar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _contactOwner, // hace lo mismo que adoptar
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
              'Si deseas continuar, te llevaré a contactar sobre ${'' + petName}.',
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
                    icon: const Icon(Icons.chat),
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
