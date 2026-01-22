import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PAGES (ajusta los imports a tus rutas reales)
import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/publish_pet_page.dart';
import 'pages/pet_detail_page.dart';
import 'pages/lost_pets_page.dart';
import 'pages/profile_page.dart';

// ✅ NUEVO: Forgot password page
import 'pages/forgot_password_page.dart';

// Lee las variables de entorno pasadas con --dart-define
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
        ),

        // ✅ NUEVO: Ruta para "Olvidé mi contraseña"
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage(),
        ),

        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/publish',
          builder: (_, state) {
            final presetEstado = state.uri.queryParameters['estado'];
            final editId = state.uri.queryParameters['editId'];
            return PublishPetPage(
              presetEstado: presetEstado,
              editPetId: editId,
            );
          },
        ),
        GoRoute(
          path: '/pet/:id',
          builder: (_, state) => PetDetailPage(
            petId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/lost',
          builder: (_, __) => const LostPetsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, state) {
            final uid = state.uri.queryParameters['uid'];
            return const ProfilePage(); // Ajusta si vas a usar uid
          },
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const SplashPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'PetfyCo',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6FEB),
        useMaterial3: true,
      ),
    );
  }
}
