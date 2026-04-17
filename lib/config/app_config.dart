import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  AppConfig._();

  static const String _defaultWhatsapp = '573177931145';
  static const String _defaultAdminEmail = 'petfyco.sas@gmail.com';

  static String _whatsappNumber = _defaultWhatsapp;

  static String get whatsappNumber => _whatsappNumber;

  /// Email de negocio de PetfyCo — admin de la plataforma
  static const String adminEmail = _defaultAdminEmail;

  /// Inicializa Remote Config y carga los valores remotos.
  /// Llamar una sola vez en main() después de Firebase.initializeApp().
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults({
        'whatsapp_number': _defaultWhatsapp,
      });
      await rc.fetchAndActivate();
      _whatsappNumber = rc.getString('whatsapp_number').isNotEmpty
          ? rc.getString('whatsapp_number')
          : _defaultWhatsapp;
    } catch (_) {
      // Si Remote Config falla, usa el valor por defecto — la app sigue funcionando
    }
  }

  /// Verifica si el usuario actual es admin de la plataforma
  static bool get isCurrentUserAdmin {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return email == adminEmail;
  }
}
