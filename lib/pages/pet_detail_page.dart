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
      // No traemos datos sensibles del dueño
      final data = await _sb
          .from('pets')
          .select('''
            id, owner_id, nombre, especie, municipio, estado,
            talla, temperamento, edad_meses, descripcion,
            delete_after_at,
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

  Future<void> _contactOwner({required bool isLost}) async {
    final pet = _pet;
    if (pet == null) return;

    // 1) Confirmación (adopción vs encontrado)
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ContactConfirmDialog(
        petName: pet['nombre'] ?? 'la mascota',
        isLostFlow: isLost,
      ),
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

      final msg = isLost
          ? '¡Hola! Encontré a *${pet['nombre']}* reportado como perdido en PetfyCo. '
            'Puedo compartir ubicación y coordinar la entrega. Gracias.'
          : '¡Hola! Vi a *${pet['nombre']}* en PetfyCo y me gustaría adoptar. '
            '¿Podemos hablar?';

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

  Future<void> _ownerDeleteNow() async {
    if (_pet == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('Esta acción no se puede deshacer. ¿Eliminar ahora?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _sb.from('pets').delete().eq('id', _pet!['id'] as String);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación eliminada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando: $e')),
      );
    }
  }

  Future<void> _markFoundAndAskDelete() async {
    final sel = await showModalBottomSheet<_FoundAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _FoundSheet(),
    );
    if (sel == null || _pet == null) return;

    try {
      if (sel == _FoundAction.deleteNow) {
        await _ownerDeleteNow();
      } else {
        // Encontrado → lo regresamos a "publicado" y programamos borrado en 7 días
        await _sb
            .from('pets')
            .update({
              'estado': 'publicado',
              'delete_after_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
            })
            .eq('id', _pet!['id'] as String);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcado como encontrado. Se eliminará automáticamente en 7 días.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _markAdopted() async {
    if (_pet == null) return;
    try {
      // Adoptado → programar borrado en 7 días
      await _sb
          .from('pets')
          .update({
            'estado': 'adoptado',
            'delete_after_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
          })
          .eq('id', _pet!['id'] as String);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcado como adoptado. Se eliminará automáticamente en 7 días.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final estado = (pet['estado'] as String?)?.toLowerCase() ?? 'publicado';
    final isLost = estado == 'perdido';
    final isPublishOrReserved = estado == 'publicado' || estado == 'reservado';
    final meId = _sb.auth.currentUser?.id;
    final isOwner = meId != null && meId == pet['owner_id'];

    final photos = (pet['pet_photos'] as List?)
            ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    photos.sort((a, b) =>
        (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
    final imageUrl = photos.isNotEmpty ? photos.first['url'] as String? : null;

    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);
    final DateTime? deleteAfterAt = pet['delete_after_at'] != null
        ? DateTime.tryParse(pet['delete_after_at'].toString())?.toLocal()
        : null;

    String? deletionBanner;
    if (deleteAfterAt != null) {
      deletionBanner =
          'Esta publicación se eliminará automáticamente el '
          '${_fmtDate(deleteAfterAt)}.';
    }

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
                if (isLost)
                  Chip(
                    label: const Text(' Perdido ',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: Colors.red.withOpacity(0.9),
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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

            if (deletionBanner != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(deletionBanner)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            // Mensaje genérico de contacto
            Text('Contacto',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              isLost
                  ? 'Si encontraste a ${pet['nombre'] ?? 'la mascota'}, por favor contacta al dueño para coordinar la entrega.'
                  : 'Para cuidar la privacidad, no mostramos los datos del dueño. '
                    'Usa los botones para enviar tu intención de adopción.',
            ),

            const SizedBox(height: 16),
            Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _contactOwner(isLost: isLost),
                      icon: const Icon(Icons.call),
                      label: Text(isLost ? 'Llamar dueño' : 'Llamar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _contactOwner(isLost: isLost),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(isLost ? 'WhatsApp dueño' : 'WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // mismo verde que el botón “Continuar”
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

            // ----- Acciones del dueño -----
            if (isOwner) ...[
              const SizedBox(height: 24),
              Text('Acciones del dueño',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              if (isLost)
                ElevatedButton.icon(
                  onPressed: _markFoundAndAskDelete,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Marcar encontrado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),

              if (isPublishOrReserved) ...[
                if (isLost) const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _markAdopted,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar adoptado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              // Eliminar ahora (siempre disponible para el dueño)
              ElevatedButton.icon(
                onPressed: _ownerDeleteNow,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ],
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

  String _fmtDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}

class _ContactConfirmDialog extends StatelessWidget {
  const _ContactConfirmDialog({
    required this.petName,
    required this.isLostFlow,
  });

  final String petName;
  final bool isLostFlow;

  @override
  Widget build(BuildContext context) {
    final title = isLostFlow ? '¡Gracias por ayudar!' : '¡Muchas gracias!';
    final body = isLostFlow
        ? 'Vas a contactar al dueño para informar que encontraste a $petName. '
          'Por seguridad, coordinen la entrega en un lugar público.'
        : 'La adopción es un acto de amor y responsabilidad. '
          'Si deseas continuar, te llevaré a contactar sobre $petName.';

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
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            Text(
              body,
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

/// ----- Hoja para "Encontrado" (solo dueño) -----
enum _FoundAction { markAndDeleteIn7Days, deleteNow }

class _FoundSheet extends StatelessWidget {
  const _FoundSheet();

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
              subtitle: const Text('Se quitará de “Perdidos” y se eliminará en 7 días.'),
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
