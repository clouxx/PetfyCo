import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración central de la app.
/// En tarea #3 esto se migra a Firebase Remote Config.
class AppConfig {
  AppConfig._();

  /// Email de negocio de PetfyCo — admin de la plataforma
  static const String adminEmail = 'petfyco.sas@gmail.com';

  /// Número WhatsApp de la empresa (sin +, con código país)
  static const String whatsappNumber = '573177931145';

  /// Verifica si el usuario actual es admin de la plataforma
  static bool get isCurrentUserAdmin {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return email == adminEmail;
  }
}
