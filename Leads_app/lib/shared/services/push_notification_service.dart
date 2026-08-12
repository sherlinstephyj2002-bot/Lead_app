import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('PushNotificationService: User granted notification permission');

        // Fetch FCM token
        String? token = await _fcm.getToken();
        if (token != null) {
          debugPrint('PushNotificationService: FCM Registration Token: $token');
        }

        // Handle foreground notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('PushNotificationService: Received a foreground message');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification?.title} - ${message.notification?.body}');
          }
        });
      } else {
        debugPrint('PushNotificationService: User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Initialization failed: $e');
    }
  }
}
