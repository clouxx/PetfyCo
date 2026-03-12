import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─── Tipos de registro ───────────────────────────────────────────────────────

const _tipos = [
  'Consulta',
  'Vacuna',
  'Cirugía',
  'Examen',
  'Desparasitación',
  'Baño / Estética',
  'Otro',
];

const _tipoConfig = {
  'Consulta':         {'icon': Icons.local_hospital_outlined, 'color': Color(0xFF4CB5F9)},
  'Vacuna':           {'icon': Icons.vaccines_outlined,        'color': Color(0xFF4CAF50)},
  'Cirugía':          {'icon': Icons.medical_services_outlined,'color': Color(0xFFF44336)},
  'Examen':           {'icon': Icons.biotech_outlined,         'color': Color(0xFF9C27B0)},
  'Desparasitación':  {'icon': Icons.pest_control_outlined,    'color': Color(0xFFFF9800)},
  'Baño / Estética':  {'icon': Icons.bathtub_outlined,         'color': Color(0xFF00BCD4)},
  'Otro':             {'icon': Icons.note_alt_outlined,        'color': Color(0xFF757575)},
};

// ─── Page ────────────────────────────────────────────────────────────────────

class HistorialMedicoPage extends StatefulWidget {
  const HistorialMedicoPage({super.key});

  @override
  State<HistorialMedicoPage> createState() => _HistorialMedicoPageState();
}

