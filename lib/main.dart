import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'pages/splash_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/pet_detail_page.dart';
import 'pages/publish_pet_page.dart';
import 'pages/lost_pets_page.dart';
import 'pages/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Supabase con variables de entorno
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

// Router global con todas las rutas
final _router = GoRouter(
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
    GoRoute(
      path: '/register',
      builder: (_, __) => const RegisterPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomePage(),
    ),
    GoRoute(
      path: '/pet/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        return PetDetailPage(petId: id);
      },
    ),
    GoRoute(
      path: '/publish',
      builder: (_, __) => const PublishPetPage(),
    ),
    GoRoute(
      path: '/lost',
      builder: (_, __) => const LostPetsPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const ProfilePage(),
    ),
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
      theme: AppTheme.light,
    );
  }
}
