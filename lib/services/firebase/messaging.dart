import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _notificationsEnabledKey = 'notifications_enabled';

  FirebaseMessaging get messaging => _messaging;

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    print('Notifications activées dans SharedPreferences : $enabled');
    return enabled;
  }
  
  Future<void> setNotificationsPreference(bool isEnabled) async {
    if (kDebugMode) {
      print('Mise à jour de la préférence de notification : $isEnabled');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, isEnabled);
  }

  Future<bool> getNotificationsStatus() async {
    if (kIsWeb) {
      print('Notifications non prises en charge sur le web');
      return false;
    }
    final settings = await _messaging.getNotificationSettings();
    print('État des permissions de notification : ${settings.authorizationStatus}');
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> initialize() async {
    print('Initialisation de FirebaseMessagingService');
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      print('Notifications désactivées, initialisation ignorée');
      return;
    }

    try {
      String? token;
      if (!kIsWeb) {
        // Demander la permission POST_NOTIFICATIONS pour Android 13+
        if (Platform.isAndroid) {
          final status = await Permission.notification.request();
          if (status.isDenied) {
            print('Permission de notification refusée');
            return;
          }
        }

        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        print('Permissions demandées : ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          token = await _messaging.getToken();
          print('FCM Token : $token');
        } else {
          print('Permissions de notification refusées');
          return;
        }
      } else {
        token = await _messaging.getToken();
        print('FCM Token (web) : $token');
      }

      // Enregistrer le token FCM dans Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('Token FCM enregistré pour ${user.uid} : $token');
      }

      // Initialiser les notifications locales pour Android/iOS
      if (!kIsWeb) {
        print('Initialisation des notifications locales');
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings();
        const initializationSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );
        await _localNotificationsPlugin.initialize(initializationSettings);
        print

          ('Notifications locales initialisées');
      }

      await _messaging.subscribeToTopic('all Ames');
      print('Abonnement au topic all_users');
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Gérer le rafraîchissement du token
      _messaging.onTokenRefresh.listen((newToken) async {
        print('Rafraîchissement du token FCM : $newToken');
        if (user != null) {
          await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({
            'fcmToken': newToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          print('Token FCM rafraîchi pour ${user.uid} : $newToken');
        }
      });

      print('Firebase Messaging initialisé pour ${kIsWeb ? 'web' : 'mobile'}');
    } catch (e, stackTrace) {
      print('Erreur lors de l\'initialisation de Firebase Messaging : $e\n$stackTrace');
    }
  }

  Future<void> setNotificationsEnabled(bool isEnabled) async {
    print('Activation/Désactivation des notifications : $isEnabled');
    await setNotificationsPreference(isEnabled);

    if (kIsWeb) {
      print('Gestion des notifications ignorée sur le web');
      return;
    }

    try {
      if (isEnabled) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        print('Permissions après activation : ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          await _messaging.subscribeToTopic('all_users');
          await initialize();
        }
      } else {
        await _messaging.unsubscribeFromTopic('all_users');
        print('Désabonnement du topic all_users');
      }
    } catch (e, stackTrace) {
      print('Erreur lors de la gestion des notifications : $e\n$stackTrace');
    }
  }

  Future<void> sendLocalNotification(String title, String body) async {
    if (kIsWeb) {
      print('Notification locale ignorée sur le web : $title - $body');
      return;
    }

    print('Vérification des permissions pour la notification locale');
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      print('Notifications désactivées par l\'utilisateur');
      return;
    }

    try {
      final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
      print('Envoi de la notification ID : $notificationId, Titre : $title, Corps : $body');

      final formattedBody = body.split('\n').map((line) => '• $line').join('\n');

      const androidDetails = AndroidNotificationDetails(
        'transfer_channel',
        'Transfer Notifications',
        channelDescription: 'Notifications for money transfers',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        groupKey: 'com.example.budget_zen.notifications',
        styleInformation: BigTextStyleInformation(''),
        ticker: 'Transfert effectué',
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      print('Appel de show pour la notification');
      await _localNotificationsPlugin.show(
        notificationId,
        title,
        formattedBody,
        platformDetails,
      );
      print('Notification locale envoyée avec succès');
    } catch (e, stackTrace) {
      print('Erreur lors de l\'envoi de la notification locale : $e\n$stackTrace');
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Notification en arrière-plan : ${message.notification?.title} - ${message.notification?.body}');

    // Initialiser flutter_local_notifications pour l'arrière-plan
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    final localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await localNotificationsPlugin.initialize(initializationSettings);

    // Afficher la notification
    if (message.notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'transfer_channel',
        'Transfer Notifications',
        channelDescription: 'Notifications for money transfers',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        groupKey: 'com.example.budget_zen.notifications',
        styleInformation: BigTextStyleInformation(''),
        ticker: 'Transfert effectué',
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
      await localNotificationsPlugin.show(
        notificationId,
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? 'Nouveau message reçu',
        platformDetails,
      );
      print('Notification locale affichée en arrière-plan');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Notification en premier plan : ${message.notification?.title} - ${message.notification?.body}');
    if (message.notification != null) {
      sendLocalNotification(
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? 'Nouveau message reçu',
      );
    }
  }
}