class _HistorialMedicoPageState extends State<HistorialMedicoPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _filterPet;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      final data = await _sb
          .from('medical_records')
          .select()
          .eq('user_id', uid)
          .order('fecha', ascending: false);
      if (mounted) setState(() => _records = List<Map<String, dynamic>>.from(data));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSheet([Map<String, dynamic>? record]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _MedicalRecordSheet(record: record, onSaved: _load),
    );
  }

  void _openDetail(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RecordDetailSheet(
        record: record,
        onEdit: () { Navigator.pop(context); _openSheet(record); },
        onDelete: () { Navigator.pop(context); _delete(record['id']); },
      ),
    );
  }

  Future<void> _delete(String id) async {
    await _sb.from('medical_records').delete().eq('id', id);
    await _load();
  }

  List<String> get _pets => _records.map((r) => r['pet_nombre'] as String).toSet().toList()..sort();

  List<Map<String, dynamic>> get _filtered =>
      _filterPet == null ? _records : _records.where((r) => r['pet_nombre'] == _filterPet).toList();

  // Group by pet_nombre
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in _filtered) {
      final pet = r['pet_nombre'] as String;
      map.putIfAbsent(pet, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Historial Médico', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        iconTheme: const IconThemeData(color: AppColors.navy),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              onPressed: _showStats,
              icon: const Icon(Icons.bar_chart_outlined, color: AppColors.purple),
              tooltip: 'Resumen',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo registro', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    if (_pets.length > 1) _buildPetFilter(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.purple,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          children: _grouped.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pet header
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.pets, size: 16, color: AppColors.purple),
                                      const SizedBox(width: 6),
                                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text('${entry.value.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.purple)),
                                      ),
                                    ],
                                  ),
                                ),
                                ...entry.value.map((r) => _RecordCard(
                                  record: r,
                                  onTap: () => _openDetail(r),
                                )),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPetFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Todas', null),
            ..._pets.map((p) => _filterChip(p, p)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _filterPet == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterPet = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.purple : AppColors.greyBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.greyText)),
        ),
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
              child: const Icon(Icons.history_edu, size: 50, color: AppColors.purple),
            ),
            const SizedBox(height: 20),
            const Text('Sin registros médicos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Lleva el control de vacunas, consultas y tratamientos de tus mascotas.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar primer registro', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple, foregroundColor: Colors.white,
                minimumSize: const Size(220, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStats() {
    final total = _records.length;
    final byType = <String, int>{};
    double totalCost = 0;
    for (final r in _records) {
      byType[r['tipo'] as String] = (byType[r['tipo'] as String] ?? 0) + 1;
      if (r['costo'] != null) totalCost += (r['costo'] as num).toDouble();
    }
    final sorted = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Resumen de salud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
            const SizedBox(height: 20),
            Row(
              children: [
                _statBox('$total', 'Registros', Icons.assignment_outlined),
                const SizedBox(width: 12),
                _statBox(_pets.length.toString(), 'Mascotas', Icons.pets),
                const SizedBox(width: 12),
                if (totalCost > 0)
                  _statBox('\$${totalCost.toStringAsFixed(0)}', 'Total gastado', Icons.attach_money),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Por tipo de visita', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy)),
            const SizedBox(height: 10),
            ...sorted.map((e) {
              final cfg = _tipoConfig[e.key];
              final color = (cfg?['color'] as Color?) ?? AppColors.greyText;
              final pct = e.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.navy))),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
                    )),
                    const SizedBox(width: 8),
                    Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.07), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.purple, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Record Card ─────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});
  final Map<String, dynamic> record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tipo = record['tipo'] as String? ?? 'Otro';
    final cfg = _tipoConfig[tipo] ?? _tipoConfig['Otro']!;
    final color = cfg['color'] as Color;
    final icon = cfg['icon'] as IconData;
    final fecha = _fmtDate(record['fecha']);
    final vet = record['veterinario'] as String?;
    final clinica = record['clinica'] as String?;
    final diag = record['diagnostico'] as String?;
    final costo = record['costo'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(tipo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                        ),
                        const Spacer(),
                        Text(fecha, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    if (diag != null && diag.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(diag, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (vet != null || clinica != null) ...[
                      const SizedBox(height: 2),
                      Text([if (vet != null) 'Dr. $vet', if (clinica != null) clinica].join(' · '),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    if (costo != null) ...[
                      const SizedBox(height: 4),
                      Text('\$${(costo as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.greyText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return d.toString(); }
  }
}

// ─── Detail Sheet ─────────────────────────────────────────────────────────────

class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({required this.record, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> record;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final tipo = record['tipo'] as String? ?? 'Otro';
    final cfg = _tipoConfig[tipo] ?? _tipoConfig['Otro']!;
    final color = cfg['color'] as Color;
    final icon = cfg['icon'] as IconData;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color)),
                  Text(_fmtDate(record['fecha']), style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.purple), onPressed: onEdit),
              IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400), onPressed: onDelete),
            ],
          ),
          const SizedBox(height: 20),

          // Pet
          _row(Icons.pets, 'Mascota', record['pet_nombre']),
          if ((record['veterinario'] ?? '').toString().isNotEmpty)
            _row(Icons.person_outline, 'Veterinario', 'Dr. ${record['veterinario']}'),
          if ((record['clinica'] ?? '').toString().isNotEmpty)
            _row(Icons.local_hospital_outlined, 'Clínica', record['clinica']),
          if ((record['diagnostico'] ?? '').toString().isNotEmpty)
            _row(Icons.assignment_outlined, 'Diagnóstico', record['diagnostico']),
          if ((record['tratamiento'] ?? '').toString().isNotEmpty)
            _row(Icons.medication_outlined, 'Tratamiento', record['tratamiento']),
          if (record['costo'] != null)
            _row(Icons.attach_money, 'Costo', '\$${(record['costo'] as num).toStringAsFixed(0)}'),
          if ((record['notas'] ?? '').toString().isNotEmpty)
            _row(Icons.notes_outlined, 'Notas', record['notas']),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.purple),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              SizedBox(
                width: 260,
                child: Text(value.toString(), style: const TextStyle(fontSize: 14, color: AppColors.navy, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return d.toString(); }
  }
}

// ─── Create / Edit Sheet ─────────────────────────────────────────────────────

class _MedicalRecordSheet extends StatefulWidget {
  const _MedicalRecordSheet({this.record, required this.onSaved});
  final Map<String, dynamic>? record;
  final VoidCallback onSaved;

  @override
  State<_MedicalRecordSheet> createState() => _MedicalRecordSheetState();
}

