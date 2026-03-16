import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';
import 'cart_page.dart';

/// E-commerce store page — lee productos desde Supabase store_products
class TiendaPage extends ConsumerStatefulWidget {
  const TiendaPage({super.key});

  @override
  ConsumerState<TiendaPage> createState() => _TiendaPageState();
}

class _TiendaPageState extends ConsumerState<TiendaPage> {
  final _sb = Supabase.instance.client;

  String _selectedCategory = 'Todos';
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _allProducts = const [];
  bool _loading = true;

  // Emoji fallback por slug de categoría
  static const _catEmoji = {
    'nutricion': '🍖',
    'higiene': '🛁',
    'accesorios': '🏷️',
    'juguetes': '🎾',
    'salud': '💊',
    'camas': '🛏',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Cargar categorías activas
      final cats = await _sb
          .from('store_categories')
          .select('id, name, slug')
          .eq('active', true)
          .order('name');

      // Cargar productos activos con su categoría
      final prods = await _sb
          .from('store_products')
          .select('id, name, description, price, compare_price, images, featured, stock, category_id, store_categories(name, slug)')
          .eq('active', true)
          .gt('stock', 0)
          .order('featured', ascending: false)
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(cats);
          _allProducts = List<Map<String, dynamic>>.from(prods);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 'Todos') return _allProducts;
    return _allProducts.where((p) {
      final cat = p['store_categories'];
      if (cat == null) return false;
      return (cat['name'] as String?) == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartCount = ref.read(cartProvider.notifier).totalItems;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        leading: BackButton(
          color: AppColors.navy,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Tienda PetfyCo',
            style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🛍 PetfyCo Tienda',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('Nutrición y Limpieza a Domicilio',
                              style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      // ── Carrito con badge ──────────
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartPage()),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                color: AppColors.purple, size: 28),
                            if (cartCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: AppColors.orange,
                                  child: Text(
                                    cartCount > 9 ? '9+' : '$cartCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Banner logo ─────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/petfyco_nutricion.png',
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Category Chips ───────────────────────────────
                  if (_loading)
                    const SizedBox(height: 36)
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _catChip('Todos'),
                          ..._categories
                              .map((c) => _catChip(c['name'] as String))
                              .toList(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ─── Product Grid ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🐾',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'No hay productos disponibles',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 220,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final p = _filtered[i];
                              final cartQty = cartItems
                                  .where((e) => e.productId == (p['id'] as String? ?? ''))
                                  .fold(0, (s, e) => s + e.quantity);
                              return _ProductCard(
                                product: p,
                                catEmoji: _emojiForProduct(p),
                                inCartQty: cartQty,
                                onAdd: () => ref
                                    .read(cartProvider.notifier)
                                    .add(CartItem(
                                      productId: p['id'] as String? ?? '',
                                      name: p['name'] ?? '',
                                      description: p['description'] ?? '',
                                      price:
                                          ((p['price'] as num?) ?? 0).toInt(),
                                      emoji: _emojiForProduct(p),
                                      imageUrl: _firstImage(p),
                                    )),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String label) {
    final selected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.purple : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _emojiForProduct(Map<String, dynamic> p) {
    final cat = p['store_categories'];
    if (cat != null) {
      final slug = (cat['slug'] as String?) ?? '';
      return _catEmoji[slug] ?? '🐾';
    }
    return '🐾';
  }

  String? _firstImage(Map<String, dynamic> p) {
    final imgs = p['images'];
    if (imgs is List && imgs.isNotEmpty) return imgs.first as String?;
    return null;
  }
}

// ─────────── Product Card ────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.catEmoji,
    required this.inCartQty,
    required this.onAdd,
  });
  final Map<String, dynamic> product;
  final String catEmoji;
  final int inCartQty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final price = ((product['price'] as num?) ?? 0).toInt();
    final comparePrice = ((product['compare_price'] as num?) ?? 0).toInt();
    final featured = product['featured'] == true;
    final imageUrl = _firstImage();
    final formattedPrice =
        '\$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Imagen / emoji ───────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _emojiPlaceholder(),
                        )
                      : _emojiPlaceholder(),
                ),
                if (featured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Destacado',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (inCartQty > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('$inCartQty en carrito',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          // ─── Info ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(product['description'] ?? '',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formattedPrice,
                            style: const TextStyle(
                                color: AppColors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (comparePrice > 0)
                          Text(
                            '\$${comparePrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough),
                          ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: AppColors.purple, shape: BoxShape.circle),
                        child:
                            const Icon(Icons.add, color: Colors.white, size: 16),
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

  String? _firstImage() {
    final imgs = product['images'];
    if (imgs is List && imgs.isNotEmpty) return imgs.first as String?;
    return null;
  }

  Widget _emojiPlaceholder() => Container(
        decoration: BoxDecoration(
          color: AppColors.purple.withOpacity(0.07),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        width: double.infinity,
        child: Center(
            child: Text(catEmoji, style: const TextStyle(fontSize: 52))),
      );
}
