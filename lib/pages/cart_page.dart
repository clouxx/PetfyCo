import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final _sb = Supabase.instance.client;
  bool _submitting = false;

  String _fmt(int price) =>
      '\$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final total = notifier.totalPrice;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Mi Carrito', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () {
                notifier.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Carrito vaciado')),
                );
              },
              child: const Text('Vaciar', style: TextStyle(color: AppColors.red)),
            ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyCart()
          : Column(
              children: [
                // ── Lista de productos ────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CartItemCard(
                      item: items[i],
                      onAdd: () => notifier.add(items[i]),
                      onDecrement: () => notifier.decrement(items[i].productId),
                      onRemove: () => notifier.remove(items[i].productId),
                    ),
                  ),
                ),

                // ── Resumen y botón ───────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${items.fold(0, (s, e) => s + e.quantity)} producto(s)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            Text(_fmt(total),
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : () => _showCheckoutForm(context, total),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.shopping_bag_outlined),
                            label: Text(
                              _submitting ? 'Procesando...' : 'Realizar pedido',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCheckoutForm(BuildContext context, int total) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Datos para entrega',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Total: ${_fmt(total + 8000)}',
                  style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('(incluye envío \$8.000)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDec('Nombre completo', Icons.person_outline),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Nombre requerido' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: _inputDec('WhatsApp / Celular', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 7) ? 'Teléfono requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressCtrl,
                decoration: _inputDec('Dirección (Medellín y área metro)', Icons.location_on_outlined),
                validator: (v) => (v == null || v.trim().length < 5) ? 'Dirección requerida' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    _createOrder(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      subtotal: total,
                    );
                  },
                  child: const Text('Confirmar pedido', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.purple, size: 20),
        filled: true,
        fillColor: AppColors.bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
      );

  Future<void> _createOrder({
    required String name,
    required String phone,
    required String address,
    required int subtotal,
  }) async {
    setState(() => _submitting = true);
    final items = ref.read(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    const shipping = 8000;
    final total = subtotal + shipping;

    try {
      final session = _sb.auth.currentSession;
      final userId = session?.user.id;
      final orderNumber = 'PFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // 1. Crear la orden en store_orders
      final orderRes = await _sb.from('store_orders').insert({
        'order_number': orderNumber,
        'user_id': userId,
        'status': 'pending',
        'subtotal': subtotal,
        'discount': 0,
        'shipping': shipping,
        'total': total,
        'billing_name': name,
        'billing_id_type': 'CC',
        'billing_id': phone,
        'billing_email': 'app@petfyco.com',
        'billing_phone': phone,
        'billing_address': address,
        'billing_city': 'Medellín',
        'billing_depto': 'Antioquia',
        'delivery_address': address,
        'delivery_city': 'Medellín',
        'delivery_depto': 'Antioquia',
        'payment_method': 'app_whatsapp',
        'payment_status': 'pending',
        'notes': 'Pedido desde app móvil — confirmar entrega por WhatsApp',
      }).select().single();

      final orderId = orderRes['id'] as String;

      // 2. Insertar items de la orden
      await _sb.from('store_order_items').insert(
        items.map((item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': item.name,
              'product_sku': null,
              'unit_price': item.price,
              'quantity': item.quantity,
              'subtotal': item.price * item.quantity,
            }).toList(),
      );

      // 3. Descontar stock de cada producto
      for (final item in items) {
        final prod = await _sb
            .from('store_products')
            .select('stock')
            .eq('id', item.productId)
            .single();
        final currentStock = (prod['stock'] as int?) ?? 0;
        final newStock = (currentStock - item.quantity).clamp(0, currentStock);
        await _sb
            .from('store_products')
            .update({'stock': newStock}).eq('id', item.productId);
      }

      notifier.clear();
      if (mounted) _showSuccess(orderNumber, phone, subtotal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear pedido. Intenta de nuevo.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess(String orderNumber, String phone, int subtotal) {
    final waText = Uri.encodeComponent(
      'Hola PetfyCo 🐾 Acabo de hacer el pedido $orderNumber desde la app. ¿Me confirman la entrega?',
    );
    final waUrl = Uri.parse('https://wa.me/573177931145?text=$waText');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Pedido creado! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.purple, size: 56),
            const SizedBox(height: 12),
            Text('Pedido #$orderNumber',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Tu pedido fue registrado. Escríbenos por WhatsApp para coordinar la entrega a domicilio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              if (await canLaunchUrl(waUrl)) {
                await launchUrl(waUrl, mode: LaunchMode.externalApplication);
              }
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Confirmar por WhatsApp'),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Tu carrito está vacío',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 8),
          Text('Agrega productos desde la tienda',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Ir a la tienda'),
          ),
        ],
      ),
    );
  }
}

// ── Cart Item Card ────────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onAdd,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onAdd;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  String _fmt(int price) =>
      '\$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen o emoji del producto
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _emojiBox(),
                    )
                  : _emojiBox(),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item.description,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(_fmt(item.price * item.quantity),
                      style: const TextStyle(
                          color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),

            // Controles cantidad
            Column(
              children: [
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.grey.shade400,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.purpleGlass),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onDecrement,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.remove, size: 16, color: AppColors.purple),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      InkWell(
                        onTap: onAdd,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(Icons.add, size: 16, color: AppColors.purple),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiBox() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.purpleGlass,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
      );
}
