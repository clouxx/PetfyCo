import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'ui/home/petfy_home.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Web mantenemos hash-style URLs (#/ruta) para evitar config extra.
  // (Si prefieres path-style, podemos cambiarlo luego.)
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PetfyCo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // desde theme/app_theme.dart
      routerConfig: _router,
    );
  }
}

/// Rutas principales de la app.
/// Si luego necesitas protección por auth, aquí mismo agregamos redirects.
final GoRouter _router = GoRouter(
  initialLocation: '/login',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      redirect: (_, __) => '/login',
    ),
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const PetfyHome(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('PetfyCo')),
    body: Center(
      child: Text(
        kDebugMode
            ? 'Ruta no encontrada: ${state.uri}'
            : 'Página no encontrada',
      ),
    ),
  ),
);
