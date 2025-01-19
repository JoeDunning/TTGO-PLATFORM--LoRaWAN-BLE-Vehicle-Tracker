/*
Google Maps
- class HomeMaps extends StatefulWidget
- class HomeMapsState extends State<HomeMaps>
    // State Handling
    void initState() - Called upon during state initialization
    void disposeState() - Called upon during disposing of state
    // Build Widget Section
    Widget build(BuildContext context)

    // Google Maps Method Area & Logic
    void getPolyPoints() async - Gets location of current polypoints
    void updateCircle() - Updates location circle

    // BLE Methods
    Future<void> bleConnect() async - Method for handling BLE connections
    Future<AlertDialog> bleDisconnect() async - Method for handling BLE disconnect requests
    void bleReadWrite() - Method for handling BLE data writes for arming and disarming the device
    Future<void> handleBluetoothConnection() async - Defines a function to handle Bluetooth connection/disconnection
    void listenToCharacteristic() - Defines a function for listening to GPS characteristic info
    void processResponse(String utfValue) - Method for handling incoming BLE responses

    // Location Methods
    void getCurrentLocationInfo() - Geocoding Location Method - Generates location inf lat/lng positions
    void getCurrentLocation() async - Method for getting phone location - User location, not device/tracker location
    void shareLocation() - Share current device location method

    // Utility Methods
    Future<void> getTTNInfo() async - HTTP GET Function for requesting latest solved (confirmed over LoRa uplink) location info
    Future<void> handleSpeedAlerts() async - Defines a function to handle speed alert callback
    void handleSwitchChange(bool newValue) -
    void speedAlertCheck(bool speedAlerts) - Method for checking status of speed alerts
    Future<String> searchValGen() async - Future method for generating recurring searching string eclipses
    added initNotifications and showAlarmNotification where the sounds and notification buttons display
*/

// Import Dart Libraries
import 'dart:io';
import 'dart:math';

// Import Flutter Libraries
import 'package:RideSafe/Service%20Handlers/ble_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import 'package:flutter_share/flutter_share.dart';

import 'package:geocoding/geocoding.dart' as geo_code;
import 'package:geolocator/geolocator.dart' as geo_location;
import 'package:http/http.dart' as http_client;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import App Classes
import 'home_page.dart';
import 'history.dart';
import 'package:RideSafe/Authentication/notifications.dart';

// Import Utility Libraries
import 'dart:async';
import 'dart:convert' show json, jsonDecode, utf8;

/*
----------- Definitions & Variables -----------
*/

// System Vars

// ---- BLE & App Status Definitions ----


Map<dynamic, dynamic> geocodeOutput = {}; // Geocoding Map output - defined as to be prepped for init
LatLng carPosition = LatLng(savedLat, savedLng);
bool speedAlerts = false;

bool movementDetected = false;
// Add a boolean flag to control whether the circle should be updated
bool updateCircleStatus = false;
// ---- Address, Searching & Geocoding Variables ----

String macAddress = "xx"; // Default MAC Address for prototype
String searchingVal = "State - Searching"; // Default search string
String currentProximity = "0";
String currentSpeedLimit = "";

bool alarmEnable = true;
bool timerStatus = false;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();



// ---- Location Vars ----

LatLng armCircleCenter = armPosition;


// ---- TTN Location Vars ---- ??/*/**/*/
double _userLat = 51.284617; // Current TTN Latitude- Parsed via HTTP get & MQTT
double _userLng = 1.071463; // Current TTN Longitude- Parsed via HTTP get & MQTT

/*
----------- Code Section Start -----------
*/


// Home Maps State Definition
class HomeMaps extends StatefulWidget {
  const HomeMaps({super.key});
  final History _history = const History();


  @override
  HomeMapsState createState() => HomeMapsState();

  // Share current user location method
  void shareLocation() async {
    final street = geocodeOutput['Street'];
    final county = geocodeOutput['Subadministrative area'];

    // Create a message with the user's location
    String message = 'I have traveled with RideSafe to $street, $county today.';
    String title = 'Travel Update';

    // Share the message
    await FlutterShare.share(title: title, text: message);
  }

