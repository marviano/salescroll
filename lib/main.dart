import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:salescroll/widgets/auth_wrapper.dart';
import 'dart:io';
import 'MasterCustomer.dart';
import 'MasterRestaurant.dart';
// import 'RestaurantPackages.dart';
import 'package:google_fonts/google_fonts.dart';
import 'SalesCustomerEnrollment.dart';
import 'widgets/network_error_handler.dart';
import 'Login.dart';
import 'CustomerRegistration.dart';
import 'Dashboard.dart';

// Initialize the local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('DEBUG: Handling a background message: ${message.messageId}');
  print('DEBUG: Message data: ${message.data}');
  print('DEBUG: Message notification: ${message.notification?.title}');
}

Future<void> showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'meeting_notifications', // channel id
    'Meeting Notifications', // channel name
    channelDescription: 'Notifications for upcoming meetings',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
  DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    platformChannelSpecifics,
  );
}

Future<void> setupFlutterNotifications() async {
  // Initialize Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'meeting_notifications', // same channel id as above
    'Meeting Notifications', // same channel name as above
    description: 'Notifications for upcoming meetings',
    importance: Importance.max,
  );

  // Create the Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize notification settings
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('DEBUG: Notification tapped: ${response.payload}');
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up notifications
  await setupFlutterNotifications();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions for iOS
  if (Platform.isIOS) {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  // Configure FCM settings
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('DEBUG: Got a message whilst in the foreground!');
      print('DEBUG: Message data: ${message.data}');

      if (message.notification != null) {
        print('DEBUG: Message also contained a notification:');
        print('DEBUG: Title: ${message.notification?.title}');
        print('DEBUG: Body: ${message.notification?.body}');

        // Show the notification using flutter_local_notifications
        showNotification(message);
      }
    });

    // Handle when the app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('DEBUG: Message clicked!');
      // Here you can handle navigation when user clicks the notification
    });

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('DEBUG: App opened from terminated state with message:');
        print('DEBUG: Message data: ${message.data}');
        // Handle initial message if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NetworkErrorHandler(
      child: MaterialApp(
        title: 'Restaurant Sales App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          // Simple way to apply Itim to everything:
          textTheme: GoogleFonts.itimTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        home: AuthWrapper(
          child: DashboardPage(),
        ),
        routes: {
          '/login': (context) => LoginPage(),
          '/dashboard': (context) => AuthWrapper(child: DashboardPage()),
          '/customer_registration': (context) => AuthWrapper(child: CustomerRegistrationPage()),
          '/master_customer': (context) => AuthWrapper(child: MasterCustomerPage()),
          '/master_restaurant': (context) => AuthWrapper(child: MasterRestaurantPage()),
          '/sales_customer_enrollment': (context) => AuthWrapper(child: SalesCustomerEnrollmentPage()),
        },
      ),
    );
  }
}