import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─── Notification helper ────────────────────────────────────────────────────

final _notif = FlutterLocalNotificationsPlugin();

Future<void> initRecetasNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
}

Future<void> _scheduleDaily(int id, String title, String body, TimeOfDay time) async {
  // Android channel
  const androidDetails = AndroidNotificationDetails(
    'recetas_channel', 'Recordatorios de Recetas',
    channelDescription: 'Recordatorio diario de medicamentos',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  // Show immediately + schedule daily repeat
  await _notif.periodicallyShow(
    id,
    title,
    body,
    RepeatInterval.daily,
    details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> _cancelNotif(int id) => _notif.cancel(id);

// ─── Page ───────────────────────────────────────────────────────────────────

class RecetasPage extends StatefulWidget {
  const RecetasPage({super.key});

  @override
  State<RecetasPage> createState() => _RecetasPageState();
}

class _RecetasPageState extends State<RecetasPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      final data = await _sb
          .from('prescriptions')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _prescriptions = List<Map<String, dynamic>>.from(data));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final notifId = id.hashCode.abs() % 100000;
    await _cancelNotif(notifId);
    await _sb.from('prescriptions').delete().eq('id', id);
    await _load();
  }

  Future<void> _toggle(String id, bool current) async {
    final notifId = id.hashCode.abs() % 100000;
    await _sb.from('prescriptions').update({'activa': !current}).eq('id', id);
    if (current) await _cancelNotif(notifId);
    await _load();
  }

  void _openSheet([Map<String, dynamic>? prescription]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RecetaSheet(
        prescription: prescription,
        onSaved: _load,
      ),
    );
  }

  List<Map<String, dynamic>> get _activas => _prescriptions.where((p) => p['activa'] == true).toList();
  List<Map<String, dynamic>> get _historial => _prescriptions.where((p) => p['activa'] == false).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Recetas', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva receta', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  children: [
                    if (_activas.isNotEmpty) ...[
                      _sectionHeader('Activas', _activas.length, AppColors.purple),
                      const SizedBox(height: 12),
                      ..._activas.map((p) => _RecetaCard(
                            prescription: p,
                            onEdit: () => _openSheet(p),
                            onDelete: () => _confirmDelete(p['id']),
                            onToggle: () => _toggle(p['id'], true),
                          )),
                    ],
                    if (_historial.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionHeader('Historial', _historial.length, AppColors.greyText),
                      const SizedBox(height: 12),
                      ..._historial.map((p) => _RecetaCard(
                            prescription: p,
                            onEdit: () => _openSheet(p),
                            onDelete: () => _confirmDelete(p['id']),
                            onToggle: () => _toggle(p['id'], false),
                          )),
                    ],
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.medical_services_outlined, size: 48, color: AppColors.purple),
            ),
            const SizedBox(height: 20),
            const Text('Sin recetas aún', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Agrega los medicamentos de tus mascotas y recibe recordatorios diarios.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva receta', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ),
      ],
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar receta'),
        content: const Text('¿Estás seguro? También se cancelará el recordatorio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () { Navigator.pop(context); _delete(id); },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Card ───────────────────────────────────────────────────────────────────

class _RecetaCard extends StatelessWidget {
  const _RecetaCard({
    required this.prescription,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Map<String, dynamic> prescription;
  final VoidCallback onEdit, onDelete, onToggle;

  @override
  Widget build(BuildContext context) {
    final p = prescription;
    final activa = p['activa'] == true;
    final color = activa ? AppColors.purple : AppColors.greyText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activa ? AppColors.purple.withOpacity(0.2) : Colors.grey.shade200),
        boxShadow: activa ? [BoxShadow(color: AppColors.purple.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.medical_services_outlined, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['medicamento'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                      Text(p['pet_nombre'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Active toggle
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: activa ? AppColors.purple.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(activa ? 'Activa' : 'Inactiva',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activa ? AppColors.purple : Colors.grey)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Info chips
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _chip(Icons.vaccines_outlined, p['dosis'] ?? '', color),
                _chip(Icons.schedule, p['frecuencia'] ?? '', color),
                if (p['hora_recordatorio'] != null && p['recordatorio'] == true)
                  _chip(Icons.notifications_outlined, p['hora_recordatorio'], color),
              ],
            ),

            // Date range
            if (p['fecha_inicio'] != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(_formatDate(p['fecha_inicio']), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  if (p['fecha_fin'] != null) ...[
                    Text(' → ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    Text(_formatDate(p['fecha_fin']), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ],

            // Notes
            if ((p['notas'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p['notas'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            // Actions
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.purple),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return d.toString(); }
  }
}

// ─── Bottom Sheet Form ───────────────────────────────────────────────────────

class _RecetaSheet extends StatefulWidget {
  const _RecetaSheet({this.prescription, required this.onSaved});
  final Map<String, dynamic>? prescription;
  final VoidCallback onSaved;

  @override
  State<_RecetaSheet> createState() => _RecetaSheetState();
}

class _RecetaSheetState extends State<_RecetaSheet> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  late final TextEditingController _pet = TextEditingController();
  late final TextEditingController _med = TextEditingController();
  late final TextEditingController _dosis = TextEditingController();
  late final TextEditingController _notas = TextEditingController();

  String _frecuencia = 'Cada 8 horas';
  DateTime _fechaInicio = DateTime.now();
  DateTime? _fechaFin;
  TimeOfDay _hora = const TimeOfDay(hour: 8, minute: 0);
  bool _recordatorio = true;
  bool _saving = false;

  static const _frecuencias = [
    'Cada 4 horas', 'Cada 6 horas', 'Cada 8 horas',
    'Cada 12 horas', 'Una vez al día', 'Dos veces al día',
    'Según necesidad',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.prescription;
    if (p != null) {
      _pet.text = p['pet_nombre'] ?? '';
      _med.text = p['medicamento'] ?? '';
      _dosis.text = p['dosis'] ?? '';
      _notas.text = p['notas'] ?? '';
      _frecuencia = p['frecuencia'] ?? _frecuencia;
      _recordatorio = p['recordatorio'] == true;
      if (p['fecha_inicio'] != null) _fechaInicio = DateTime.parse(p['fecha_inicio']);
      if (p['fecha_fin'] != null) _fechaFin = DateTime.parse(p['fecha_fin']);
      if (p['hora_recordatorio'] != null) {
        final parts = (p['hora_recordatorio'] as String).split(':');
        _hora = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    _pet.dispose(); _med.dispose(); _dosis.dispose(); _notas.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;

      final payload = {
        'user_id': uid,
        'pet_nombre': _pet.text.trim(),
        'medicamento': _med.text.trim(),
        'dosis': _dosis.text.trim(),
        'frecuencia': _frecuencia,
        'hora_recordatorio': _recordatorio ? '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}' : null,
        'recordatorio': _recordatorio,
        'fecha_inicio': _fechaInicio.toIso8601String().split('T')[0],
        'fecha_fin': _fechaFin?.toIso8601String().split('T')[0],
        'notas': _notas.text.trim().isEmpty ? null : _notas.text.trim(),
        'activa': true,
      };

      String prescriptionId;
      if (widget.prescription != null) {
        await _sb.from('prescriptions').update(payload).eq('id', widget.prescription!['id']);
        prescriptionId = widget.prescription!['id'];
      } else {
        final result = await _sb.from('prescriptions').insert(payload).select().single();
        prescriptionId = result['id'];
      }

      // Schedule/cancel notification
      final notifId = prescriptionId.hashCode.abs() % 100000;
      if (_recordatorio) {
        await _scheduleDaily(
          notifId,
          '💊 Hora del medicamento',
          '${_med.text.trim()} — ${_dosis.text.trim()} para ${_pet.text.trim()}',
          _hora,
        );
      } else {
        await _cancelNotif(notifId);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final isEdit = widget.prescription != null;

    return SizedBox(
      height: screenH * 0.92,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(isEdit ? 'Editar receta' : 'Nueva receta',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), color: AppColors.greyText),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Mascota'),
                      _field(_pet, 'Nombre de la mascota', Icons.pets_outlined),
                      const SizedBox(height: 16),

                      _label('Medicamento'),
                      _field(_med, 'Nombre del medicamento', Icons.medication_outlined),
                      const SizedBox(height: 16),

                      _label('Dosis'),
                      _field(_dosis, 'Ej: 5 mg, 1 tableta, 2 ml', Icons.vaccines_outlined),
                      const SizedBox(height: 16),

                      _label('Frecuencia'),
                      _dropdown(),
                      const SizedBox(height: 16),

                      // Dates row
                      Row(
                        children: [
                          Expanded(child: _dateTile('Inicio', _fechaInicio, (d) => setState(() => _fechaInicio = d))),
                          const SizedBox(width: 12),
                          Expanded(child: _dateTile('Fin (opc.)', _fechaFin, (d) => setState(() => _fechaFin = d), optional: true)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Recordatorio switch
                      Container(
                        decoration: BoxDecoration(
                          color: _recordatorio ? AppColors.purple.withOpacity(0.06) : AppColors.greyBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _recordatorio ? AppColors.purple.withOpacity(0.2) : Colors.transparent),
                        ),
                        child: SwitchListTile(
                          title: const Text('Recordatorio diario', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_recordatorio ? 'Recibirás una notificación cada día' : 'Sin recordatorio',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          value: _recordatorio,
                          activeColor: AppColors.purple,
                          onChanged: (v) => setState(() => _recordatorio = v),
                          secondary: Icon(Icons.notifications_outlined, color: _recordatorio ? AppColors.purple : AppColors.greyText),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),

                      if (_recordatorio) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: AppColors.purple, size: 20),
                                const SizedBox(width: 12),
                                const Text('Hora del recordatorio', style: TextStyle(fontSize: 14, color: AppColors.navy)),
                                const Spacer(),
                                Text(_hora.format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.purple, fontSize: 15)),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, color: AppColors.greyText, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _label('Notas (opcional)'),
                      TextFormField(
                        controller: _notas,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Instrucciones adicionales, observaciones…',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(isEdit ? 'Guardar cambios' : 'Guardar receta',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.navy)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return TextFormField(
      controller: ctrl,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _frecuencia,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.greyText),
          items: _frecuencias.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) { if (v != null) setState(() => _frecuencia = v); },
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, Function(DateTime) onPick, {bool optional = false}) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.purple)),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.purple),
                const SizedBox(width: 6),
                Text(
                  date != null ? '${date.day}/${date.month}/${date.year}' : (optional ? 'Sin fecha' : 'Seleccionar'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: date != null ? AppColors.navy : Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _hora,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.purple)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hora = picked);
  }
}
