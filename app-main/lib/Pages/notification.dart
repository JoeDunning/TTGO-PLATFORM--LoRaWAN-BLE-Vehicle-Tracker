// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// class Noti {
//   static Future initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
//     var androidInitialize = new AndroidInitializationSettings('mipmap/ic_launcher');
//     var initializationSettings = new InitializationSettings(android: androidInitialize);
//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//   }
//
//   static Future showBigTextNotification({
//     var id = 0,
//     required String title,
//     required String body,
//     var payload,
//     required FlutterLocalNotificationsPlugin fln,
//   }) async {
//     AndroidNotificationDetails androidPlatformChannelSpecifics = new AndroidNotificationDetails(
//       'you_can_name_it_whatever1',
//       'channel_name',
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('notification'),
//       importance: Importance.max,
//       priority: Priority.high,
//       ongoing: true, // Add this line to make the notification ongoing
//     );
//
//     var not = NotificationDetails(android: androidPlatformChannelSpecifics);
//     await fln.show(0, title, body, not);
//   }
// }
