Widget _buildPetCard(Map<String, dynamic> pet) {
  final edadMeses = pet['edad_meses'] as int?;
  final edadAnios = edadMeses != null ? (edadMeses ~/ 12) : null;

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/pet_detail', extra: pet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen principal
          AspectRatio(
            aspectRatio: 16 / 9,
            child: pet['foto_url'] != null
                ? Image.network(
                    pet['foto_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 60, color: Colors.grey),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.pets, size: 60, color: Colors.grey),
                    ),
                  ),
          ),

          // Información básica
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (pet['raza'] != null)
                  Text(pet['raza'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),

                // Fila de detalles (edad, tamaño, temperamento)
                Wrap(
                  spacing: 6,
                  runSpacing: -4,
                  children: [
                    if (edadAnios != null)
                      _buildTag('${edadAnios} año${edadAnios > 1 ? "s" : ""}'),
                    if (pet['tamaño'] != null) _buildTag(pet['tamaño']),
                    if (pet['temperamento'] != null) _buildTag(pet['temperamento']),
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

Widget _buildTag(String text) {
  return Chip(
    label: Text(text, style: const TextStyle(fontSize: 12)),
    backgroundColor: Colors.blue.withValues(alpha: 0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
