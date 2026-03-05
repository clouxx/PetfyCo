import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class CrossSellModal extends StatelessWidget {
  const CrossSellModal({
    super.key,
    required this.petName,
    required this.petSpecies,
  });

  final String petName;
  final String petSpecies; // 'perro', 'gato', etc

  // Categorías de muestra por especie para hacer up-selling
  List<Map<String, dynamic>> get _suggestedProducts {
    final act = petSpecies.toLowerCase();
    if (act == 'gato') {
      return [
        {'title': 'Alimento Premium', 'desc': 'Nutrición balanceada para gatos', 'emoji': '🐱', 'price': '\$52.000'},
        {'title': 'Arena Sanitaria', 'desc': 'Control de olores 10kg', 'emoji': '🚽', 'price': '\$35.000'},
        {'title': 'Antipulgas', 'desc': 'Protección total 1 mes', 'emoji': '🔬', 'price': '\$25.000'},
      ];
    }
    // Default: Perros u otras especies
    return [
      {'title': 'Alimento Adulto', 'desc': 'Nutrición balanceada para perros', 'emoji': '🐾', 'price': '\$65.000'},
      {'title': 'Shampoo Avena', 'desc': 'Baño suave y cuidado de la piel', 'emoji': '🛁', 'price': '\$28.000'},
      {'title': 'Desparasitante', 'desc': 'Protección interna completa', 'emoji': '💊', 'price': '\$18.000'},
    ];
  }

  static Future<void> show(BuildContext context, {required String petName, required String petSpecies}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrossSellModal(petName: petName, petSpecies: petSpecies),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prods = _suggestedProducts;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          
          // Imagen/Icono Celebración
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('🎉', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          
          // Título y Subtítulo
          Text(
            '¡Prepárate para recibir a $petName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Lleva todo lo que necesita tu nuevo mejor amigo hasta la puerta de tu casa.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Productos Sugeridos
          Column(
            children: prods.map((p) => _buildProductTile(p)).toList(),
          ),
          const SizedBox(height: 24),

          // CTA Princpial
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/tienda');  // Llevar a la tienda
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.orange.withOpacity(0.4),
            ),
            child: const Text(
              'Ir a PetfyCo Tienda 🛍',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Comprar en otro momento', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(p['emoji'], style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(p['desc'], style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            p['price'],
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
