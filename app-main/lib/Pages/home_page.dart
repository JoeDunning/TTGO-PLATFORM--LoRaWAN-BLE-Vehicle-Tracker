/*
Homepage
- class HomePage extends StatefulWidget
- class _HomePageState extends State<HomePage>
    // Build Widget Section
    Widget build(BuildContext context)

    // State Handling
    void initState()        // Called upon during state initialization

    // MQTT Methods
    Future<void> initMQTT() async   // Function for initialising MQTT connection
    Future<void> initLoc()          // Function for initialising MQTT connection
    void _processPM                 // Function for processing MQTT responses
    void setupUpdatesListener()     // Function for handling and initialising a message stream for incoming MQTT messages

    // Utility Methods
    void handleInitialLocation()    // Function for calling and ensuring latest location has been initialised before map state
*/

// Import Dart Libraries
import 'dart:async';
import 'dart:convert';

// Import Flutter & Firebase libraries
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';


// Import App Classes
import '../Service Handlers/ble_handler.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'google_maps.dart';
import 'history.dart';
import 'package:RideSafe/Service%20Handlers/mqtt_sysrun.dart';

/*
----------- Definitions & Variables -----------
*/

double savedLat = 0.0; // Current Vehicle Latitude
double savedLng = 0.0; // Current Vehicle Longitude
String emergencyRecipients = "07496267128"; // Storage for emergency contact
MQTTClientManager mqttClientManager = MQTTClientManager(); // MQTT manager definition

/*
----------- Code Section Start -----------
*/


// HomePage State Definition
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  final History _history = const History();

  @override
  State<HomePage> createState() => _HomePageState();
}

// Class HomePageState Definition
class _HomePageState extends State<HomePage>{

  int currentIndex = 0; // Variable to keep track of the current tab that is selected

  final screens = [
    const HomeMaps(),
    const History(),
    const ProfilePage(),
    const SettingsPage()
  ]; // Available screens aka 'views'

  final user = FirebaseAuth.instance.currentUser!; // Variable for current user

  // TTN MQTT Topics
  static const String _topicLocation = "v3/ttgo-tbeam-tracker-proj@ttn/devices/eui-70b3d57ed0059dc6/up"; //MQTT topic exposed by traffic

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        backgroundColor:Colors.deepPurple,
        leading: IconButton(
          onPressed: (){}, // Callback function for when the icon is pressed
          icon: const Icon(Icons.phone_android),
        ),
        title: Center(
          child: Text(user.email!, // Displaying the current user's email
            style : const TextStyle(fontSize:18),
          ),
        ),

        actions: [

          // Logout button
          GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Confirm Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: <Widget>[
                        TextButton(
                          child: const Text("Confirm"),
                          onPressed: () {
                            FirebaseAuth.instance.signOut(); // sign out the current user
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text("Cancel"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.0),
                child: Icon(Icons.logout),
              ))],
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Color(0xD3CA9EFF)),
        child: Scrollbar(
          child:
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  screens[currentIndex],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.deepPurple,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,

        currentIndex: currentIndex,
        onTap: (index)=> setState(()=> currentIndex = index),
        items: const [
          // Home Navbar Item
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),

          // History Navbar Item
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),

          // Profile Navbar Item
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),

          // Settings Navbar Item
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  /*
  ----------- State Handling -----------
  */

  // Called upon state initialization
  @override
  void initState() {
    initMQTT();
    setupUpdatesListener();
    initLoc();
    super.initState();
  }

  // Called during disposing of state
  @override
  void dispose() {
    super.dispose();
  }

  /*
  ----------- MQTT Methods -----------
  */

  // Function for initialising MQTT connection
  Future<void> initMQTT() async {
    await mqttClientManager.connect();
    mqttClientManager.subscribe(_topicLocation);
  }

  // Function for initialising location handlers and setup
  Future<void> initLoc() async {
    setState(() async {
      await History.readArmStatus();
      appStatusInt = readStatus;
      debugPrint(readStatus.toString());
      debugPrint(appStatusInt.toString());

      await History.readArmPosition();
      armCircleCenter = armPosition;

      await widget._history.readGeoFenceRange();

      await widget._history.getLatestLocation();
      carPosition = LatLng(savedLat, savedLng);
    });



  }

  // Function for processing MQTT responses
  void _processPM(String payloadMessage) {
    String jsonConv = payloadMessage;

    Map<String, dynamic> map = jsonDecode(jsonConv);
    Map<String, dynamic> latestLat = map['location']['latitude'];
    Map<String, dynamic> latestLng = map['location']['longitude'];

    debugPrint(latestLat as String?);
    debugPrint(latestLng as String?);

    History.saveCarPosition(LatLng(double.parse(latestLat as String), double.parse(latestLng as String)), true);
  }

  // Function for handling and initialising a message stream for incoming MQTT messages
  void setupUpdatesListener() {
    mqttClientManager
        .getMessagesStream()!
        .listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final receivedMessage = c![0].payload as MqttPublishMessage;
      final payloadMessage = MqttPublishPayload.bytesToStringAsString(receivedMessage.payload.message);

      debugPrint('MQTTUpdatesListener: $payloadMessage\nResponse Processing');
      _processPM(payloadMessage);
    });
  }
}