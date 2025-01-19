/*

MQTT_SysRun - MQTT Handler

- class MQTTClientManager

    // MQTT Methods

    // Connection Handlers
    Future<int> connect() async   // Function for MQTT Connection - Takes variables for callbacks and connection config
    void disconnect()   // Function for disconnecting MQTT client from server
    void onConnected()    // Function for MQTT connected state handling/notification
    void onDisconnected()    // Function for MQTT connected state handling/notification

    // Subscription/Message Handlers
    void onSubscribed(String topic)   // Function for MQTT onSubscribed state handling/notification
    void subscribe(String topic)   // Function for subscribing to MQTT topic
    Stream<List<MqttReceivedMessage<MqttMessage>>>? getMessagesStream()   // Stream List for receiving MQTT messages, kept active until disconnected/disposed

*/

// Import Dart Libraries
import 'dart:io';

// Import Flutter & mqtt_client packages
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/*
----------- Code Section Start -----------
*/

// Class for handling MQTT states
class MQTTClientManager {

  /*
  ----------- Definitions & Variables -----------
  */

  // MQTT Client
  MqttServerClient client = MqttServerClient.withPort('eu1.cloud.thethings.network', 'test_device', 1883);

  static const String _username = "ttgo-tbeam-tracker-proj@ttn"; // MQTT Info
  static const String _topicpass = "NNSXS.QOOFXWNJSKCYZTDNR7KNOR4Q7TMCMWQQSC4VRXI.4JJWIECT763UJTZZNFE7OZJ6ADEIH22JHQIU52Y2SRTRHG52A6CQ"; // MQTT API Key

  /*
  ----------- MQTT Methods-----------
  */

  // -- Connection Handlers --

  // Function for MQTT Connection - Takes variables for callbacks and connection config
  Future<int> connect() async {
    client.logging(on: true);
    client.keepAlivePeriod = 1000;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;

    // Var for storing connection message
    final connMessage = MqttConnectMessage().startClean().withWillQos(MqttQos.atLeastOnce).authenticateAs(_username, _topicpass);

    // Connect with stored credentials/config
    client.connectionMessage = connMessage;

    // Try connection handler, receives exception states
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint('MQTTClient: Client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      debugPrint('MQTTClient: Socket exception - $e');
      client.disconnect();
    }
    return 0;
  }

  // Function for disconnecting MQTT client from server
  void disconnect(){
    client.disconnect();
  }

  // Function for MQTT connected state handling/notification
  void onConnected() {
    debugPrint('MQTTClient: Connected to Server!');
  }

  // Function for MQTT connected state handling/notification
  void onDisconnected() {
    debugPrint('MQTTClient: Disconnected! Re-connecting..');
    connect();
  }

  // -- Subscription/Message Handlers --

  // Function for MQTT onSubscribed state handling/notification
  void onSubscribed(String topic) {
    debugPrint('MQTTClient: Subscribed to topic: $topic');
  }

  // Function for subscribing to MQTT topic
  void subscribe(String topic) {
    client.subscribe(topic, MqttQos.atLeastOnce);
  }

  // Stream List for receiving MQTT messages, kept active until disconnected/disposed
  Stream<List<MqttReceivedMessage<MqttMessage>>>? getMessagesStream() {
    return client.updates;
  }
}
