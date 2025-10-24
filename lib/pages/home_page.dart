class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.isOwner,
    required this.onEdit,
    required this.onFound,
    required this.onAdopt,
  });

  final Map<String, dynamic> pet;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onFound;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final nombre = pet['nombre'] as String? ?? 'Sin nombre';
    final especie = pet['especie'] as String? ?? 'desconocido';
    final municipio = (pet['municipio'] as String?)?.trim();
    final estado = pet['estado'] as String? ?? 'publicado';
    final talla = pet['talla'] as String?;
    final temperamento = pet['temperamento'] as String?;
    final edadMeses = pet['edad_meses'] as int?;
    final edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);

    // Foto principal
    String? imageUrl;
    final petPhotosRaw = pet['pet_photos'];
    if (petPhotosRaw is List && petPhotosRaw.isNotEmpty) {
      final casted = petPhotosRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort((a, b) =>
            (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
      imageUrl = casted.first['url'] as String?;
    }

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGEN (tap abre el detalle)
          InkWell(
            onTap: () => context.push('/pet/${pet['id']}'),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                    )
                  : const _ImagePlaceholder(),
            ),
          ),

          // TÍTULO + UBICACIÓN (NEGRO) DEBAJO DE LA IMAGEN
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppColors.pink),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        municipio?.isNotEmpty == true ? municipio! : 'Colombia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CHIPS INFO
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
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
          ),

          const Spacer(),

          // BOTONES (también DEBAJO)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                if (isOwner) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (estado == 'perdido')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onFound,
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Encontrado'),
                      ),
                    ),
                ] else if (estado == 'publicado') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdopt,
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: const Text('Adoptar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chip gris
  Widget _chip(String text) {
    return Chip(
      label: Text(text.trim(), style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.blue.withOpacity(0.10),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // Chip de estado (rojo/verde) – sin “Reservado”
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
      label: Text(label, style: TextStyle(fontSize: 11, color: fg)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _cap(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
}
