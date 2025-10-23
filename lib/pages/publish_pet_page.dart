import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/petfy_widgets.dart';
import '../theme/app_theme.dart';

class PublishPetPage extends StatefulWidget {
  const PublishPetPage({super.key});

  @override
  State<PublishPetPage> createState() => _PublishPetPageState();
}

class _PublishPetPageState extends State<PublishPetPage> {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  // Controllers
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();

  // ADAPTADO: Valores según tu BD
  String _especie = 'gato';
  String? _raza;
  int? _edadMeses; // ADAPTADO: edad en meses (int)
  String? _talla; // ADAPTADO: tu columna
  String? _sexo; // ADAPTADO: tu columna (M/H)
  String? _temperamento; // NUEVO: tu columna
  String _estado = 'publicado'; // ADAPTADO: tu default

  // Ubicación - ADAPTADO
  final List<Map<String, dynamic>> _departments = [];
  final List<String> _cityNames = [];
  int? _deptId;
  String? _deptName;
  String? _cityName;

  // Imágenes
  final List<XFile> _images = [];
  final _picker = ImagePicker();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadUserLocation();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await _sb
          .from('departments')
          .select('id, name')
          .order('name', ascending: true);
      setState(() {
        _departments.clear();
        _departments.addAll(List<Map<String, dynamic>>.from(data));
      });
    } catch (e) {
      debugPrint('Error cargando departamentos: $e');
    }
  }

  Future<void> _loadCities(int deptId) async {
    try {
      final data = await _sb
          .from('cities')
          .select('name')
          .eq('department_id', deptId)
          .order('name', ascending: true);
      setState(() {
        _cityNames.clear();
        _cityNames.addAll(data.map((e) => e['name'] as String));
      });
    } catch (e) {
      debugPrint('Error cargando ciudades: $e');
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return;

      final profile = await _sb
          .from('profiles')
          .select('depto, municipio')
          .eq('id', user.id)
          .single();

      // Buscar department_id del depto del usuario
      if (profile['depto'] != null) {
        final depts = await _sb
            .from('departments')
            .select('id, name')
            .eq('name', profile['depto'])
            .single();
        
        setState(() {
          _deptId = depts['id'] as int;
          _deptName = depts['name'] as String;
          _cityName = profile['municipio'];
        });
        
        if (_deptId != null) {
          await _loadCities(_deptId!);
        }
      }
    } catch (e) {
      debugPrint('Error cargando ubicación del usuario: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedImages = await _picker.pickMultiImage();
      if (pickedImages.isNotEmpty) {
        setState(() {
          _images.addAll(pickedImages);
          if (_images.length > 5) {
            _images.removeRange(5, _images.length);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando imágenes: $e')),
      );
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> urls = [];
    
    for (var i = 0; i < _images.length; i++) {
      try {
        final file = _images[i];
        final bytes = await file.readAsBytes();
        final fileExt = file.path.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        final filePath = '${_sb.auth.currentUser!.id}/$fileName';

        await _sb.storage.from('pet-images').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$fileExt',
                upsert: false,
              ),
            );

        final url = _sb.storage.from('pet-images').getPublicUrl(filePath);
        urls.add(url);
      } catch (e) {
        debugPrint('Error subiendo imagen $i: $e');
      }
    }

    return urls;
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_deptName == null || _cityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona departamento y ciudad'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final user = _sb.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      // Subir imágenes
      final imageUrls = await _uploadImages();

      // ADAPTADO: Insertar mascota con tus columnas
      final petData = await _sb.from('pets').insert({
        'owner_id': user.id,
        'nombre': _nombre.text.trim(),
        'especie': _especie,
        'raza': _raza,
        'edad_meses': _edadMeses, // ADAPTADO
        'talla': _talla, // ADAPTADO
        'sexo': _sexo, // ADAPTADO
        'temperamento': _temperamento, // NUEVO
        'descripcion': _descripcion.text.trim(),
        'estado': _estado,
        'depto': _deptName, // ADAPTADO
        'municipio': _cityName, // ADAPTADO
      }).select().single();

      final petId = petData['id'];

      // ADAPTADO: Insertar fotos en tabla pet_photos
      if (imageUrls.isNotEmpty) {
        final photoInserts = imageUrls.asMap().entries.map((entry) {
          return {
            'pet_id': petId,
            'url': entry.value,
            'position': entry.key,
          };
        }).toList();

        await _sb.from('pet_photos').insert(photoInserts);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Mascota publicada exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al publicar: $e'),
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
        title: const Text('Publicar Mascota'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imágenes
              Text(
                'Fotos (máximo 5)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Botón agregar
                    InkWell(
                      onTap: _pickImages,
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.grey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40),
                            SizedBox(height: 4),
                            Text('Agregar fotos'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Imágenes seleccionadas
                    ..._images.map((img) {
                      final index = _images.indexOf(img);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                img.path,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() => _images.removeAt(index));
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nombre
              PetfyTextField(
                controller: _nombre,
                label: 'Nombre de la mascota *',
                hint: 'Ej: Firulais',
                prefix: const Icon(Icons.pets),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // Especie
              Text(
                'Especie *',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('🐶 Perro'),
                      value: 'perro',
                      groupValue: _especie,
                      onChanged: (v) => setState(() => _especie = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('🐱 Gato'),
                      value: 'gato',
                      groupValue: _especie,
                      onChanged: (v) => setState(() => _especie = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Estado - ADAPTADO
              Text(
                'Estado *',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Publicado'),
                    selected: _estado == 'publicado',
                    onSelected: (v) => setState(() => _estado = 'publicado'),
                  ),
                  ChoiceChip(
                    label: const Text('Reservado'),
                    selected: _estado == 'reservado',
                    onSelected: (v) => setState(() => _estado = 'reservado'),
                  ),
                  ChoiceChip(
                    label: const Text('Adoptado'),
                    selected: _estado == 'adoptado',
                    onSelected: (v) => setState(() => _estado = 'adoptado'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Raza
              PetfyTextField(
                label: 'Raza (opcional)',
                hint: 'Ej: Golden Retriever',
                onChanged: (v) => _raza = v.isEmpty ? null : v,
              ),
              const SizedBox(height: 16),

              // Edad en meses - ADAPTADO
              PetfyTextField(
                label: 'Edad en meses (opcional)',
                hint: 'Ej: 24 (2 años)',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  _edadMeses = int.tryParse(v);
                },
              ),
              const SizedBox(height: 16),

              // Talla - ADAPTADO
              PetfyDropdown<String>(
                label: 'Talla',
                value: _talla,
                items: ['pequeña', 'mediana', 'grande']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _talla = v),
              ),
              const SizedBox(height: 16),

              // Sexo - ADAPTADO
              PetfyDropdown<String>(
                label: 'Sexo',
                value: _sexo,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Macho')),
                  DropdownMenuItem(value: 'H', child: Text('Hembra')),
                ],
                onChanged: (v) => setState(() => _sexo = v),
              ),
              const SizedBox(height: 16),

              // Temperamento - NUEVO
              PetfyTextField(
                label: 'Temperamento (opcional)',
                hint: 'Ej: Juguetón, tranquilo, activo',
                onChanged: (v) => _temperamento = v.isEmpty ? null : v,
              ),
              const SizedBox(height: 16),

              // Ubicación - ADAPTADO
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _deptId,
                      decoration: InputDecoration(
                        labelText: 'Departamento *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem<int>(
                          value: dept['id'] as int,
                          child: Text(dept['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selectedDept = _departments.firstWhere(
                            (d) => d['id'] == val,
                          );
                          setState(() {
                            _deptId = val;
                            _deptName = selectedDept['name'] as String;
                            _cityName = null;
                            _cityNames.clear();
                          });
                          _loadCities(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _cityName,
                      decoration: InputDecoration(
                        labelText: 'Ciudad *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      items: _cityNames.map((city) {
                        return DropdownMenuItem<String>(
                          value: city,
                          child: Text(city),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _cityName = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descripción
              PetfyTextField(
                controller: _descripcion,
                label: 'Descripción',
                hint:
                    'Cuéntanos más sobre esta mascota (personalidad, cuidados especiales, etc.)',
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              // Botón publicar
              PetfyButton(
                text: 'Publicar Mascota',
                loading: _sending,
                onPressed: _sending ? null : _submit,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
