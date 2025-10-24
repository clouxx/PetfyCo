// lib/pages/publish_pet_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  const PublishPetPage({
    super.key,
    this.presetEstado,
    this.editPetId, // <-- ahora lo aceptamos
  });

  /// Preselección del estado al crear (publicado|reservado|adoptado|perdido)
  final String? presetEstado;

  /// Si no es null, entramos en modo edición y cargamos esa mascota
  final String? editPetId;

  @override
  State<PublishPetPage> createState() => _PublishPetPageState();
}

class _PublishPetPageState extends State<PublishPetPage> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  // Campos
  String _especie = 'perro';
  String? _sexo; // macho | hembra
  String _estado = 'publicado';
  String? _talla;
  String? _temperamento;
  int? _edadAnios; // se guarda como meses=*12

  // Imágenes nuevas a subir
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  // Imágenes ya existentes (solo para mostrar en edición)
  List<Map<String, dynamic>> _existingPhotos = [];

  bool _sending = false;
  bool get _isEdit => widget.editPetId != null;

  @override
  void initState() {
    super.initState();

    // Preselección de estado si viene por query
    final e = widget.presetEstado?.toLowerCase();
    if (e == 'publicado' || e == 'reservado' || e == 'adoptado' || e == 'perdido') {
      _estado = e!;
    }

    // Cargar datos si es edición
    if (_isEdit) _loadForEdit();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadForEdit() async {
    try {
      final pet = await _sb
          .from('pets')
          .select('''
            id, especie, nombre, raza, sexo, edad_meses, talla, temperamento,
            descripcion, estado,
            pet_photos(url, position)
          ''')
          .eq('id', widget.editPetId!)
          .single();

      setState(() {
        _especie = (pet['especie'] as String?) ?? 'perro';
        _nombreCtrl.text = (pet['nombre'] as String?) ?? '';
        _razaCtrl.text = (pet['raza'] as String?) ?? '';
        _sexo = pet['sexo'] as String?;
        final edadMeses = pet['edad_meses'] as int?;
        _edadAnios = edadMeses == null ? null : edadMeses ~/ 12;
        _talla = pet['talla'] as String?;
        _temperamento = pet['temperamento'] as String?;
        _descripcionCtrl.text = (pet['descripcion'] as String?) ?? '';
        _estado = (pet['estado'] as String?) ?? 'publicado';

        final ph = pet['pet_photos'];
        _existingPhotos = ph is List
            ? ph.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _existingPhotos.sort(
          (a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la mascota: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) {
        setState(() {
          _images
            ..clear()
            ..addAll(files);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron seleccionar imágenes: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = _sb.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      String petId;

      if (_isEdit) {
        // UPDATE
        petId = widget.editPetId!;
        await _sb
            .from('pets')
            .update({
              'especie': _especie,
              'nombre': _nombreCtrl.text.trim(),
              'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
              'sexo': _sexo,
              'edad_meses': _edadAnios == null ? null : _edadAnios! * 12,
              'talla': _talla,
              'temperamento': _temperamento,
              'descripcion': _descripcionCtrl.text.trim().isEmpty
                  ? null
                  : _descripcionCtrl.text.trim(),
              'estado': _estado,
            })
            .eq('id', petId);
      } else {
        // INSERT
        final insert = await _sb
            .from('pets')
            .insert({
              'owner_id': user.id,
              'especie': _especie,
              'nombre': _nombreCtrl.text.trim(),
              'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
              'sexo': _sexo,
              'edad_meses': _edadAnios == null ? null : _edadAnios! * 12,
              'talla': _talla,
              'temperamento': _temperamento,
              'descripcion': _descripcionCtrl.text.trim().isEmpty
                  ? null
                  : _descripcionCtrl.text.trim(),
              'estado': _estado,
            })
            .select('id')
            .single();

        petId = insert['id'] as String;
      }

      // SUBIR nuevas imágenes (si hay)
      for (int i = 0; i < _images.length; i++) {
        final img = _images[i];
        final Uint8List bytes = await img.readAsBytes();

        String ext = 'jpg';
        final lower = img.name.toLowerCase();
        if (lower.endsWith('.png')) ext = 'png';
        if (lower.endsWith('.jpeg')) ext = 'jpeg';
        if (lower.endsWith('.webp')) ext = 'webp';

        final storagePath =
            '${user.id}/$petId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        await _sb.storage.from('pet-images').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                cacheControl: '3600',
                contentType: 'image/$ext',
              ),
            );

        final publicUrl =
            _sb.storage.from('pet-images').getPublicUrl(storagePath);

        // posición: continuamos después de las existentes
        final positionBase = _existingPhotos.isEmpty
            ? 0
            : ((_existingPhotos.last['position'] as int? ?? 0) + 1);

        await _sb.from('pet_photos').insert({
          'pet_id': petId,
          'url': publicUrl,
          'position': positionBase + i,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '¡Mascota actualizada!' : '¡Mascota publicada!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de base de datos: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo ${_isEdit ? 'actualizar' : 'publicar'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Editar mascota' : 'Publicar mascota';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _especie,
                        decoration: const InputDecoration(
                          labelText: 'Especie',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'perro', child: Text('Perro')),
                          DropdownMenuItem(value: 'gato', child: Text('Gato')),
                        ],
                        onChanged: (v) => setState(() => _especie = v ?? 'perro'),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _sexo,
                        decoration: const InputDecoration(
                          labelText: 'Sexo',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'macho', child: Text('Macho')),
                          DropdownMenuItem(value: 'hembra', child: Text('Hembra')),
                        ],
                        onChanged: (v) => setState(() => _sexo = v),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _estado,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'publicado', child: Text('Publicado')),
                          DropdownMenuItem(value: 'reservado', child: Text('Reservado')),
                          DropdownMenuItem(value: 'adoptado', child: Text('Adoptado')),
                          DropdownMenuItem(value: 'perdido', child: Text('Perdido')),
                        ],
                        onChanged: (v) => setState(() => _estado = v ?? 'publicado'),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _razaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Raza (opcional)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Edad (años)',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          setState(() => _edadAnios = parsed);
                        },
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _talla,
                        decoration: const InputDecoration(
                          labelText: 'Talla',
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Pequeño', child: Text('Pequeño')),
                          DropdownMenuItem(value: 'Mediano', child: Text('Mediano')),
                          DropdownMenuItem(value: 'Grande', child: Text('Grande')),
                        ],
                        onChanged: (v) => setState(() => _talla = v),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _temperamento,
                        decoration: const InputDecoration(
                          labelText: 'Temperamento',
                          prefixIcon: Icon(Icons.emoji_emotions_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Juguetón', child: Text('Juguetón')),
                          DropdownMenuItem(value: 'Tranquilo', child: Text('Tranquilo')),
                          DropdownMenuItem(value: 'Guardián', child: Text('Guardián')),
                        ],
                        onChanged: (v) => setState(() => _temperamento = v),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _descripcionCtrl,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_existingPhotos.isNotEmpty) ...[
                        const Text('Fotos actuales', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _existingPhotos.map((p) {
                            final url = p['url'] as String?;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: url == null
                                  ? const SizedBox.shrink()
                                  : Image.network(url, width: 110, height: 110, fit: BoxFit.cover),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Añadir imágenes'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _images.isEmpty
                                ? 'Sin nuevas imágenes'
                                : '${_images.length} seleccionadas',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_images.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(_images.length, (i) {
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _images[i].path,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setState(() => _images.removeAt(i)),
                                  icon: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),

                      const SizedBox(height: 24),

                      ElevatedButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_isEdit
                                ? Icons.save_outlined
                                : Icons.cloud_upload_outlined),
                        label: Text(_sending
                            ? (_isEdit ? 'Guardando...' : 'Publicando...')
                            : (_isEdit ? 'Guardar cambios' : 'Publicar')),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
