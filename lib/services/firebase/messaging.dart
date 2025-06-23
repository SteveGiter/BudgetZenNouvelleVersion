import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _notificationsEnabledKey = 'notifications_enabled';

  FirebaseMessaging get messaging => _messaging;

  // Vérifier si les notifications sont activées (persistantes)
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Par défaut, true si non défini (première ouverture)
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  // Mettre à jour l'état persistant des notifications
  Future<void> setNotificationsPreference(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, isEnabled);
  }

  // Obtenir l'état des permissions système
  Future<bool> getNotificationsStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> initialize() async {
    // Vérifier l'état persistant avant d'initialiser
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      // Si désactivé, ne pas initialiser FCM
      return;
    }

    // Demander la permission pour les notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Obtenir le token FCM
      final token = await _messaging.getToken();
      if (kDebugMode) {
        print("FCM Token: $token");
      }

      // Initialiser les notifications locales
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotificationsPlugin.initialize(initializationSettings);

      // S'abonner au sujet si activé
      await _messaging.subscribeToTopic('all_users');

      // Configurer les gestionnaires de messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    }
  }

  // Méthode pour activer ou désactiver les notifications
  Future<void> setNotificationsEnabled(bool isEnabled) async {
    // Mettre à jour l'état persistant
    await setNotificationsPreference(isEnabled);

    if (isEnabled) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // S'abonner au sujet
        await _messaging.subscribeToTopic('all_users');
        // Réinitialiser les gestionnaires si nécessaire
        await initialize();
      }
    } else {
      // Se désinscrire du sujet
      await _messaging.unsubscribeFromTopic('all_users');
    }
  }

  // Méthode pour envoyer une notification locale
  Future<void> sendLocalNotification(String title, String body) async {
    // Vérifier si les notifications sont activées avant d'envoyer
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'login_channel',
      'Login Notifications',
      channelDescription: 'Notifications for successful logins',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await _localNotificationsPlugin.show(0, title, body, platformDetails);
  }

  // Gestionnaire pour les messages en arrière-plan
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print("Background Notification: ${message.notification?.title} - ${message.notification?.body}");
    }
  }

  // Gestionnaire pour les messages en premier plan
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print("Foreground Notification: ${message.notification?.title} - ${message.notification?.body}");
    }
    if (message.notification != null) {
      sendLocalNotification(
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? 'Nouveau message reçu',
      );
    }
  }
}