  //  code defines a function locationHandler that takes a location and a location type as input, and depending on the location type,
  //  either saves the car position or updates the car position and saves it to the device and TTN, while discarding invalid locations
  static Future<void> locationHandler(LatLng location, int locType) async {
    switch(locType) {
      case 0:
        debugPrint("Reserved for Debug - Error!");
        break;
      case 1:
        debugPrint("----------------------------------------------");
        debugPrint("locationHandler HTTP - Adding if not present.");
        debugPrint("---------------------------------------------");
        if (location == const LatLng(0.0 ,0.0)) {
          debugPrint("locationHandler HTTP Error: Invalid Location, Discarding.");
          break;
        }
        History.saveCarPosition(location, false);
        break;
      case 2:
        debugPrint("------------------------------------------------------------");
        debugPrint("locationHandler BLE - Adding to device & TTN if not present.");
        debugPrint("------------------------------------------------------------");
        if (location == const LatLng(0.0, 0.0) || location.toString() == "") {
          debugPrint("locationHandler BLE Error: Invalid Location, Discarding.");
          break;
        }
        LatLng updatedPos = LatLng(location.latitude, location.longitude);
        carPosition = (LatLng(updatedPos.latitude, updatedPos.longitude));

        savedLat = location.latitude;
        savedLng = location.longitude;

        History.saveCarPosition(location, true); // add if return true then
        HomeMapsState.saveTTNLoc(location);

        break;
      default:
        debugPrint("locationHandler: Unknown Location Type, Discarding");
        break;
    }
  }
}

// Home Maps Class Definition
class HomeMapsState extends State<HomeMaps> {
  final BLESystemState _bleSystem = BLESystemState();
  /*
  ----------- State Handling -----------
  */

  // Called upon state initialization
  @override
  void initState() {

    getCurrentUserLocation();
    getTTNInfo();

    super.initState();

    _timer = null;

    getPolyPoints();
    getCurrentLocationInfo(LatLng(savedLat, savedLng));
    initNotifications();
  }

  // Called during disposing of state
  @override
  void dispose() {
    _pageController.dispose();

    super.dispose();
  }

  /*
  ----------- Google Maps Logic & Code -----------
  */

  bool switchValue = false; // default value for switch
  Timer? _timer; // declare the timer variable as nullable

  double circleRadius = 5;
  bool showCircle = false;

  final PageController _pageController = PageController(initialPage: 0);
  late GoogleMapController _controller; // Flagged as not used due to late and conditional

  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;

  // Define the _circleColor variable as a state variable
  Color _circleColor = Colors.blue.withOpacity(0.3);