class _MedicalRecordSheetState extends State<_MedicalRecordSheet> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  late final _pet = TextEditingController();
  late final _vet = TextEditingController();
  late final _clinica = TextEditingController();
  late final _diag = TextEditingController();
  late final _trat = TextEditingController();
  late final _costo = TextEditingController();
  late final _notas = TextEditingController();

  String _tipo = 'Consulta';
  DateTime _fecha = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _pet.text = r['pet_nombre'] ?? '';
      _vet.text = r['veterinario'] ?? '';
      _clinica.text = r['clinica'] ?? '';
      _diag.text = r['diagnostico'] ?? '';
      _trat.text = r['tratamiento'] ?? '';
      _notas.text = r['notas'] ?? '';
      if (r['costo'] != null) _costo.text = (r['costo'] as num).toStringAsFixed(0);
      _tipo = r['tipo'] ?? 'Consulta';
      if (r['fecha'] != null) _fecha = DateTime.parse(r['fecha']);
    }
  }

  @override
  void dispose() {
    _pet.dispose(); _vet.dispose(); _clinica.dispose();
    _diag.dispose(); _trat.dispose(); _costo.dispose(); _notas.dispose();
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
        'tipo': _tipo,
        'fecha': _fecha.toIso8601String().split('T')[0],
        'veterinario': _vet.text.trim().isEmpty ? null : _vet.text.trim(),
        'clinica': _clinica.text.trim().isEmpty ? null : _clinica.text.trim(),
        'diagnostico': _diag.text.trim().isEmpty ? null : _diag.text.trim(),
        'tratamiento': _trat.text.trim().isEmpty ? null : _trat.text.trim(),
        'costo': _costo.text.trim().isEmpty ? null : double.tryParse(_costo.text.trim()),
        'notas': _notas.text.trim().isEmpty ? null : _notas.text.trim(),
      };
      if (widget.record != null) {
        await _sb.from('medical_records').update(payload).eq('id', widget.record!['id']);
      } else {
        await _sb.from('medical_records').insert(payload);
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.record != null;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              child: Column(children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 14),
                Row(children: [
                  Text(isEdit ? 'Editar registro' : 'Nuevo registro',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), color: AppColors.greyText),
                ]),
              ]),
            ),
            const Divider(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo selector (chips)
                      _label('Tipo de visita'),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _tipos.map((t) {
                            final sel = _tipo == t;
                            final cfg = _tipoConfig[t]!;
                            final color = cfg['color'] as Color;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _tipo = t),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel ? color : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sel ? color : Colors.grey.shade300),
                                  ),
                                  child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey.shade600)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date
                      _label('Fecha'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined, color: AppColors.purple, size: 18),
                            const SizedBox(width: 10),
                            Text('${_fecha.day}/${_fecha.month}/${_fecha.year}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: AppColors.greyText, size: 18),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _label('Mascota *'),
                      _field(_pet, 'Nombre de la mascota', Icons.pets_outlined, required: true),
                      const SizedBox(height: 16),

                      _label('Veterinario'),
                      _field(_vet, 'Nombre del veterinario', Icons.person_outline),
                      const SizedBox(height: 16),

                      _label('Clínica / Consultorio'),
                      _field(_clinica, 'Nombre del lugar', Icons.local_hospital_outlined),
                      const SizedBox(height: 16),

                      _label('Diagnóstico'),
                      _field(_diag, 'Ej: Gastroenteritis leve', Icons.assignment_outlined),
                      const SizedBox(height: 16),

                      _label('Tratamiento'),
                      _field(_trat, 'Ej: Antibióticos por 5 días', Icons.medication_outlined),
                      const SizedBox(height: 16),

                      _label('Costo (opcional)'),
                      TextFormField(
                        controller: _costo,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDec('Ej: 85000', Icons.attach_money_outlined),
                      ),
                      const SizedBox(height: 16),

                      _label('Notas adicionales'),
                      TextFormField(
                        controller: _notas,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Observaciones, próxima cita…',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          filled: true, fillColor: Colors.white,
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
                    backgroundColor: AppColors.purple, foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(isEdit ? 'Guardar cambios' : 'Guardar registro',
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

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
      decoration: _inputDec(hint, icon),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.purple)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fecha = picked);
  }
}
