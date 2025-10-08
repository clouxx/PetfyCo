import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'widgets/petfy_widgets.dart';
import 'pages/login_page.dart';
// 👇 importa tu pantalla*
import 'ui/home/petfy_home.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://YOUR-PROJECT.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR-ANON-KEY'),
  );
  runApp(const ProviderScope(child: App()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/pages', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/home', builder: (_, __) => const PetfyHome()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PetfyCo',
      routerConfig: _router,
      theme: buildPetfyTheme(),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (!context.mounted) return;
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const PetfyHeader(
              title: 'Login',
              asset: 'assets/logo/petfyco_logo_full.png',
            ),
            const SizedBox(height: 8),
            PetfyTextField(controller: emailCtrl, hint: 'Correo electrónico', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            PetfyTextField(controller: passCtrl, hint: 'Contraseña', obscure: true),
            const SizedBox(height: 16),
            PetfyPrimaryButton(
              label: loading ? 'Entrando...' : 'Login',
              onTap: loading ? null : () async {
                setState(() => loading = true);
                try {
                  await Supabase.instance.client.auth.signInWithPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                  );
                  if (context.mounted) context.go('/home');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => loading = false);
                }
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ),
          ],
        ),
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
  String? _error;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const PetfyHeader(
              title: 'Regístrate',
              asset: 'assets/logo/petfyco_logo_full.png',
            ),
            PetfyTextField(controller: nameCtrl, hint: 'Nombre'),
            const SizedBox(height: 12),
            PetfyTextField(controller: emailCtrl, hint: 'Correo electrónico', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            PetfyTextField(controller: passCtrl, hint: 'Contraseña', obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            PetfyPrimaryButton(
              label: loading ? 'Creando...' : 'Registrarse',
              onTap: loading ? null : () async {
                final p = passCtrl.text;
                final ok = RegExp(r'[A-Z]').hasMatch(p) &&
                    RegExp(r'[a-z]').hasMatch(p) &&
                    RegExp(r'\d').hasMatch(p) &&
                    RegExp(r'[!@#\$%\^&\*]').hasMatch(p) &&
                    p.length >= 8;

                if (!ok) {
                  setState(() => _error = 'La contraseña debe tener mayúscula, minúscula, número, especial y 8+ caracteres.');
                  return;
                } else {
                  setState(() => _error = null);
                }

                setState(() => loading = true);
                try {
                  final supa = Supabase.instance.client;
                  final res = await supa.auth.signUp(email: emailCtrl.text.trim(), password: passCtrl.text);
                  final uid = res.user?.id;
                  if (uid != null) {
                    await supa.from('profiles').insert({'id': uid, 'display_name': nameCtrl.text});
                  }
                  if (context.mounted) context.go('/home');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => loading = false);
                }
              },
            ),
            const SizedBox(height: 12),
            PetfyGhostButton(label: 'Volver al login', onTap: () => context.go('/login')),
          ],
        ),
      ),
    );
  }
}
