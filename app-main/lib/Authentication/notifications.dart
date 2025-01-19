/*

Notifications - Notification Method Store

Future<void> connectionCancelNotification(context) async   // Notification for when current BLE scan is cancelled
Future<AlertDialog> unknownErrorNotification() async       // Notification for when unknown error occurs
Future<AlertDialog> bleDisconnectedError() async           // Notification for when BLE disconnection occurs
Future<AlertDialog> disableAlarmNotification() async       // Notification for alarm status
Future<AlertDialog> deviceDisconnectedNotification()       // Notification for device disconnection

*/

// Import Flutter Packages
import 'package:flutter/material.dart';

/*
----------- Code Section Start -----------
*/

// Notification for when current BLE scan is cancelled
Future<void> connectionCancelNotification(context) async {
  debugPrint('connectionCancelNotification: Notification Called - Cancel Scan');
  await showDialog(
    context: context,
    builder: (BuildContext context) => const AlertDialog(
      actionsAlignment: MainAxisAlignment.center,
      title: Text('Cancelled Current Scan',),
    ),
  );
}

// Notification for when unknown error occurs
Future<AlertDialog> unknownErrorNotification() async {
  debugPrint('unknownErrorNotification: Notification Called - Unknown Error');
  return const AlertDialog(
    actionsAlignment: MainAxisAlignment.center,
    title: Text('Unknown Error'),
  );
}

// Notification for when BLE disconnection occurs
Future<AlertDialog> bleDisconnectedError() async {
  debugPrint('bleDisconnectedError: Notification Called');
  return const AlertDialog(
    actionsAlignment: MainAxisAlignment.center,
    title: Text('Error! BLE Disconnected!'),
    content: Text('Your device is currently disconnected, connect to your device to use speed alerts.'),
  );
}

// Notification for alarm status
Future<AlertDialog> disableAlarmNotification() async {
  debugPrint('disableAlarmNotification: Notification Called');
  return const AlertDialog(
    actionsAlignment: MainAxisAlignment.center,
    title: Text('Alarm Disabled'),
    content: Text('Your alarm is now disabled, you will only receive text notifications'),
  );
}


// Notification for device disconnection
Future<AlertDialog> deviceDisconnectedNotification() async {
  debugPrint('Notification Called');
  return const AlertDialog(
    actionsAlignment: MainAxisAlignment.center,
    title: Text('Disconnected From Device'),
    content: Text('Your device is now disconnected.'),
  );
}

