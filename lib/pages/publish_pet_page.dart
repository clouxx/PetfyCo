import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  final String? presetEstado;
  final String? editPetId;

  const PublishPetPage({
    super.key,
    this.presetEstado,
    this.editPetId,
  });

  @override
  State<PublishPetPage> createState() => _PublishPetPageState();
}

class _PublishPetPageState extends State<PublishPetPage> {
  final _sb = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String _especie = 'perro';
  String _sexo = 'macho';
  String _estado = 'publicado'; // publicado | perdido | adoptado
  String? _talla;
  String? _temperamento;
  int? _edadAnios;

  bool _loading = false;
  String? _editingPetId;

  final List<XFile> _pickedImages = [];
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.presetEstado != null && widget.presetEstado!.isNotEmpty) {
      _estado = widget.presetEstado!;
    }
    if (widget.editPetId != null && widget.editPetId!.isNotEmpty) {
      _editingPetId = widget.editPetId!;
      _loadPetForEdit(_editingPetId!);
    }
  }

  Future<void> _loadPetForEdit(String id) async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('pets')
          .select('''
            id, nombre, especie, sexo, estado, raza, edad_meses, talla, temperamento, descripcion,
            municipio, depto,
            pet_photos(url, position)
          ''')
          .eq('id', id)
          .single(); // ← forzamos exactamente 1 fila

      _nombreCtrl.text      = (data['nombre'] ?? '') as String;
      _razaCtrl.text        = (data['raza'] ?? '') as String;
      _descripcionCtrl.text = (data['descripcion'] ?? '') as String;

      _especie      = (data['especie'] ?? 'perro') as String;
      _sexo         = (data['sexo'] ?? 'macho') as String;
      _estado       = (data['estado'] ?? 'publicado') as String;
      _talla        = data['talla'] as String?;
      _temperamento = data['temperamento'] as String?;

      final edadMeses = data['edad_meses'] as int?;
      _edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error cargando mascota: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files != null && files.isNotEmpty) {
      setState(() => _pickedImages.addAll(files));
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentUser!.id;

      final Map<String, dynamic> payload = {
        'owner_id': userId,
        'especie': _especie,
        'nombre': _nombreCtrl.text.trim(),
        'sexo': _sexo,
        'estado': _estado, // sin "reservado"
        'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
        'edad_meses': _edadAnios == null ? null : _edadAnios! * 12,
        'talla': _talla,
        'temperamento': _temperamento,
        'descripcion': _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
      };

      String petId;

      if (_editingPetId == null) {
        // INSERT
        final inserted =
            await _sb.from('pets').insert(payload).select('id').single();
        petId = inserted['id'] as String;
      } else {
        // UPDATE
        final id = _editingPetId!;
        await _sb.from('pets').update(payload).eq('id', id);
        petId = id;
      }

      // Subir imágenes nuevas
      if (_pickedImages.isNotEmpty) {
        int pos = 0;
        for (final x in _pickedImages) {
          final path =
              '$userId/${DateTime.now().millisecondsSinceEpoch}_${pos}.jpg';
          final bytes = await x.readAsBytes();
          await _sb.storage.from('pet-images').uploadBinary(
                path,
                bytes,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: false),
              );
          final publicUrl = _sb.storage.from('pet-images').getPublicUrl(path);
          await _sb.from('pet_photos').insert({
            'pet_id': petId,
            'url': publicUrl,
            'position': pos,
          });
          pos++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _editingPetId == null ? '¡Mascota publicada!' : 'Mascota actualizada')));
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_editingPetId == null ? 'Publicar mascota' : 'Editar mascota'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Encabezado
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(colors: [
                            AppColors.blue.withOpacity(0.15),
                            AppColors.orange.withOpacity(0.12),
                          ]),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pets, color: AppColors.navy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cuéntanos sobre tu mascota 🐾',
                                style: theme.textTheme.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Campos
                      _filledText(
                        controller: _nombreCtrl,
                        label: 'Nombre',
                        icon: Icons.pets,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      _dropdown<String>(
                        label: 'Especie',
                        icon: Icons.category_outlined,
                        value: _especie,
                        items: const [
                          DropdownMenuItem(value: 'perro', child: Text('Perro')),
                          DropdownMenuItem(value: 'gato', child: Text('Gato')),
                        ],
                        onChanged: (v) => setState(() => _especie = v!),
                      ),
                      const SizedBox(height: 12),

                      _dropdown<String>(
                        label: 'Sexo',
                        icon: Icons.people_alt_outlined,
                        value: _sexo,
                        items: const [
                          DropdownMenuItem(value: 'macho', child: Text('Macho')),
                          DropdownMenuItem(value: 'hembra', child: Text('Hembra')),
                        ],
                        onChanged: (v) => setState(() => _sexo = v!),
                      ),
                      const SizedBox(height: 12),

                      _dropdown<String>(
                        label: 'Estado',
                        icon: Icons.flag_outlined,
                        value: _estado,
                        items: const [
                          DropdownMenuItem(value: 'publicado', child: Text('Publicado')),
                          DropdownMenuItem(value: 'perdido', child: Text('Perdido')),
                          DropdownMenuItem(value: 'adoptado', child: Text('Adoptado')),
                        ],
                        onChanged: (v) => setState(() => _estado = v!),
                      ),
                      const SizedBox(height: 12),

                      _filledText(
                        controller: _razaCtrl,
                        label: 'Raza (opcional)',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),

                      _dropdown<int>(
                        label: 'Edad (años)',
                        icon: Icons.cake_outlined,
                        value: _edadAnios,
                        items: List.generate(
                          21,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (v) => setState(() => _edadAnios = v),
                      ),
                      const SizedBox(height: 12),

                      _dropdown<String>(
                        label: 'Talla',
                        icon: Icons.straighten,
                        value: _talla,
                        items: const [
                          DropdownMenuItem(value: 'pequeño', child: Text('Pequeño')),
                          DropdownMenuItem(value: 'mediano', child: Text('Mediano')),
                          DropdownMenuItem(value: 'grande', child: Text('Grande')),
                        ],
                        onChanged: (v) => setState(() => _talla = v),
                      ),
                      const SizedBox(height: 12),

                      _dropdown<String>(
                        label: 'Temperamento',
                        icon: Icons.mood_outlined,
                        value: _temperamento,
                        items: const [
                          DropdownMenuItem(value: 'juguetón', child: Text('Juguetón')),
                          DropdownMenuItem(value: 'tranquilo', child: Text('Tranquilo')),
                          DropdownMenuItem(value: 'activo', child: Text('Activo')),
                        ],
                        onChanged: (v) => setState(() => _temperamento = v),
                      ),
                      const SizedBox(height: 12),

                      _filledText(
                        controller: _descripcionCtrl,
                        label: 'Descripción',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Fotos nuevas
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Añadir fotos'),
                          ),
                          const SizedBox(width: 12),
                          if (_pickedImages.isNotEmpty)
                            Text('${_pickedImages.length} seleccionadas'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _onSubmit,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                              _editingPetId == null ? 'Publicar' : 'Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- Helpers UI ---
  Widget _filledText({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.blueGrey.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    T? value,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.blueGrey.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
