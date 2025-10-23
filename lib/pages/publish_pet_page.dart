// lib/pages/publish_pet_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  const PublishPetPage({super.key});

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
  String _especie = 'perro'; // perro | gato
  String? _sexo; // macho | hembra
  String _estado = 'publicado'; // publicado | adoptado | reservado | perdido
  String? _talla; // Pequeño|Mediano|Grande (texto libre)
  String? _temperamento; // Juguetón, Tranquilo, etc (texto libre)
  int? _edadAnios; // UI en años (se convertirá a meses)

  // Imágenes seleccionadas
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  bool _sending = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isNotEmpty) {
        setState(() => _images
          ..clear()
          ..addAll(files));
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
      // 1) Insertar mascota
      final insert = await _sb
          .from('pets')
          .insert({
            'owner_id': user.id, // requerido por RLS
            'especie': _especie,
            'nombre': _nombreCtrl.text.trim(),
            'raza': _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
            'sexo': _sexo,
            'edad_meses': _edadAnios == null ? null : _edadAnios! * 12,
            'talla': _talla,
            'temperamento': _temperamento,
            'descripcion':
                _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
            'estado': _estado,
          })
          .select('id')
          .single();

      final String petId = insert['id'] as String;

      // 2) Subir imágenes y crear filas en pet_photos
      for (int i = 0; i < _images.length; i++) {
        final img = _images[i];

        // Leemos los bytes para usar uploadBinary (sirve para web y mobile)
        final Uint8List bytes = await img.readAsBytes();

        // Extensión simple por path; si no se puede, usa jpg
        String ext = 'jpg';
        final pathLower = img.name.toLowerCase();
        if (pathLower.endsWith('.png')) ext = 'png';
        if (pathLower.endsWith('.jpeg')) ext = 'jpeg';
        if (pathLower.endsWith('.webp')) ext = 'webp';

        final storagePath =
            '${user.id}/$petId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        // Subir al bucket pet-images
        await _sb.storage.from('pet-images').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                cacheControl: '3600',
                contentType: 'image/$ext',
              ),
            );

        // URL pública
        final publicUrl =
            _sb.storage.from('pet-images').getPublicUrl(storagePath);

        // Insertar metadata de la foto
        await _sb.from('pet_photos').insert({
          'pet_id': petId,
          'url': publicUrl,
          'position': i,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Mascota publicada!'),
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
          content: Text('No se pudo publicar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Publicar mascota'),
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
                      // Nombre
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Ingresa el nombre'
                                : null,
                      ),
                      const SizedBox(height: 12),

                      // Especie
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

                      // Sexo
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

                      // Estado
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
                        onChanged: (v) =>
                            setState(() => _estado = v ?? 'publicado'),
                      ),
                      const SizedBox(height: 12),

                      // Raza
                      TextFormField(
                        controller: _razaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Raza (opcional)',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Años (se guardará como meses)
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

                      // Talla
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

                      // Temperamento
                      DropdownButtonFormField<String>(
                        value: _temperamento,
                        decoration: const InputDecoration(
                          labelText: 'Temperamento',
                          prefixIcon: Icon(Icons.emoji_emotions_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Juguetón', child: Text('Juguetón')),
                          DropdownMenuItem(value: 'Tranquilo', child: Text('Tranquilo')),
                          DropdownMenuItem(value: 'Guardían', child: Text('Guardián')),
                        ],
                        onChanged: (v) => setState(() => _temperamento = v),
                      ),
                      const SizedBox(height: 12),

                      // Descripción
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
                      // Imágenes
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Seleccionar imágenes'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _images.isEmpty
                                ? 'Sin imágenes'
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
                                  onPressed: () {
                                    setState(() => _images.removeAt(i));
                                  },
                                  icon: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),

                      const SizedBox(height: 24),
                      // Botón publicar
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_sending ? 'Publicando...' : 'Publicar'),
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
