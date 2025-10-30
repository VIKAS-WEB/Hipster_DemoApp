
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final _notifications = FlutterLocalNotificationsPlugin();

//   static Future init() async {
//     const android = AndroidInitializationSettings('app_icon');
//     const settings = InitializationSettings(android: android);
//     await _notifications.initialize(settings);
//   }

//   static Future showNotification(String title, String body) async {
//     const details = NotificationDetails(android: AndroidNotificationDetails('channel_id', 'Channel Name'));
//     await _notifications.show(0, title, body, details);
//   }
// }