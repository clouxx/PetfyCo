import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─── Estado → etiqueta / color ────────────────────────────────────────────────
const _statusLabel = {
  'pending':   'Pendiente',
  'paid':      'Pagado',
  'shipped':   'En camino',
  'delivered': 'Entregado',
  'cancelled': 'Cancelado',
};

const _statusColor = {
  'pending':   Color(0xFFFF9800), // naranja
  'paid':      Color(0xFF1565C0), // azul
  'shipped':   AppColors.purple,  // morado
  'delivered': Color(0xFF2E7D32), // verde
  'cancelled': AppColors.red,     // rojo
};

// ─── Page ─────────────────────────────────────────────────────────────────────

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  final _sb = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentSession?.user.id;
      if (userId == null) {
        setState(() { _orders = []; _loading = false; });
        return;
      }
      final data = await _sb
          .from('store_orders')
          .select('id, order_number, status, total, shipping, created_at, delivery_city, delivery_depto, payment_method')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      if (mounted) setState(() { _orders = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (e) {
      debugPrint('[Pedidos] _load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    final userId = _sb.auth.currentSession?.user.id;
    if (userId == null) return;

    _channel = _sb
        .channel('pedidos-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'store_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            if (mounted) {
              setState(() {
                _orders = _orders.map((o) {
                  return (o['id'] == updated['id']) ? {...o, ...updated} : o;
                }).toList();
              });
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Mis Pedidos',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _EmptyOrders()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrderCard(
                      order: _orders[i],
                      onTap: () => _showDetail(context, _orders[i]),
                    ),
                  ),
                ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _OrderDetailPage(orderId: order['id'] as String)),
    );
  }
}

// ─── Order card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  String _fmt(int price) =>
      '\$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final label = _statusLabel[status] ?? status;
    final color = _statusColor[status] ?? Colors.grey;
    final total = ((order['total'] as num?) ?? 0).toInt();
    final orderNumber = order['order_number'] as String? ?? '—';
    final city = order['delivery_city'] as String? ?? '';
    final depto = order['delivery_depto'] as String? ?? '';
    final createdAt = order['created_at'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(orderNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.navy)),
                      _StatusChip(label: label, color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_fmtDate(createdAt),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (city.isNotEmpty)
                        Text('$city, $depto',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      Text(_fmt(total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.purple,
                              fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Aún no tienes pedidos',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Visita la tienda y haz tu primer pedido 🐾',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
}

// ─── Order detail page ────────────────────────────────────────────────────────

class _OrderDetailPage extends StatefulWidget {
  const _OrderDetailPage({required this.orderId});
  final String orderId;

  @override
  State<_OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<_OrderDetailPage> {
  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await _sb
          .from('store_orders')
          .select()
          .eq('id', widget.orderId)
          .single();
      final items = await _sb
          .from('store_order_items')
          .select()
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          _order = Map<String, dynamic>.from(order);
          _items = List<Map<String, dynamic>>.from(items);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(int price) =>
      '\$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.day}/${l.month}/${l.year}  ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de pedido')),
        body: const Center(child: Text('No se encontró el pedido')),
      );
    }

    final status = _order!['status'] as String? ?? 'pending';
    final label = _statusLabel[status] ?? status;
    final color = _statusColor[status] ?? Colors.grey;
    final orderNumber = _order!['order_number'] as String? ?? '—';
    final subtotal = ((_order!['subtotal'] as num?) ?? 0).toInt();
    final shipping = ((_order!['shipping'] as num?) ?? 0).toInt();
    final total = ((_order!['total'] as num?) ?? 0).toInt();
    final address = _order!['delivery_address'] as String? ?? '';
    final city = _order!['delivery_city'] as String? ?? '';
    final depto = _order!['delivery_depto'] as String? ?? '';
    final paymentMethod = _order!['payment_method'] as String? ?? '';

    // Estimated delivery
    String eta = '';
    if (status == 'shipped') eta = 'En camino — llega hoy o mañana';
    else if (status == 'delivered') eta = 'Entregado';
    else if (status == 'pending' || status == 'paid') eta = '1-2 días hábiles tras confirmación';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: Text(orderNumber,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StatusChip(label: label, color: color),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Items ──────────────────────────────────────────
          _DetailCard(
            title: 'Productos',
            child: Column(
              children: _items.map((item) {
                final name = item['product_name'] as String? ?? '';
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final subtotalItem = ((item['subtotal'] as num?) ?? 0).toInt();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('x$qty',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(_fmt(subtotalItem),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.navy)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Totales ─────────────────────────────────────────
          _DetailCard(
            title: 'Resumen de pago',
            child: Column(
              children: [
                _Row('Subtotal', _fmt(subtotal)),
                _Row('Envío', shipping == 0 ? 'Gratis' : _fmt(shipping)),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(_fmt(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.purple)),
                  ],
                ),
                const SizedBox(height: 4),
                _Row('Método de pago', paymentMethod == 'app_whatsapp'
                    ? 'WhatsApp / Transferencia'
                    : paymentMethod == 'transferencia'
                        ? 'Transferencia bancaria'
                        : paymentMethod),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Entrega ─────────────────────────────────────────
          _DetailCard(
            title: 'Información de entrega',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty)
                  _Row('Dirección', '$address, $city, $depto'),
                if (eta.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_outlined, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(eta,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _Row('Fecha del pedido', _fmtDate(_order!['created_at'] as String?)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.navy)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
      );
}
