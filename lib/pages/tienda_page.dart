import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// E-commerce store page - PetfyCo Nutrición y Limpieza a Domicilio
class TiendaPage extends StatefulWidget {
  const TiendaPage({super.key});

  @override
  State<TiendaPage> createState() => _TiendaPageState();
}

class _TiendaPageState extends State<TiendaPage> {
  String _selectedCategory = 'Todos';

  final List<String> _categories = ['Todos', 'Alimentos', 'Baño y Limpieza', 'Accesorios', 'Salud'];

  final List<_Product> _products = [
    _Product(
      name: 'Royal Canin Adulto',
      description: 'Alimento seco para perros adultos 2kg',
      price: 65000,
      category: 'Alimentos',
      emoji: '🐾',
      badgeText: 'Más vendido',
    ),
    _Product(
      name: 'Hills Science Diet',
      description: 'Alimento premium para gatos 1.5kg',
      price: 52000,
      category: 'Alimentos',
      emoji: '🐱',
    ),
    _Product(
      name: 'Shampoo Antipulgas',
      description: 'Baño con protección antipulgas 500ml',
      price: 28000,
      category: 'Baño y Limpieza',
      emoji: '🛁',
    ),
    _Product(
      name: 'Kit de Aseo Completo',
      description: 'Cepillo, shampoo y cortauñas',
      price: 48000,
      category: 'Baño y Limpieza',
      emoji: '✂️',
      badgeText: 'Oferta',
    ),
    _Product(
      name: 'Collar GPS Smart',
      description: 'Rastreador GPS para mascotas',
      price: 120000,
      category: 'Accesorios',
      emoji: '📍',
    ),
    _Product(
      name: 'Cama Ortopédica',
      description: 'Cama con memoria de espuma M/L',
      price: 89000,
      category: 'Accesorios',
      emoji: '🛏',
    ),
    _Product(
      name: 'Vitaminas Multivitamínicas',
      description: 'Suplemento diario para perros y gatos',
      price: 35000,
      category: 'Salud',
      emoji: '💊',
    ),
    _Product(
      name: 'Antipulgas Pipeta',
      description: 'Protección 3 meses contra pulgas y garrapatas',
      price: 42000,
      category: 'Salud',
      emoji: '🔬',
    ),
  ];

  List<_Product> get _filtered => _selectedCategory == 'Todos'
      ? _products
      : _products.where((p) => p.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('🛍 PetfyCo Tienda', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('Nutrición y Limpieza a Domicilio', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carrito próximamente 🛒'))),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: const [
                            Icon(Icons.shopping_bag_outlined, color: AppColors.purple),
                            Positioned(
                              right: -4, top: -4,
                              child: CircleAvatar(radius: 7, backgroundColor: AppColors.purple, child: Text('0', style: TextStyle(color: Colors.white, fontSize: 9))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Banner Promo ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.purple, AppColors.purple.withOpacity(0.7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entrega a domicilio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('Todo lo que tu mascota necesita, en la puerta de tu casa.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Text('🚚', style: TextStyle(fontSize: 36)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Category Filters ─────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final selected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.purple : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(cat, style: TextStyle(
                                color: selected ? Colors.white : Colors.grey.shade700,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ─── Product Grid ─────────────────────────────────────
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 220,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _ProductCard(product: _filtered[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────── Product Model ───────────────────────────────────────────────────

class _Product {
  const _Product({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.emoji,
    this.badgeText,
  });
  final String name, description, category, emoji;
  final int price;
  final String? badgeText;
}

// ─────────── Product Card ────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final _Product product;

  @override
  Widget build(BuildContext context) {
    final formattedPrice = '\$${product.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product visual area
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  width: double.infinity,
                  child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 52))),
                ),
                if (product.badgeText != null)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                      child: Text(product.badgeText!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(product.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formattedPrice, style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 14)),
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} añadido al carrito 🛒'))),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
