import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  const PublishPetPage({
    super.key,
    this.presetEstado,
    this.editId,
  });

  /// Preselección de estado, útil para `/publish?estado=perdido`
  final String? presetEstado;

  /// Editar una mascota: `/publish?edit=<uuid>`
  final String? editId;

  @override
  State<PublishPetPage> createState() => _PublishPetPageState();
}

class _PublishPetPageState extends State<PublishPetPage> {
  final _sb = Supabase.instance.client;

  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _edadAnhosCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String _especie = 'perro'; // perro | gato
  String _sexo = 'macho'; // macho | hembra
  String _estado = 'publicado'; // publicado | adoptado | reservado | perdido | encontrado
  String _talla = 'pequeña'; // pequeña | mediano | grande
  String _temperamento = 'juguetón'; // etiqueta libre simple

  // Imagen local seleccionada
  Uint8List? _imageBytes;
  String? _imageName; // para el upload
  String? _existingPhotoUrl; // si estamos editando
  bool _loading = false;

  // Si estamos editando
  String? get _editId => widget.editId;

  @override
  void initState() {
    super.initState();

    // Lee query params también si vinimos por GoRouter sin props
    final qp = GoRouterState.of(context).uri.queryParameters;
    final qpEstado = qp['estado'];
    final qpEdit = qp['edit'];

    _estado = (widget.presetEstado ?? qpEstado ?? _estado).toLowerCase();

    if ((widget.editId ?? qpEdit) != null) {
      _loadForEdit((widget.editId ?? qpEdit)!);
    }
  }

