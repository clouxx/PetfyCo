import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _pets = [];
  bool _loading = true;
  String _filter = 'todos';       // todos, perro, gato
  String _statusFilter = 'publicado'; // tu BD

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _loading = true);
    try {
      // 👇 Construimos el builder y aplicamos filtros ANTES de select()
      var q = _sb.from('pets').eq('estado', _statusFilter);
      if (_filter != 'todos') {
        q = q.eq('especie', _filter);
      }

      final data = await q
          .select('''
            *,
            profiles:owner_id(display_name, phone),
            pet_photos(url, position)
          ''')
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _pets = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando mascotas: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _sb.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo/petfyco_logo_full.png', height: 40),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/publish'),
        icon: const Icon(Icons.add),
        label: const Text('Publicar mascota'),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPets,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.all(16), child: _HeaderBanner()),
            ),

            // Filtros especie
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _filter == 'todos',
                      onTap: () { setState(() => _filter = 'todos'); _loadPets(); },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🐶 Perros',
                      selected: _filter == 'perro',
                      onTap: () { setState(() => _filter = 'perro'); _loadPets(); },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🐱 Gatos',
                      selected: _filter == 'gato',
                      onTap: () { setState(() => _filter = 'gato'); _loadPets(); },
                    ),
                  ],
                ),
              ),
            ),

            // Filtros estado
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusChip(
                        label: 'Publicados',
                        selected: _statusFilter == 'publicado',
                        onTap: () { setState(() => _statusFilter = 'publicado'); _loadPets(); },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusChip(
                        label: 'Adoptados',
                        selected: _statusFilter == 'adoptado',
                        onTap: () { setState(() => _statusFilter = 'adoptado'); _loadPets(); },
                      ),
                    ),
                  ],
                ),
              ),
