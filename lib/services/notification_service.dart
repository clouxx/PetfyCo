import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Background handler (must be top-level) ─────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are shown automatically by FCM on Android.
  // On iOS they appear as system notifications.
}

// ─── Notification Service ────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final _local = FlutterLocalNotificationsPlugin();
  static final _fcm   = FirebaseMessaging.instance;

  static const _androidChannel = AndroidNotificationChannel(
    'petfyco_alerts',
    'Alertas PetfyCo',
    description: 'Nuevas mascotas, adopciones y más',
    importance: Importance.high,
    playSound: true,
  );

  /// Call once from main() after Firebase.initializeApp()
  static Future<void> init() async {
    // 1. Local notifications setup
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: false, // we request below
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // Create Android channel
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 2. FCM permissions
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false, announcement: false,
      carPlay: false, criticalAlert: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // 3. Get token and save to Supabase
      await _refreshToken();
      _fcm.onTokenRefresh.listen(_saveToken);

      // 4. Foreground messages → show local notification
      FirebaseMessaging.onMessage.listen(_onForeground);

      // 5. Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // 6. iOS foreground presentation
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
    }
  }

  static Future<void> _refreshToken() async {
    try {
      String? token;
      if (Platform.isIOS) {
        // iOS needs APNs token first
        await _fcm.getAPNSToken();
      }
      token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e, st) {
      debugPrint('[NotificationService] Error obteniendo token FCM: $e\n$st');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', uid);
    } catch (e, st) {
      debugPrint('[NotificationService] Error guardando token FCM: $e\n$st');
    }
  }

  /// Call when user logs out to clear the token
  static Future<void> clearToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', uid);
      }
      await _fcm.deleteToken();
    } catch (e, st) {
      debugPrint('[NotificationService] Error en clearToken: $e\n$st');
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  static Future<void> _onForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static void _onLocalTap(NotificationResponse response) {
    // Future: navigate based on payload
  }
}
