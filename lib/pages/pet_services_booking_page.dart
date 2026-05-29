import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─── Catálogo de servicios a domicilio ───────────────────────────────────────

class PetServicesPage extends StatefulWidget {
  const PetServicesPage({super.key});

  @override
  State<PetServicesPage> createState() => _PetServicesPageState();
}

class _PetServicesPageState extends State<PetServicesPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('pet_services')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[PetServicesPage] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Servicios a domicilio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/mis-reservas'),
            icon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.purple),
            label: const Text('Mis reservas',
                style: TextStyle(color: AppColors.purple, fontSize: 13)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _services.length,
                    itemBuilder: (_, i) => _ServiceCard(
                      service: _services[i],
                      onBook: () => _showBookingSheet(_services[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Próximamente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Estamos preparando servicios a domicilio para tu mascota.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(Map<String, dynamic> service) {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para reservar')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        service: service,
        sb: _sb,
        userId: uid,
        onBooked: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Reserva creada! Te contactaremos pronto.'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

// ─── Card de servicio ─────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onBook});
  final Map<String, dynamic> service;
  final VoidCallback onBook;

  String _fmt(num price) =>
      '\$${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final nombre = service['name'] as String? ?? '';
    final descripcion = service['description'] as String? ?? '';
    final precio = service['price'] as num?;
    final duracion = service['duration_minutes'] as int?;
    final imagen = service['image_url'] as String?;
    final categoria = service['category'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagen != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imagen,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.purple.withOpacity(0.08),
                  child: const Center(
                    child: Icon(Icons.pets, size: 48, color: AppColors.purple),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.pets, size: 40, color: AppColors.purple),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categoria.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(categoria,
                        style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (precio != null) ...[
                      Text(
                        _fmt(precio),
                        style: const TextStyle(
                            color: AppColors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (duracion != null)
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('$duracion min',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: const Text('Reservar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking sheet ────────────────────────────────────────────────────────────

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({
    required this.service,
    required this.sb,
    required this.userId,
    required this.onBooked,
  });
  final Map<String, dynamic> service;
  final SupabaseClient sb;
  final String userId;
  final VoidCallback onBooked;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _mascotaCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _mascotaCtrl.dispose();
    _direccionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mascotaCtrl.text.trim().isEmpty ||
        _direccionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos obligatorios')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.sb.from('pet_service_bookings').insert({
        'service_id': widget.service['id'],
        'user_id': widget.userId,
        'pet_name': _mascotaCtrl.text.trim(),
        'scheduled_at': _fecha.toIso8601String(),
        'address': _direccionCtrl.text.trim(),
        'notes': _notasCtrl.text.trim().isEmpty
            ? null
            : _notasCtrl.text.trim(),
        'status': 'pending',
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onBooked();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.service['nombre'] as String? ?? '';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Reservar — $nombre',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field('Nombre de tu mascota *', _mascotaCtrl, 'Ej: Firulais'),
            const SizedBox(height: 12),
            _field('Dirección de entrega *', _direccionCtrl,
                'Calle 10 #5-20, Medellín'),
            const SizedBox(height: 12),
            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.purple, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field('Notas adicionales', _notasCtrl,
                'Indicaciones especiales...', maxLines: 3, required: false),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Confirmar reserva',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.purple)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.purple),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mis Reservas ─────────────────────────────────────────────────────────────

class MisReservasPage extends StatefulWidget {
  const MisReservasPage({super.key});

  @override
  State<MisReservasPage> createState() => _MisReservasPageState();
}

class _MisReservasPageState extends State<MisReservasPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  static const _statusLabel = {
    'pending': 'Pendiente',
    'confirmed': 'Confirmada',
    'cancelled': 'Cancelada',
    'completed': 'Completada',
  };

  static const _statusColor = {
    'pending': Color(0xFFFF9800),
    'confirmed': Color(0xFF1565C0),
    'cancelled': AppColors.red,
    'completed': Color(0xFF2E7D32),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) {
        setState(() { _bookings = []; _loading = false; });
        return;
      }
      final data = await _sb
          .from('pet_service_bookings')
          .select('*, pet_services(name, category)')
          .eq('user_id', uid)
          .order('scheduled_at', ascending: false);
      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[MisReservas] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Mis Reservas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Sin reservas aún',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Reserva un servicio para tu mascota 🐾',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.push('/servicios-domicilio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Ver servicios'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (_, i) {
                      final b = _bookings[i];
                      final service =
                          b['pet_services'] as Map<String, dynamic>?;
                      final nombre =
                          service?['name'] as String? ?? 'Servicio';
                      final categoria =
                          service?['category'] as String? ?? '';
                      final mascota = b['pet_name'] as String? ?? '';
                      final rawDate = b['scheduled_at'] as String? ?? '';
                      final fecha = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
                      final status = b['status'] as String? ?? 'pending';
                      final label = _statusLabel[status] ?? status;
                      final color =
                          _statusColor[status] ?? Colors.grey;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  if (categoria.isNotEmpty)
                                    Text(categoria,
                                        style: TextStyle(
                                            color: AppColors.purple,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  Text('Mascota: $mascota',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12)),
                                  Text('Fecha: $fecha',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: color.withOpacity(0.4)),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
