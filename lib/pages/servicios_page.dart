import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// Solo estos emails pueden registrar empresas
const _adminEmails = ['fredy.alandete@gmail.com', 'f.alandete@uniandes.edu.co'];

const _categorias = [
  {'label': 'Todos', 'emoji': '🐾'},
  {'label': 'Veterinaria', 'emoji': '🏥'},
  {'label': 'Peluquería', 'emoji': '✂️'},
  {'label': 'Guardería', 'emoji': '🏠'},
  {'label': 'Transporte', 'emoji': '🚗'},
  {'label': 'Adiestramiento', 'emoji': '🎓'},
  {'label': 'Tienda', 'emoji': '🛒'},
];

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key});

  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _providers = [];
  bool _loading = true;
  String _catFilter = 'Todos';

  bool get _isAdmin {
    final email = _sb.auth.currentUser?.email ?? '';
    return _adminEmails.contains(email);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = _sb.from('service_providers').select('''
        id, nombre, categoria, descripcion, ciudad, depto,
        whatsapp, email, website, logo_url, verificado,
        provider_services(id, nombre, descripcion, precio_desde, precio_hasta)
      ''').order('verificado', ascending: false).order('created_at', ascending: false);

      final data = await q;
      List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(data);

      if (_catFilter != 'Todos') {
        list = list.where((p) => p['categoria'] == _catFilter).toList();
      }

      setState(() {
        _providers = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Servicios', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add_business_outlined, color: AppColors.purple),
              tooltip: 'Registrar empresa',
              onPressed: () => _showRegisterSheet(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Categorías
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categorias.map((c) {
                  final label = c['label']!;
                  final emoji = c['emoji']!;
                  final sel = _catFilter == label;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _catFilter = label);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.purple : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.purple : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '$emoji $label',
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Lista
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _providers.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _providers.length,
                          itemBuilder: (_, i) => _ProviderCard(
                            provider: _providers[i],
                            onTap: () => _showDetail(_providers[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _catFilter == 'Todos'
                ? 'Aún no hay empresas aliadas'
                : 'No hay empresas en "$_catFilter"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Tienes un negocio?\n¡Regístralo y llega a más clientes!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          if (_isAdmin)
          ElevatedButton.icon(
            onPressed: _showRegisterSheet,
            icon: const Icon(Icons.add_business),
            label: const Text('Registrar empresa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProviderDetail(provider: provider),
    );
  }

  void _showRegisterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegisterSheet(
        sb: _sb,
        onSaved: _load,
      ),
    );
  }
}

// ─────────── Card de proveedor ────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider, required this.onTap});
  final Map<String, dynamic> provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nombre = provider['nombre'] as String? ?? '';
    final categoria = provider['categoria'] as String? ?? '';
    final descripcion = provider['descripcion'] as String? ?? '';
    final ciudad = provider['ciudad'] as String? ?? '';
    final logoUrl = provider['logo_url'] as String?;
    final verificado = provider['verificado'] == true;
    final services = provider['provider_services'] as List? ?? [];

    final catData = _categorias.firstWhere(
      (c) => c['label'] == categoria,
      orElse: () => {'label': categoria, 'emoji': '🐾'},
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl != null
                    ? Image.network(logoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoPlaceholder(catData['emoji']!))
                    : _logoPlaceholder(catData['emoji']!),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (verificado)
                          const Icon(Icons.verified, color: AppColors.blue, size: 18),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${catData['emoji']} $categoria',
                        style: const TextStyle(
                            color: AppColors.purple, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                    if (ciudad.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Text(ciudad,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ],
                    if (services.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${services.length} servicio${services.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder(String emoji) => Center(
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      );
}

// ─────────── Detalle del proveedor ───────────────────────────────────────────

class _ProviderDetail extends StatelessWidget {
  const _ProviderDetail({required this.provider});
  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final nombre = provider['nombre'] as String? ?? '';
    final categoria = provider['categoria'] as String? ?? '';
    final descripcion = provider['descripcion'] as String? ?? '';
    final ciudad = provider['ciudad'] as String? ?? '';
    final depto = provider['depto'] as String? ?? '';
    final whatsapp = provider['whatsapp'] as String? ?? '';
    final email = provider['email'] as String? ?? '';
    final website = provider['website'] as String? ?? '';
    final logoUrl = provider['logo_url'] as String?;
    final verificado = provider['verificado'] == true;
    final services = (provider['provider_services'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final catData = _categorias.firstWhere(
      (c) => c['label'] == categoria,
      orElse: () => {'label': categoria, 'emoji': '🐾'},
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl != null
                        ? Image.network(logoUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Center(child: Text(catData['emoji']!, style: const TextStyle(fontSize: 32))))
                        : Center(child: Text(catData['emoji']!, style: const TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nombre,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                            if (verificado)
                              const Icon(Icons.verified, color: AppColors.blue, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${catData['emoji']} $categoria',
                              style: const TextStyle(
                                  color: AppColors.purple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (ciudad.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 2),
                              Text('$ciudad${depto.isNotEmpty ? ', $depto' : ''}',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              if (descripcion.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Acerca de',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 6),
                Text(descripcion, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
              ],

              // Servicios
              if (services.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Servicios',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 10),
                ...services.map((s) => _ServiceItem(service: s)),
              ],

              // Contacto
              const SizedBox(height: 20),
              Text('Contacto',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 10),

              if (whatsapp.isNotEmpty)
                _ContactButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    final uri = Uri.parse(
                        'https://wa.me/$whatsapp?text=${Uri.encodeComponent('Hola, los encontré en PetfyCo y quisiera información sobre sus servicios.')}');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              if (email.isNotEmpty)
                _ContactButton(
                  icon: Icons.email_outlined,
                  label: email,
                  color: AppColors.blue,
                  onTap: () async {
                    final uri = Uri.parse('mailto:$email');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                ),
              if (website.isNotEmpty)
                _ContactButton(
                  icon: Icons.language_outlined,
                  label: website,
                  color: AppColors.purple,
                  onTap: () async {
                    final url = website.startsWith('http') ? website : 'https://$website';
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({required this.service});
  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    final nombre = service['nombre'] as String? ?? '';
    final desc = service['descripcion'] as String? ?? '';
    final desde = service['precio_desde'];
    final hasta = service['precio_hasta'];

    String precio = '';
    if (desde != null) {
      precio = 'Desde \$${desde.toStringAsFixed(0)}';
      if (hasta != null) precio += ' - \$${hasta.toStringAsFixed(0)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.purple, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          if (precio.isNotEmpty)
            Text(precio,
                style: const TextStyle(
                    color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton(
      {required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────── Sheet Registrar empresa ─────────────────────────────────────────

class _RegisterSheet extends StatefulWidget {
  const _RegisterSheet({required this.sb, required this.onSaved});
  final SupabaseClient sb;
  final VoidCallback onSaved;

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _deptoCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _webCtrl = TextEditingController();
  String _categoria = 'Veterinaria';
  bool _saving = false;

  @override
  void dispose() {
    _nombreCtrl.dispose(); _descCtrl.dispose(); _ciudadCtrl.dispose();
    _deptoCtrl.dispose(); _waCtrl.dispose(); _emailCtrl.dispose(); _webCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final me = widget.sb.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _saving = true);
    try {
      await widget.sb.from('service_providers').insert({
        'user_id': me,
        'nombre': _nombreCtrl.text.trim(),
        'categoria': _categoria,
        'descripcion': _descCtrl.text.trim(),
        'ciudad': _ciudadCtrl.text.trim(),
        'depto': _deptoCtrl.text.trim(),
        'whatsapp': _waCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _webCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Empresa registrada! Pronto será verificada.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text('Registrar mi empresa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),

              _field('Nombre del negocio *', _nombreCtrl, 'Ej: Veterinaria Patitas'),
              const SizedBox(height: 12),

              // Categoría
              const Text('Categoría *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: _inputDeco('Selecciona una categoría'),
                items: _categorias
                    .where((c) => c['label'] != 'Todos')
                    .map((c) => DropdownMenuItem(
                          value: c['label'],
                          child: Text('${c['emoji']} ${c['label']}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 12),

              _field('Descripción', _descCtrl, 'Cuéntanos sobre tu empresa...', maxLines: 3, required: false),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _field('Ciudad', _ciudadCtrl, 'Bogotá', required: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Departamento', _deptoCtrl, 'Cundinamarca', required: false)),
                ],
              ),
              const SizedBox(height: 12),

              _field('WhatsApp', _waCtrl, '573001234567', keyboardType: TextInputType.phone, required: false),
              const SizedBox(height: 12),
              _field('Correo electrónico', _emailCtrl, 'contacto@empresa.com',
                  keyboardType: TextInputType.emailAddress, required: false),
              const SizedBox(height: 12),
              _field('Sitio web', _webCtrl, 'www.miempresa.com', required: false),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Registrar empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {TextInputType? keyboardType, int maxLines = 1, bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Requerido' : null : null,
          decoration: _inputDeco(hint),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      );
}
