import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'env.dart';

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('DEBUG: Handling background message');
  print('DEBUG: Message data: ${message.data}');
  print('DEBUG: Message notification: ${message.notification?.toMap()}');
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    print('DEBUG: Initializing NotificationService');

    try {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('DEBUG: Local notification tapped: ${response.payload}');
          _handleNotificationTap(json.decode(response.payload ?? '{}'));
        },
      );

      print('DEBUG: Requesting notification permissions');
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      print('DEBUG: Permission status: ${settings.authorizationStatus}');
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('DEBUG: Notifications not authorized! Status: ${settings.authorizationStatus}');
        return;
      }

      String? token = await _firebaseMessaging.getToken();
      print('DEBUG: FCM Token obtained: ${token?.substring(0, 20)}...');

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (token != null && _auth.currentUser != null) {
        print('DEBUG: Updating FCM token in database');
        await _updateFcmToken(token);
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      print('DEBUG: Message handlers set up successfully');
    } catch (e) {
      print('DEBUG: Error initializing NotificationService: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('DEBUG: Handling foreground message');
    print('DEBUG: Message data: ${message.data}');
    print('DEBUG: Message notification: ${message.notification?.toMap()}');

    try {
      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        notificationDetails,
        payload: json.encode(message.data),
      );
      print('DEBUG: Local notification displayed successfully');
    } catch (e) {
      print('DEBUG: Error showing local notification: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('DEBUG: User tapped on notification (app opened)');
    print('DEBUG: Message data: ${message.data}');
    print('DEBUG: Message notification: ${message.notification?.toMap()}');
    _handleNotificationTap(message.data);
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    print('DEBUG: Handling notification tap with data: $data');
  }

  static Future<void> _updateFcmToken(String token) async {
    final url = '${Env.apiUrl}/api/users/fcm-token';
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      print('DEBUG: No user logged in, skipping FCM token update');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': currentUser.uid,
          'fcm_token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: FCM token updated successfully');
      } else {
        print('DEBUG: Failed to update FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error updating FCM token: $e');
    }
  }

  static Future<void> clearToken() async {
    print('DEBUG: Clearing FCM token');
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('DEBUG: No user logged in, skipping token clear');
      return;
    }

    try {
      await _firebaseMessaging.deleteToken();

      final url = '${Env.apiUrl}/api/users/fcm-token';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': currentUser.uid,
          'fcm_token': null,
        }),
      );

      if (response.statusCode == 200) {
        print('DEBUG: FCM token cleared successfully');
      } else {
        print('DEBUG: Failed to clear FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error clearing FCM token: $e');
      rethrow;
    }
  }

  static Future<void> sendTestNotification() async {
    print('DEBUG: Current FCM token before test: ${await _firebaseMessaging.getToken()}');

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('DEBUG: No user logged in, cannot send test notification');
      return;
    }

    print('DEBUG: Sending test notification for user: ${currentUser.uid}');
    try {
      final url = '${Env.apiUrl}/api/notifications/test';
      print('DEBUG: Making request to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': currentUser.uid,
        }),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('DEBUG: Test notification sent successfully');
      } else {
        print('DEBUG: Failed to send test notification. Status: ${response.statusCode}');
        print('DEBUG: Error response: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Error sending test notification: $e');
    }
  }
}