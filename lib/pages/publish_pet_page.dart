import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  /// NUEVO: puedes pasar un estado por defecto desde la URL (?estado=perdido, etc.)
  final String? presetEstado;

  /// NUEVO: si vienes en modo edición, pasa el id de la mascota (?edit=<uuid>)
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

  // Form controllers / estado
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String _especie = 'perro'; // perro | gato
  String _sexo = 'macho';    // macho | hembra
  String _estado = 'publicado'; // publicado | adoptado | reservado | perdido
  String? _talla; // pequeño | mediano | grande
  String? _temperamento;
  int? _edadAnios;

  // edición
  bool _loading = false;
  String? _editingPetId;

  // imágenes locales seleccionadas
  final List<XFile> _pickedImages = [];
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Si viene ?estado=... lo usamos como valor inicial
    if (widget.presetEstado != null && widget.presetEstado!.isNotEmpty) {
      _estado = widget.presetEstado!;
    }

    // Si viene ?edit=<uuid> cargamos datos para edición
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
          .maybeSingle();

      if (data != null) {
        _nombreCtrl.text = data['nombre'] ?? '';
        _razaCtrl.text = data['raza'] ?? '';
        _descripcionCtrl.text = data['descripcion'] ?? '';
        _especie = (data['especie'] ?? 'perro') as String;
        _sexo = (data['sexo'] ?? 'macho') as String;
        _estado = (data['estado'] ?? 'publicado') as String;
        _talla = data['talla'] as String?;
        _temperamento = data['temperamento'] as String?;
        final edadMeses = data['edad_meses'] as int?;
        _edadAnios = edadMeses == null ? null : (edadMeses ~/ 12);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando mascota: $e')),
      );
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
        'estado': _estado,
        'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
        'edad_meses': _edadAnios == null ? null : _edadAnios! * 12,
        'talla': _talla,
        'temperamento': _temperamento,
        'descripcion':
            _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
      };

      String petId;

      // ====== FIX DE NULL-SAFETY AQUÍ ======
      final editingId = _editingPetId; // copia local para promoción de tipo
      if (editingId == null) {
        // INSERT
        final inserted =
            await _sb.from('pets').insert(payload).select('id').single();
        petId = inserted['id'] as String;
      } else {
        // UPDATE
        await _sb.from('pets').update(payload).eq('id', editingId);
        petId = editingId;
      }
      // ====== FIN DEL FIX ======

      // Subir imágenes nuevas (si se eligieron)
      if (_pickedImages.isNotEmpty) {
        // bucket recomendado: pet-images; carpeta por userId
        int pos = 0;
        for (final x in _pickedImages) {
          final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_${pos}.jpg';
          await _sb.storage.from('pet-images').upload(path, File(x.path));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingId == null ? 'Mascota publicada' : 'Mascota actualizada'),
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // especie
                      _Dropdown<String>(
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

                      // sexo
                      _Dropdown<String>(
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

                      // estado
                      _Dropdown<String>(
                        label: 'Estado',
                        icon: Icons.flag_outlined,
                        value: _estado,
                        items: const [
                          DropdownMenuItem(value: 'publicado', child: Text('Publicado')),
                          DropdownMenuItem(value: 'perdido', child: Text('Perdido')),
                          DropdownMenuItem(value: 'reservado', child: Text('Reservado')),
                          DropdownMenuItem(value: 'adoptado', child: Text('Adoptado')),
                        ],
                        onChanged: (v) => setState(() => _estado = v!),
                      ),
                      const SizedBox(height: 12),

                      // raza
                      TextFormField(
                        controller: _razaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Raza (opcional)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // edad
                      _Dropdown<int>(
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

                      // talla
                      _Dropdown<String>(
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

                      // temperamento
                      _Dropdown<String>(
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

                      // descripción
                      TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // imágenes
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
                          label: Text(_editingPetId == null ? 'Publicar' : 'Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
    super.key,
  });

  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
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
