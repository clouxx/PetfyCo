import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'pages/adopt_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_scaffold.dart';
import 'pages/tienda_page.dart';
import 'pages/my_pets_page.dart';
import 'providers/role_provider.dart';

// ✅ NUEVO: Forgot password page
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/recetas_page.dart';
import 'pages/conecta_page.dart';
import 'pages/historial_medico_page.dart';
import 'pages/servicios_page.dart';
import 'pages/pedidos_page.dart';
import 'services/notification_service.dart';
import 'config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Lee las variables de entorno pasadas con --dart-define
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

// Falla en tiempo de inicio si faltan las vars — evita arranque silencioso roto
void _assertEnvVars() {
  assert(_supabaseUrl.isNotEmpty, 'SUPABASE_URL no definido. Pasa --dart-define=SUPABASE_URL=...');
  assert(_supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY no definido. Pasa --dart-define=SUPABASE_ANON_KEY=...');
}

bool get _isMobile =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _assertEnvVars();

  if (_isMobile) {
    await Firebase.initializeApp();
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await AppConfig.init();
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  if (_isMobile) {
    await NotificationService.init();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        // Alias en español para deep-links externos — deben estar ANTES que cualquier
        // StatefulShellRoute porque go_router 14.x no llama el redirect global cuando
        // no hay match; registrar como GoRoute garantiza que el path queda en el bundle.
        GoRoute(path: '/perdidos', redirect: (_, __) => '/lost'),
        GoRoute(path: '/adoptar',  redirect: (_, __) => '/adopt'),
        GoRoute(path: '/store',    redirect: (_, __) => '/tienda'),

        // Rutas sin barra de navegación inferior
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, state) {
            // Email llega por GoRouter extra (no en URL) para evitar exposición en logs
            final email = state.extra as String?;
            return ResetPasswordPage(email: email);
          },
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterPage(),
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
          path: '/tienda',
          builder: (_, __) => const TiendaPage(),
        ),
        GoRoute(
          path: '/recetas',
          builder: (_, __) => const RecetasPage(),
        ),
        GoRoute(
          path: '/conecta',
          builder: (_, __) => const ConectaPage(),
        ),
        GoRoute(
          path: '/historial',
          builder: (_, __) => const HistorialMedicoPage(),
        ),
        GoRoute(
          path: '/servicios',
          builder: (_, __) => const ServiciosPage(),
        ),
        GoRoute(
          path: '/pedidos',
          builder: (_, __) => const PedidosPage(),
        ),

        // Ruta principal con barra inferior (4 tabs reales)
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScaffold(navigationShell: navigationShell);
          },
          branches: [
            // Rama 0 (Inicio)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, __) => const HomePage(),
                ),
              ],
            ),
            // Rama 1 (Perdidos)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/lost',
                  builder: (_, __) => const LostPetsPage(),
                ),
              ],
            ),
            // Rama 2 (Adoptar / Mis mascotas — depende del rol)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/adopt',
                  builder: (_, __) => const _RoleAwareMidPage(),
                ),
              ],
            ),
            // Rama 3 (Perfil)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, __) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    // Escuchar el evento de recuperación de contraseña (deep link de Supabase)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // Redirigir siempre a reset-password cuando venga un recovery link
        _router.go('/reset-password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PetfyCo',
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6FEB),
        useMaterial3: true,
      ),
    );
  }
}

/// Muestra AdoptPage para buscadores y MyPetsPage para publicadores.
class _RoleAwareMidPage extends ConsumerWidget {
  const _RoleAwareMidPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolProvider).valueOrNull ?? 'buscador';
    if (rol == 'publicador') return const MyPetsPage();
    return const AdoptPage();
  }
}