  double getDistanceBetween(double lat1, double lon1, double lat2, double lon2,
      ) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.8,
      child: Scaffold(
        body: currentLocation == null ? const Center(child: Text("Loading..")) :
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
              zoom: 16.5),
          mapType: MapType.normal,
          polylines: switchValue ? {Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            color: Colors.deepPurple,
            width: 5,
          ),} : {},
          markers: {
            Marker(
              markerId: const MarkerId("car"),
              position: carPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ),
            Marker(
              markerId: const MarkerId("currentLocation"),
              position: LatLng(currentLocation!.latitude!,
                  currentLocation!.longitude!),
            ),
          },
          circles: {
            if (showCircle)
              Circle(
                circleId: const CircleId("car_radius"),
                center: armCircleCenter,
                radius: circleRadius,
                // radius in meters
                fillColor: _circleColor,
                strokeColor: Colors.blue,
                strokeWidth: 2,
              ),
          },
          // Initialize the GoogleMap controller
          onMapCreated: (controller) {
            _controller = controller;
          },
        ),

        // Bottom navigation bar to contain the arm/disarm button
        bottomNavigationBar: Container(
          height: MediaQuery.of(context).size.height * 0.25,
          width: MediaQuery.of(context).size.width,
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
          child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Container(
                        height: MediaQuery.of(context).size.height * 0.3,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          color: const Color(0xD3CA9EFF),
                          border: Border.all(
                            width: 3,
                            color: const Color(0x565664FF),
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                        ),

                        child: RawScrollbar(
                          controller: _pageController,

                          thumbVisibility: true,
                          thumbColor: const Color(0x565664FF),
                          thickness: 18.0,
                          scrollbarOrientation: ScrollbarOrientation.top,
                          radius: const Radius.circular(4.0),

                          child: PageView(
                            controller: _pageController,
                            scrollDirection: Axis.horizontal,
                            children: [

                              // Location Settings Panel
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[

                                    const Divider(height: 20),

                                    const Divider(height: 1, thickness: 3, color: Color(0x565664FF)),

                                    Container(
                                      alignment: Alignment.center,
                                      height: 50,
                                      width: MediaQuery.of(context).size.width,
                                      decoration: const BoxDecoration(
                                        color: Colors.deepPurple,
                                      ),
                                      child: const Text('Device Overview', style: TextStyle(fontSize: 30, color: Colors.white)),
                                    ),

                                    const Divider(height: 1, thickness: 3, color: Color(0x565664FF)),

                                    const Divider(height: 5),

                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[

                                        // Current Location Overview
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[

                                              Card(
                                                margin: const EdgeInsets.only(right: 10.0, left: 10.0, top: 15.0, bottom: 4.0),
                                                color: Colors.white60,
                                                child: Column(
                                                  children: <Widget>[
                                                    const Divider(height: 2),

                                                    const Card(
                                                      color: Colors.deepPurple,
                                                      child: Padding(
                                                        padding: EdgeInsets.all(5.0),
                                                        child: Text('Current Location',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                                        ),
                                                      ),
                                                    ), // Current
                                                    // Location

                                                    // Street Name
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: <Widget>[
                                                        Text('  Street: ${geocodeOutput['Street'] ?? ''}',
                                                          textAlign: TextAlign.start,
                                                          style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),

                                                    const Divider(height: 1),

                                                    // Post Code
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: <Widget>[
                                                        Text('  Post Code: ${geocodeOutput['Postal Code'] ?? ''}',
                                                          textAlign: TextAlign.start,
                                                          style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),

                                                    const Divider(height: 1),

                                                    // County
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: <Widget>[
                                                        Text('  District: ${geocodeOutput['Subadministrative area'] ?? ''}',
                                                          textAlign: TextAlign.start,
                                                          style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),

                                                    const Divider(height: 1),

                                                    // Country
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      children: <Widget>[
                                                        Text('  Country: ${geocodeOutput['Country'] ?? ''}',
                                                          textAlign: TextAlign.start,
                                                          style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),

                                                    const Divider(height: 5),

                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Set Geofencing Button
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            children: <Widget>[
                                              const Divider(
                                                height: 5,
                                              ),

                                              ElevatedButton(
                                                onPressed: () {

                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text('Set Geofence Radius', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                                                        content: StatefulBuilder(
                                                          builder: (BuildContext context, StateSetter setState) {
                                                            return Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: <Widget>[
                                                                const Text('Select radius in meters'),
                                                                const SizedBox(height: 16),
                                                                Slider(
                                                                  value: circleRadius,
                                                                  min: 2,
                                                                  max: 20,
                                                                  divisions: 9,
                                                                  label: circleRadius.round().toString(),
                                                                  onChanged: (double value) {
                                                                    setState(() {
                                                                      widget._history.saveGeoFenceRange(value);
                                                                      circleRadius = value;
                                                                    });
                                                                  },
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ),
                                                        actions: <Widget>[
                                                          TextButton(
                                                            child: const Text('Cancel'),
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                          TextButton(
                                                            child: const Text('OK'),
                                                            onPressed: () {
                                                              setState(() {
                                                                // Set the circle radius to the selected value
                                                                circleRadius = circleRadius;
                                                              });
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );



                                                  debugPrint(readStatus.toString());
                                                },

                                                style: ButtonStyle(
                                                  shape: MaterialStateProperty.all(const CircleBorder()),
                                                  padding:
                                                  MaterialStateProperty.all(const EdgeInsets.all(20)),

                                                  // Button Colour
                                                  backgroundColor:
                                                  MaterialStateProperty.all(Colors.green),

                                                  // Splash
                                                  overlayColor:
                                                  MaterialStateProperty
                                                      .resolveWith<Color?>(
                                                          (states) {
                                                        if (states.contains(
                                                            MaterialState.pressed)) {
                                                          return Colors.redAccent;
                                                        }
                                                        return null;
                                                      }),
                                                ),
                                                child: const Icon(Icons.travel_explore_sharp),),

                                              const Divider(height: 10),

                                              const Text('Set Geofencing', style: TextStyle(fontWeight: FontWeight.w700)),

                                              const Divider(height: 18, thickness: 2, color: Colors.black),

                                              const Text('Proximity: ', style: TextStyle(fontSize: 20),),
                                            ],
                                          ),
                                        ),

                                        // Trip Details Button
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            children: <Widget>[
                                              const Divider(
                                                height: 5,
                                              ),

                                              ElevatedButton(
                                                  onPressed: () {

                                                  },

                                                  style: ButtonStyle(
                                                    shape: MaterialStateProperty.all(const CircleBorder()),
                                                    padding:
                                                    MaterialStateProperty.all(const EdgeInsets.all(20)),

                                                    // Button Colour
                                                    backgroundColor:
                                                    MaterialStateProperty.all(Colors.deepPurpleAccent),

                                                    // Splash
                                                    overlayColor:
                                                    MaterialStateProperty
                                                        .resolveWith<Color?>(
                                                            (states) {
                                                          if (states.contains(
                                                              MaterialState.pressed)) {
                                                            return Colors.green;
                                                          }
                                                          return null;
                                                        }),
                                                  ),

                                                  child: const Icon(Icons.battery_unknown)),

                                              const Divider(height: 10),

                                              const Text('Power Check', style: TextStyle(fontWeight: FontWeight.w700)),

                                              const Divider(height: 18, thickness: 2, color: Colors.black),

                                              Text(currentProximity, style: const TextStyle(fontSize: 20)),
                                            ],
                                          ),
                                        ),

                                      ],
                                    ),
                                  ]),

                              // BLE Settings Panel
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[

                                    // BLE Submenu
                                    const Divider(height: 20),

                                    const Divider(height: 1, thickness: 3, color: Color(0x565664FF)),

                                    Container(
                                      alignment: Alignment.center,
                                      height: 50,
                                      width: MediaQuery.of(context).size.width,
                                      decoration: const BoxDecoration(
                                        color: Colors.deepPurple,
                                      ),
                                      child: const Text(
                                        'BLE Settings',
                                        style: TextStyle(fontSize: 30, color: Colors.white),
                                      ),
                                    ),

                                    const Divider(height: 1, thickness: 3, color: Color(0x565664FF)),

                                    const Divider(height: 12),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              ElevatedButton(
                                                onPressed: () {
                                                  _bleSystem.handleBluetoothConnection();
                                                },
                                                style: ButtonStyle(
                                                  shape: MaterialStateProperty.all(
                                                      const CircleBorder()),
                                                  padding:
                                                  MaterialStateProperty.all(
                                                      const EdgeInsets.all(20)),
                                                  backgroundColor:
                                                  MaterialStateProperty.all(
                                                      bleConnecting
                                                          ? Colors.blue
                                                          : (bleConnected
                                                          ? Colors.green
                                                          : Colors.red)),
                                                  overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                                    if (states.contains(
                                                        MaterialState.pressed)) {
                                                      return Colors.green;
                                                    }
                                                    return null; // <-- Splash color
                                                  }),
                                                ),
                                                child: Icon(bleConnecting ? Icons.bluetooth_searching : (bleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled)),
                                              ),

                                              const Divider(height: 8),

                                              const Text('BLE Toggle', style: TextStyle(fontWeight: FontWeight.w700)),

                                              const Divider(height: 18, thickness: 2, color: Colors.black),

                                              Text(bleConnecting
                                                  ? searchingVal
                                                  : (bleConnected
                                                  ? 'State - Connected'
                                                  : 'State - Disconnected')),
                                            ],
                                          ),
                                        ), // BLE Toggle Button

                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              ElevatedButton(
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder:
                                                          (BuildContext context) {
                                                        return AlertDialog(
                                                          title: Text(appStatusInt.isOdd
                                                              ? 'Disarm your device?'
                                                              : 'Arm your device?'),
                                                          content: const Text(
                                                              'Are you sure you want to arm your device?\n\nIf your device leaves the set geofencing range, it will enter recovery mode.'),
                                                          actions: <Widget>[
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.of(context)
                                                                    .pop();
                                                              },
                                                              child: const Text('CANCEL'),
                                                            ),
                                                            TextButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  BLESystemState.bleReadWrite();
                                                                });
                                                                Navigator.of(context).pop();
                                                              },
                                                              child: Text(appStatusInt.isEven ? 'ARM' : 'DISARM'),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  },
                                                  style: ButtonStyle(
                                                    shape: MaterialStateProperty.all(const CircleBorder()),
                                                    padding: MaterialStateProperty.all(const EdgeInsets.all(20)),
                                                    backgroundColor: MaterialStateProperty.all(bleConnected
                                                        ? (appStatusInt.isOdd
                                                        ? Colors.green
                                                        : Colors.red)
                                                        : (appStatusInt.isOdd
                                                        ? Colors.green
                                                        : Colors
                                                        .grey)), // <-- Button color
                                                    overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                                      if (states.contains(
                                                          MaterialState.pressed)) {
                                                        return Colors.green;
                                                      }
                                                      return null; // <-- Splash color
                                                    }),
                                                  ),
                                                  child: const Icon(Icons.lock_outline_sharp)),

                                              const Divider(height: 8),

                                              Text(appStatusInt.isEven
                                                  ? 'Arm Device'
                                                  : (bleConnected
                                                  ? 'Disarm Device'
                                                  : 'Remote Monitoring'), style: const TextStyle(fontWeight: FontWeight.w700),),

                                              const Divider(height: 18, thickness: 2, color: Colors.black),

                                              Text(appStatusInt.isOdd ? 'State - Armed' : 'State - Disarmed'),
                                            ],
                                          ),
                                        ), // BLE Arm Button

                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    handleAlarmAlerts();
                                                  });
                                                },
                                                style: ButtonStyle(
                                                  shape: MaterialStateProperty.all(
                                                      const CircleBorder()),
                                                  padding:
                                                  MaterialStateProperty.all(
                                                      const EdgeInsets.all(20)),
                                                  backgroundColor:
                                                  MaterialStateProperty.all(alarmEnable ? Colors.green : Colors.red), // <-- Button color
                                                  overlayColor:
                                                  MaterialStateProperty
                                                      .resolveWith<Color?>(
                                                          (states) {
                                                        if (states.contains(
                                                            MaterialState.pressed)) {
                                                          return Colors.green;
                                                        }
                                                        return null; // <-- Splash color
                                                      }),
                                                ),
                                                child: const Icon(Icons.alarm_on_sharp),
                                              ),

                                              const Divider(height: 8),

                                              const Text('Set Alarm Status', style: TextStyle(fontWeight: FontWeight.w700)),

                                              const Divider(height: 18, thickness: 2, color: Colors.black),

                                              Text(alarmEnable ? 'State - Enabled' : 'State - Disabled'),
                                            ],
                                          ),
                                        ), // Speed Alerts Toggle Button

                                      ],
                                    ),
                                  ]),
                            ],
                          ),
                        ),
                      ),
                    ]),
              ]),
        ),
      ),
    );
  }

  /*
  ----------- Google Maps Method Area -----------
  */

  // Function to generate polyline points between positions  and updates the UI with the new polyline coordinates.
  void getPolyPoints() async {
    // Create a new instance of the PolylinePoints class
    PolylinePoints polylinePoints = PolylinePoints();
    // Use the getRouteBetweenCoordinates method to get the polyline coordinates between the current location and the car position
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
      PointLatLng(currentLocation?.latitude ?? 0.0, currentLocation?.longitude ?? 0.0),
      PointLatLng(carPosition.latitude, carPosition.longitude),
    );
    // Check if the result has any points
    if (result.points.isNotEmpty) {
      // Iterate through each point in the result and add it to the polylineCoordinates list
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
      // Update the UI with the new polyline coordinates
      setState(() {});
    }
  }

  // Initializes the local notifications plugin with default settings
  Future<void> initNotifications() async {
    // Set the Android-specific initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Create the initialization settings for the plugin
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    // Initialize the local notifications plugin
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Shows an alarm notification when called
  Future<void> showAlarmNotification() async {
    // Define Android-specific notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'alarm_notification_channel_id',
      'Alarm Notifications',
      channelDescription: 'Alarm notifications for the app',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
    );

    // Create the notification details
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show the notification
    await flutterLocalNotificationsPlugin.show(
      0,
      'Device left the circle',
      'The device has left the geofencing circle.',
      platformChannelSpecifics,
    );
  }

  // Function for triggering a breach of geofencing based on the distance between arm & current positions
  void updateCircle() {
    // Check if the circle should be displayed and updated
    debugPrint("--------------------");
    debugPrint("updateCircle: Fired");
    debugPrint("--------------------");

    if (showCircle && updateCircleStatus) {
      // Calculate the distance between the car position and the current location
      debugPrint("updateCircle: Distance Check Fired");
      debugPrint("--------------------");
      final distance = geo_location.Geolocator.distanceBetween(
          carPosition.latitude,
          carPosition.longitude,

          armCircleCenter.latitude,
          armCircleCenter.longitude
      );
      debugPrint("Distance: $distance");
      debugPrint("--------------------\n");
      // Update the circle color based on the distance from the car position
      setState(() {
        // If the distance is within the circle radius, set the color to blue
        debugPrint(distance.toString());
        if (distance <= circleRadius) {
          _circleColor = Colors.blue.withOpacity(0.3);
        } else {
          debugPrint("updateCircle: ALARM TRIGGERED");
          // If the distance is outside the circle radius, set the color to red
          _circleColor = Colors.red.withOpacity(0.3);

          // Show the alarm notification when the device leaves the circle
          showAlarmNotification();
        }
      });
    }
  }

  /*
  ----------- Location Methods -----------
  */

  //
  void calculateProximity() async {
    debugPrint("-------------------------");
    debugPrint("calculateProximity: Fired");
    debugPrint("-------------------------");

    await widget._history.getLatestLocation();

    getCurrentLocationInfo(LatLng(savedLat, savedLng));

    if (readStatus == 1) {
      handleArmTimers(true);
    }

    if (savedLat != 0.0) {
      final proximityCalc = geo_location.Geolocator.distanceBetween(
          savedLat, savedLng, _userLat, _userLng);
      final mCalc = proximityCalc.toStringAsFixed(1);

      currentProximity =
      '${mCalc}m'; // Assignment of current proximity as string
    } else if (savedLat == 0.0 && savedLng == 0.0) {
      debugPrint("calculateProximity: Error! Invalid Location!");
      return;
    }
  }

  // Geocoding Location Method - Generates location info from lat/lng positions
  void getCurrentLocationInfo(LatLng location) {
    if (!mounted || location.latitude == 0.0) {
      debugPrint("getCurrentLocationInfo: Error! Invalid Location!");
      return;
    }
    geo_code.placemarkFromCoordinates(location.latitude, location.longitude).then((placemarks) {
      setState(() {
        geocodeOutput = {};
        if (placemarks.isNotEmpty) {
          final placemark = placemarks[0];
          geocodeOutput['Street'] = placemark.street;
          geocodeOutput['Postal Code'] = placemark.postalCode;
          geocodeOutput['Subadministrative area'] = placemark.subAdministrativeArea;
          geocodeOutput['Country'] = placemark.country;
        } else {
          geocodeOutput['Error'] = 'No Results Found!';
        }
      });
    });
  }

  // Method for getting phone location - User location, not device/tracker location
  void getCurrentUserLocation() async {
    // create a new instance of the Location class
    Location location = Location();
    // get the current location data
    LocationData locationData = await location.getLocation();
    // update the currentLocation variable with the location data and re-render the widget
    currentLocation = locationData;

    // listen for changes in location and update the currentLocation variable and re-render the widget
    location.onLocationChanged.listen((newLocation) {
      currentLocation = newLocation;
      if (mounted) {
        setState(() {

          final lat = currentLocation?.latitude ?? 0.0;
          final lng = currentLocation?.longitude?? 0.0;
          _userLat = double.parse(lat.toStringAsFixed(6));
          _userLng = double.parse(lng.toStringAsFixed(6));

          calculateProximity();
        });
      }
    });
    // this makes sure the users location is initialized before calling the getPolyPoints method
    // so that you can get their polyline distance
    if (currentLocation != null) {
      getPolyPoints();
    }
  }

  /*
  ----------- Utility Methods -----------
  */

  // HTTP GET Function for requesting latest solved (confirmed over LoRa uplink) location info
  static Future<void> getTTNInfo() async {
    final deviceLocationResponse = await http_client.get(
      Uri.parse('https://eu1.cloud.thethings.network/api/v3/applications/XX'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer NNSXS.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    if (deviceLocationResponse.statusCode == 200) {
      debugPrint("---------------------------------------");
      debugPrint("getTTNInfo: Successful HTTP Get Request");
      debugPrint("---------------------------------------\n");

      final decodedResponse = jsonDecode(utf8.decode(deviceLocationResponse.bodyBytes)); // Decode to string
      debugPrint(json.encode(decodedResponse));
      debugPrint(decodedResponse['locations'].toString());

      final locations = decodedResponse['locations']; // Grabs locations from JSON
      final latitude = double.parse(locations['solved']['latitude'].toString()); // Grabs latitude as 6 digit String
      final longitude = double.parse(locations['solved']['longitude'].toString()); // Grabs longitude as 6 digit String


      HomeMaps.locationHandler(LatLng(latitude, longitude), 1); // Call for HTTP location handling
    } else {
      final status = deviceLocationResponse.statusCode;
      debugPrint("getTTNInfo: Request Failed, Status: $status");
    }
  }

  // HTTP Put Function - Provides latest BLE location back to TTN
  static void saveTTNLoc(LatLng location) async{
    final bleLocationInfo = {
      "end_device": {
        "ids": {
          "device_id": "eui-70b3d57ed0059dc6",
          "application_ids": {
            "application_id": "ttgo-tbeam-tracker-proj"
          },
          "dev_eui": "70B3D57ED0059DC6",
          "dev_addr": "260B88C6"
        },
        "locations": {
          "solved": {
              "latitude": location.latitude,
              "longitude": location.longitude,
              "altitude": 2,//altitude,
              "accuracy": 1,
              "source": "SOURCE_GPS",
          }
        },

        "service_profile_id": "ttnmapper"
      },
      "field_mask": {
        "paths": ["locations"]
      }
    };

    final post = await http_client.put(
      Uri.parse('https://eu1.cloud.thethings.network/api/v3/applications/XX'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer NNSXS.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        HttpHeaders.contentTypeHeader: 'application/json'
      },
      body: json.encode(bleLocationInfo),
    );
    debugPrint(json.encode(bleLocationInfo));

    if (post.statusCode == 200) {

      debugPrint("saveTTNLoc: PUT Successful - BLE Location Uploaded to TTN");
    } else {
      final status = post.statusCode;
      debugPrint(post.body);
      debugPrint("saveTTNLoc: Error! PUT Failed, Status: $status");
    }
  }

  // Defines a function to handle speed alert callback
  Future<void> handleAlarmAlerts() async {
    if (alarmEnable != true) {
      debugPrint("handleAlarmAlerts: Enabling Alarm");
      alarmEnable = true;
    } else {
      alarmEnable = false;
      debugPrint("handleAlarmAlerts: Disabling Alarm");
      await disableAlarmNotification();
      return;
    }
  }

  // Function for handling polyline drawing
  void handleArmTimers (bool newValue) async {
    setState(() {
      switchValue = newValue;
      if (switchValue) {
        if (readStatus == 0) {
          debugPrint("handleArmTimers: Invalid Call, Re-parsing..");
          return;
        }
        debugPrint("handleArmTimers: ARMED");
        // Update circle radius if appStatus == 1 and bleConnected
        if (readStatus == 1) {

          circleRadius = geoRange; // Set the geofence range here
          updateCircleStatus = true; //note joe might need to swap here???

        }
        else{
          updateCircleStatus = false;

        }

        updateCircle(); // Call updateCircle method to set circle color initially

        // Start a timer to save the car's position every 30 seconds
        _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
          History.saveCarPosition(carPosition, false);
          History.saveArmStatus(appStatusInt);
          widget._history.readJsonFile();
        });

        _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
          getTTNInfo();
        });

        // Show the circle
        showCircle = true;
      } else {
        debugPrint("handleArmTimers: DISARMED");
        // Cancel the timer when the switch is turned off
        _timer?.cancel();
        _timer = null;

        // Display a notification using a SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("handleArmTimers: Car position saved"),
          ),
        );

        // Hide the circle
        showCircle = false;
      }
    });

    // dami
    // checks if the device is connected via Bluetooth and in an "armed" state, or just in an "armed" state,
    // and then updates the switchValue based on the newValue

    if (bleConnected && appStatusInt == 1 || appStatusInt == 1) {
      setState(() {
        switchValue = newValue;
      });
      // update the arming status based on the switch value
      if (switchValue) {
        debugPrint("Arming...");
        // perform arming action here

      } else {
        debugPrint("Disarming...");
        // perform disarming action here

      }
    }
  }

  // Future method for generating recurring searching string eclipses
  Future<String> searchValGen() async {
    int i = 0;
    while (bleConnecting) {
      setState(() {
        searchingVal += ".";
      });
      i++;
      await Future.delayed(const Duration(seconds: 1));
      if (i > 2 || searchingVal == "State - Searching...") {
        setState(() {
          searchingVal = "State - Searching";
          i = 0;
        });
        //break;
      }
    }
    searchingVal = "State - Searching";
    return "State - Searching";
  }
}