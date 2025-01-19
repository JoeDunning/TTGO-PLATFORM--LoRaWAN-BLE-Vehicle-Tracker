/*
Main - Main Class, Called Upon INIT

//  Main
void main() async   // Main Function  - Called Upon INIT

- class LoginPage MyApp StatelessWidget

    // Build Method
    Widget build(BuildContext context)

*/

// Import Flutter Packages
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:RideSafe/Authentication/main_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/timezone.dart';

/*
----------- Definitions & Variables -----------
*/

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

/*
----------- Code Section Start -----------
*/

// Main Function  - Called Upon INIT
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());

  var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// MyApp State Definition
class MyApp extends StatelessWidget{
  const MyApp({Key? key}) : super(key: key);

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home:MainPage(),
    );
  }

  /*
  ----------- State Methods -----------
  */

  // notification test
  Future<void> scheduleNotification(BuildContext context, int id, String title, String body, DateTime scheduledTime) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'your channel id', 'your channel name',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('your_sound'),
        ticker: 'ticker');
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics);

    var location = tz.getLocation(Localizations.localeOf(context).toString());
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        TZDateTime.from(scheduledTime, location),
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        matchDateTimeComponents: DateTimeComponents.time);
  }
}

