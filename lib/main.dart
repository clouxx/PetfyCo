import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://YOUR-PROJECT.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'YOUR-ANON-KEY',
    ),
  );
  runApp(const ProviderScope(child: App()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PetfyCo',
      theme: buildPetfyTheme(),
      routerConfig: _router,
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final user = Supabase.instance.client.auth.currentUser;
      context.go(user == null ? '/login' : '/home');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() => loading = true);
                    try {
                      await Supabase.instance.client.auth.signInWithPassword(
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text,
                      );
                      if (context.mounted) context.go('/home');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
            child: Text(loading ? 'Entrando...' : 'Login'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('¿No tienes cuenta? Regístrate'),
          )
        ]),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  bool loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regístrate')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo electrónico')),
          const SizedBox(height: 12),
          TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_error ?? '', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: loading
                ? null
                : () async {
                    final p = passCtrl.text;
                    final ok = RegExp(r'[A-Z]').hasMatch(p) &&
                        RegExp(r'[a-z]').hasMatch(p) &&
                        RegExp(r'\d').hasMatch(p) &&
                        RegExp(r'[!@#\$%\^&\*]').hasMatch(p) &&
                        p.length >= 8;
                    if (!ok) {
                      setState(() => _error =
                          'La contraseña debe tener mayúscula, minúscula, número, especial y 8+ caracteres.');
                      return;
                    }
                    setState(() => loading = true);
                    try {
                      final supa = Supabase.instance.client;
                      final res = await supa.auth.signUp(
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text,
                      );
                      final uid = res.user?.id;
                      if (uid != null) {
                        await supa.from('profiles').insert({
                          'id': uid,
                          'display_name': nameCtrl.text,
                        });
                      }
                      if (context.mounted) context.go('/home');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
            child: Text(loading ? 'Creando...' : 'Registrarse'),
          ),
        ]),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PetfyCo')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('pets')
            .select('id, nombre, especie, municipio, estado')
            .limit(20),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          if (data.isEmpty) return const Center(child: Text('No hay mascotas publicadas aún'));
          return ListView.separated(
            itemBuilder: (_, i) {
              final p = data[i];
              return ListTile(
                title: Text(p['nombre'] ?? '🐾'),
                subtitle: Text('${p['especie']} • ${p['municipio'] ?? ''} • ${p['estado']}'),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: data.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final supa = Supabase.instance.client;
          final user = supa.auth.currentUser;
          if (user == null) {
            if (context.mounted) context.go('/login');
            return;
          }
          await supa.from('pets').insert({
            'owner_id': user.id,
            'especie': 'gato',
            'nombre': 'Michi de prueba',
            'estado': 'publicado',
          });
          if (mounted) setState(() {});
        },
        label: const Text('Subir mascota demo'),
      ),
    );
  }
}