  Future<void> _loadForEdit(String id) async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('pets')
          .select('''
            id, nombre, especie, sexo, estado, raza, edad_meses, talla, temperamento,
            descripcion, municipio,
            pet_photos(url, position)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (data != null) {
        _nameCtrl.text = (data['nombre'] as String?) ?? '';
        _especie = (data['especie'] as String?) ?? 'perro';
        _sexo = (data['sexo'] as String?) ?? 'macho';
        _estado = (data['estado'] as String?)?.toLowerCase() ?? 'publicado';
        _razaCtrl.text = (data['raza'] as String?) ?? '';
        final edadMeses = data['edad_meses'] as int?;
        if (edadMeses != null) {
          _edadAnhosCtrl.text = (edadMeses ~/ 12).toString();
        }
        _talla = (data['talla'] as String?)?.toLowerCase() ?? 'pequeña';
        _temperamento =
            (data['temperamento'] as String?)?.toLowerCase() ?? 'juguetón';
        _descripcionCtrl.text = (data['descripcion'] as String?) ?? '';

        // Foto principal existente
        final petPhotos = data['pet_photos'];
        if (petPhotos is List && petPhotos.isNotEmpty) {
          petPhotos.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
          _existingPhotoUrl = petPhotos.first['url'] as String?;
        }
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
    _nameCtrl.dispose();
    _razaCtrl.dispose();
    _edadAnhosCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) {
        throw 'Debes iniciar sesión.';
      }

      // edad_meses desde años
      final anhos = int.tryParse(_edadAnhosCtrl.text.trim());
      final edadMeses = (anhos == null) ? null : (anhos * 12);

      // Datos comunes
      final row = <String, dynamic>{
        'nombre': _nameCtrl.text.trim(),
        'especie': _especie,
        'sexo': _sexo,
        'estado': _estado,
        'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
        'edad_meses': edadMeses,
        'talla': _talla,
        'temperamento': _temperamento,
        'descripcion': _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
      };

      // Si es "encontrado" guardamos found_at si la columna existe
      if (_estado == 'encontrado') {
        row['found_at'] = DateTime.now().toIso8601String();
      }

      String petId;

      if (_editId != null) {
        // UPDATE
        petId = _editId!;
        await _sb.from('pets').update(row).eq('id', petId);
      } else {
        // INSERT
        row['owner_id'] = userId;
        final inserted = await _sb.from('pets').insert(row).select('id').single();
        petId = inserted['id'] as String;
      }

      // Subir imagen si hay nueva selección
      if (_imageBytes != null) {
        final path = '$userId/$petId-${DateTime.now().millisecondsSinceEpoch}-${_imageName ?? 'main.jpg'}';

        // Storage upload
        await _sb.storage.from('pet-images').uploadBinary(
              path,
              _imageBytes!,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );

        // Public URL
        final publicUrl = _sb.storage.from('pet-images').getPublicUrl(path);

        // Registrar/actualizar pet_photos (principal en position 0)
        // Borramos principal previa si existía (opcional)
        await _sb.from('pet_photos').delete().eq('pet_id', petId).eq('position', 0);

        await _sb.from('pet_photos').insert({
          'pet_id': petId,
          'url': publicUrl,
          'position': 0,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editId != null ? 'Mascota actualizada' : 'Mascota publicada')),
      );
      context.pop(); // volver
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
    final isEditing = _editId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(isEditing ? 'Editar mascota' : 'Publicar mascota'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Imagen
                    GestureDetector(
                      onTap: _pickImage,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                            image: (_imageBytes != null)
                                ? DecorationImage(
                                    image: MemoryImage(_imageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingPhotoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_existingPhotoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: (_imageBytes == null && _existingPhotoUrl == null)
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 36),
                                      SizedBox(height: 8),
                                      Text('Agregar foto principal'),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nombre
                    _Labeled(
                      icon: Icons.pets,
                      label: 'Nombre',
                      child: TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Firu',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Especie
                    _Labeled(
                      icon: Icons.category_outlined,
                      label: 'Especie',
                      child: DropdownButtonFormField<String>(
                        value: _especie,
                        items: const [
                          DropdownMenuItem(value: 'perro', child: Text('Perro')),
                          DropdownMenuItem(value: 'gato', child: Text('Gato')),
                        ],
                        onChanged: (v) => setState(() => _especie = v ?? 'perro'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sexo
                    _Labeled(
                      icon: Icons.people_outline,
                      label: 'Sexo',
                      child: DropdownButtonFormField<String>(
                        value: _sexo,
                        items: const [
                          DropdownMenuItem(value: 'macho', child: Text('Macho')),
                          DropdownMenuItem(value: 'hembra', child: Text('Hembra')),
                        ],
                        onChanged: (v) => setState(() => _sexo = v ?? 'macho'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Estado
                    _Labeled(
                      icon: Icons.flag_outlined,
                      label: 'Estado',
                      child: DropdownButtonFormField<String>(
                        value: _estado,
                        items: const [
                          DropdownMenuItem(value: 'publicado', child: Text('Publicado')),
                          DropdownMenuItem(value: 'adoptado', child: Text('Adoptado')),
                          DropdownMenuItem(value: 'reservado', child: Text('Reservado')),
                          DropdownMenuItem(value: 'perdido', child: Text('Perdido')),
                          DropdownMenuItem(value: 'encontrado', child: Text('Encontrado')),
                        ],
                        onChanged: (v) => setState(() => _estado = v ?? 'publicado'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Raza
                    _Labeled(
                      icon: Icons.badge_outlined,
                      label: 'Raza (opcional)',
                      child: TextFormField(
                        controller: _razaCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'Ej. Criollo'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Edad (años)
                    _Labeled(
                      icon: Icons.cake_outlined,
                      label: 'Edad (años)',
                      child: TextFormField(
                        controller: _edadAnhosCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Ej. 3'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Talla
                    _Labeled(
                      icon: Icons.straighten_outlined,
                      label: 'Talla',
                      child: DropdownButtonFormField<String>(
                        value: _talla,
                        items: const [
                          DropdownMenuItem(value: 'pequeña', child: Text('Pequeño')),
                          DropdownMenuItem(value: 'mediano', child: Text('Mediano')),
                          DropdownMenuItem(value: 'grande', child: Text('Grande')),
                        ],
                        onChanged: (v) => setState(() => _talla = v ?? 'pequeña'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Temperamento
                    _Labeled(
                      icon: Icons.mood_outlined,
                      label: 'Temperamento',
                      child: DropdownButtonFormField<String>(
                        value: _temperamento,
                        items: const [
                          DropdownMenuItem(value: 'juguetón', child: Text('Juguetón')),
                          DropdownMenuItem(value: 'tranquilo', child: Text('Tranquilo')),
                          DropdownMenuItem(value: 'activo', child: Text('Activo')),
                          DropdownMenuItem(value: 'amistoso', child: Text('Amistoso')),
                        ],
                        onChanged: (v) => setState(() => _temperamento = v ?? 'juguetón'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Descripción
                    _Labeled(
                      icon: Icons.notes_outlined,
                      label: 'Descripción',
                      child: TextFormField(
                        controller: _descripcionCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Cuéntanos algo de tu mascota…',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _save,
                      label: Text(isEditing ? 'Guardar cambios' : 'Publicar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade800)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
