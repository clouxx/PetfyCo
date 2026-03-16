import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

// ─── Coverage zones ───────────────────────────────────────────────────────────

const _medellin = ['medellín', 'medellin'];
const _metro = ['bello', 'itagüí', 'itagui', 'envigado', 'sabaneta', 'la estrella', 'copacabana'];
const _shippingByZone = {'medellin': 8000, 'metro': 10000, 'outside': 12000, 'unknown': 8000};
const _freeShippingThreshold = 150000;

String _coverageZone(String city, String depto) {
  if (city.isEmpty || depto.isEmpty) return 'unknown';
  if (depto.toLowerCase() != 'antioquia') return 'outside';
  final n = city.toLowerCase().trim();
  if (_medellin.contains(n)) return 'medellin';
  if (_metro.contains(n)) return 'metro';
  return 'outside';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _depto = 'Antioquia';

  static const _deptos = [
    'Antioquia', 'Bogotá D.C.', 'Atlántico', 'Valle del Cauca',
    'Cundinamarca', 'Santander', 'Risaralda', 'Caldas', 'Otro',
  ];

  String get _zone => _coverageZone(_cityCtrl.text, _depto);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  String _fmt(int price) => '\$${price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final subtotal = notifier.totalPrice;
    final isFreeShipping = subtotal >= _freeShippingThreshold;
    final shipping = isFreeShipping ? 0 : (_shippingByZone[_zone] ?? 8000);
    final total = subtotal + shipping;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Finalizar pedido',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Resumen del pedido ──────────────────────────────
              _SectionCard(
                title: 'Resumen del pedido',
                child: Column(
                  children: [
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item.imageUrl != null
                                    ? Image.network(
                                        item.imageUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _EmojiBox(item.emoji),
                                      )
                                    : _EmojiBox(item.emoji),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text('x${item.quantity}',
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              Text(_fmt(item.price * item.quantity),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navy,
                                      fontSize: 13)),
                            ],
                          ),
                        )),
                    const Divider(height: 20),
                    _SummaryRow('Subtotal', _fmt(subtotal)),
                    _SummaryRow(
                        'Envío', isFreeShipping ? 'Gratis 🎉' : _fmt(shipping)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(_fmt(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.purple)),
                      ],
                    ),
                    if (isFreeShipping) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '¡Envío gratis por compra mayor a \$150.000!',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Datos de entrega ────────────────────────────────
              _SectionCard(
                title: 'Datos de entrega',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _dec('Nombre completo', Icons.person_outline),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Nombre requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration:
                          _dec('WhatsApp / Celular', Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Teléfono requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration:
                          _dec('Dirección de entrega', Icons.home_outlined),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'Dirección requerida'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _depto,
                            decoration:
                                _dec('Departamento', Icons.map_outlined),
                            isExpanded: true,
                            items: _deptos
                                .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _depto = v ?? 'Antioquia'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration:
                                _dec('Ciudad', Icons.location_city_outlined),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Ciudad requerida'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CoverageBadge(zone: _zone),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Método de pago ──────────────────────────────────
              _SectionCard(
                title: 'Método de pago',
                child: Column(
                  children: [
                    _PaymentOption(
                      icon: Icons.credit_card_outlined,
                      title: 'Pagar con Wompi',
                      subtitle:
                          'Tarjeta, PSE, Nequi, Bancolombia — abre la tienda web',
                      color: AppColors.purple,
                      onTap: _submitting
                          ? null
                          : () => _payWithWompi(),
                    ),
                    const SizedBox(height: 10),
                    _PaymentOption(
                      icon: Icons.chat_bubble_outline,
                      title: 'WhatsApp / Transferencia',
                      subtitle:
                          'Reserva el pedido y coordina el pago por WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: _submitting
                          ? null
                          : () => _payWithWhatsApp(subtotal, shipping, total),
                    ),
                    if (_submitting) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.purple, size: 20),
        filled: true,
        fillColor: AppColors.bgLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
      );

  void _payWithWompi() {
    if (!_formKey.currentState!.validate()) return;
    launchUrl(Uri.parse('https://petfyco.com/checkout'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _payWithWhatsApp(
      int subtotal, int shipping, int total) async {
    if (!_formKey.currentState!.validate()) return;
    await _createOrder(
        subtotal: subtotal,
        shipping: shipping,
        total: total,
        paymentMethod: 'app_whatsapp');
  }

  Future<void> _createOrder({
    required int subtotal,
    required int shipping,
    required int total,
    required String paymentMethod,
  }) async {
    setState(() => _submitting = true);
    final items = ref.read(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    try {
      final userId = _sb.auth.currentSession?.user.id;
      final orderNumber =
          'PFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final orderRes = await _sb.from('store_orders').insert({
        'order_number': orderNumber,
        'user_id': userId,
        'status': 'pending',
        'subtotal': subtotal,
        'discount': 0,
        'shipping': shipping,
        'total': total,
        'billing_name': _nameCtrl.text.trim(),
        'billing_id_type': 'CC',
        'billing_id': _phoneCtrl.text.trim(),
        'billing_email': 'app@petfyco.com',
        'billing_phone': _phoneCtrl.text.trim(),
        'billing_address': _addressCtrl.text.trim(),
        'billing_city': _cityCtrl.text.trim(),
        'billing_depto': _depto,
        'delivery_address': _addressCtrl.text.trim(),
        'delivery_city': _cityCtrl.text.trim(),
        'delivery_depto': _depto,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'notes': 'Pedido desde app móvil',
      }).select().single();

      final orderId = orderRes['id'] as String;

      await _sb.from('store_order_items').insert(
        items
            .map((item) => {
                  'order_id': orderId,
                  'product_id': item.productId,
                  'product_name': item.name,
                  'product_sku': null,
                  'unit_price': item.price,
                  'quantity': item.quantity,
                  'subtotal': item.price * item.quantity,
                })
            .toList(),
      );

      // Descontar stock
      for (final item in items) {
        final prod = await _sb
            .from('store_products')
            .select('stock')
            .eq('id', item.productId)
            .single();
        final current = (prod['stock'] as int?) ?? 0;
        final newStock = (current - item.quantity).clamp(0, current);
        await _sb
            .from('store_products')
            .update({'stock': newStock}).eq('id', item.productId);
      }

      notifier.clear();
      if (mounted) _showSuccess(orderNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al crear pedido. Intenta de nuevo.'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess(String orderNumber) {
    final waText = Uri.encodeComponent(
        'Hola PetfyCo 🐾 Acabo de hacer el pedido $orderNumber desde la app. ¿Me confirman la entrega?');
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
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Tu pedido fue registrado. Escríbenos por WhatsApp para coordinar la entrega a domicilio.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                Navigator.pop(context); // dialog
                Navigator.pop(context); // checkout page
                Navigator.pop(context); // cart page
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.navy)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}

class _EmojiBox extends StatelessWidget {
  const _EmojiBox(this.emoji);
  final String emoji;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.purpleGlass,
            borderRadius: BorderRadius.circular(8)),
        child:
            Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
      );
}

class _CoverageBadge extends StatelessWidget {
  const _CoverageBadge({required this.zone});
  final String zone;

  @override
  Widget build(BuildContext context) {
    switch (zone) {
      case 'medellin':
        return _badge(
          Icons.check_circle_outline,
          '¡Zona de cobertura!',
          'Medellín — entrega en 1 día hábil',
          Colors.green.shade50,
          Colors.green.shade300,
          Colors.green.shade700,
        );
      case 'metro':
        return _badge(
          Icons.check_circle_outline,
          '¡Zona de cobertura!',
          'Área metropolitana — 1 a 2 días hábiles',
          Colors.green.shade50,
          Colors.green.shade300,
          Colors.green.shade700,
        );
      case 'outside':
        return _badge(
          Icons.warning_amber_outlined,
          'Posible zona fuera de cobertura',
          'Enviamos al área metropolitana de Medellín. Te contactaremos para confirmar.',
          Colors.orange.shade50,
          Colors.orange.shade300,
          Colors.orange.shade700,
        );
      default:
        return _badge(
          Icons.location_on_outlined,
          'Ingresa ciudad y departamento',
          'Verificaremos cobertura en tu zona.',
          Colors.grey.shade50,
          Colors.grey.shade200,
          Colors.grey.shade600,
        );
    }
  }

  Widget _badge(IconData icon, String title, String sub, Color bg, Color border,
          Color fg) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: fg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11, color: fg.withOpacity(0.85))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
}
