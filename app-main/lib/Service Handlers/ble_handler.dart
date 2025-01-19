import 'dart:async';
import 'dart:convert';

import 'package:RideSafe/Pages/history.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter/material.dart';
import 'package:RideSafe/Pages/google_maps.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../Authentication/notifications.dart';

late BluetoothDevice? _tracker; // Current connected device
bool bleConnected = false; // Bool for BLE connection status, signifies a complete and current connection
bool bleConnecting = false; // Bool for when BLE instance is currently attempting a connection
bool bleDataReady = false;

bool ?latPrep = false;
bool ?lngPrep = false;
bool gpsStatus = false;
late StreamSubscription subscriptionGPS; // GPS listening stream subscription
late StreamSubscription subscriptionMV; // Movement detection listening stream subscription

// ---- Location Vars ----

// BLE Location Vars
String _currentLatBLE = ""; // Current BLE Latitude - Parsed via BLE as a String, needed due to identifier
String _currentLngBLE = ""; // Current BLE Longitude - Parsed via BLE as a String, needed due to identifier

late String currentAlt; // Current Altitude - Parsed via BLE as a String

int appStatusInt = 0; // App Arm Status - Used as int to account for hex

/*
----------- Code Section Start -----------
*/

// Home Maps State Definition
class BLESystem extends StatefulWidget {
  const BLESystem({super.key});

  @override
  BLESystemState createState() => BLESystemState();
}

class BLESystemState extends State<BLESystem> {
  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }


  @override
  void initState() {
    super.initState();
    bleSetup();
  }

  // Called during disposing of state
  @override
  void dispose() {
    super.dispose();
  }

  /*
  ----------- BLE Method Area -----------
  */

  void bleSetup() {
    debugPrint("BLEHandler: Starting..");
    requestPermission();
    bleConnect();
  }

  // Defines a function for handling BLE connections
  Future<void> bleConnect() async {
    if (bleConnected) {
      return;
    }
    List<ScanResult> results = [];
    requestPermission();

    late StreamSubscription<List<ScanResult>> subscription;
    HomeMapsState.getTTNInfo();
    subscription = FlutterBlue.instance.scanResults.listen((scanResult) async {
      for (ScanResult result in scanResult) {
        macAddress = result.device.id.id;

        // Only store results with known MAC address
        if (macAddress == "3C:71:BF:59:7F:7E") {
          // Add result to list
          results.add(result);

          // Stop scanning once device is found
          FlutterBlue.instance.stopScan();
          subscription.cancel();

          // Connect to device

          await result.device.disconnect();
          await result.device.connect();
          //result.device.connect().then((device) {
          debugPrint("bleConnect: Connected to device");
          _tracker = result.device;

          bleConnected = true;
          bleConnecting = false;

          listenToGPSCharacteristic();
          listenToMVCharacteristic();
          // add extra listen code
          break;
        }
      }
    });
    FlutterBlue.instance.startScan(timeout: const Duration(seconds: 4));
    bleConnecting = true;
    searchValGen();
  }

  // Defines a function for handling BLE disconnect requests
  Future<AlertDialog> bleDisconnect() async {
    if (bleConnected == false) {
      return const AlertDialog(
        title: Text("BLE Already Disconnected!... Why are you seeing this?"),
      );
    }
    if (_tracker != null) {
      final deviceState = await _tracker!.state.first;
      if (deviceState != BluetoothDeviceState.connected) {
        debugPrint("Device Not Connected");
        return const AlertDialog(
          title: Text("Connection Cancelled"),
        );
      }
    }
    await FlutterBlue.instance.stopScan();
    await _tracker?.disconnect();
    _tracker = null;
    bleConnected = false;
    speedAlerts = false;
    debugPrint("Device Disconnected");
    return deviceDisconnectedNotification();
  }

  // Defines a function for handling BLE data writes for arming and disarming the device
  static void bleReadWrite() {
    final appArmUUID = Guid("5c1e52ea-9e6e-4f7e-a13a-7a609deffc79");

    _tracker?.discoverServices().then((services) {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == appArmUUID) {
            characteristic.read().then((value) {
              int armValue = value[0];
              debugPrint("Arm Value: $armValue");

              if (armValue == 49) {
                characteristic.write(utf8.encode("0"));
                appStatusInt = 0;

                debugPrint("------------------------------");
                debugPrint("bleReadWrite: Device Disarmed");
                debugPrint("------------------------------");
                History.saveArmStatus(0);
                History.saveArmPosition(const LatLng(0.0, 0.0));
              } else if (armValue == 48 || armValue == 0) {
                characteristic.write(utf8.encode("1"));
                appStatusInt = 1;
                debugPrint("---------------------------");
                debugPrint("bleReadWrite:  Device Armed");
                debugPrint("---------------------------");

                armCircleCenter = LatLng(carPosition.latitude, carPosition.longitude);

                History.saveArmStatus(1);
                History.saveArmPosition(armCircleCenter);
              }
            });
          }
        }
      }
    });
  }

  // Defines a function to handle Bluetooth connection/disconnection
  Future<void> handleBluetoothConnection() async {
    if (bleConnecting == true) { // if scan running then cancel current scan
      FlutterBlue.instance.stopScan();

      bleConnected = false;
      bleConnecting = false;
      speedAlerts = false;

      await connectionCancelNotification(context);
      return;
    }
    if (bleConnected) { // Initial check if device is connected, if so then disconnect
      debugPrint("Disconnecting Device");
      bleDisconnect();
      bleConnected = false;
    } else if (!bleConnected) { // Initial check is not connected for checking scan status

      // Initialise BLE connection
      await bleConnect();
      debugPrint("Device Connecting");
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (bleConnected) {

          debugPrint("Device Connected");
          bleConnected = true;

          return;
        } else if (bleConnecting == false) {
          debugPrint("Scan Cancelled");
          bleConnected = false;
          bleConnecting = false;
          speedAlerts = false;
          return;
        } else {
          debugPrint("Device Connection Timed Out");

          bleConnected = false;
          bleConnecting = false;
          speedAlerts = false;
          return;

        }
      });
    }
    unknownErrorNotification();
  }

  // Defines a function for listening to GPS characteristic info
  void listenToGPSCharacteristic() {
    final Guid callbackID = Guid("496c90d8-4cb6-4a92-9bb2-9a34e47b8538");
    _tracker?.discoverServices().then((services) {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
        in service.characteristics) {
          if (characteristic.uuid == callbackID) {
            characteristic.setNotifyValue(true);
            if (bleConnected == false) {
              bleConnected = true;
            }
            String utfValue = "";
            subscriptionGPS = characteristic.value.listen((value) {
              utfValue = utf8.decode(value, allowMalformed: true);
              processResponse(utfValue);
            });

          }
        }
      }
    });
  }

  void listenToMVCharacteristic() {
    final Guid callbackID = Guid("9be1c709-4bb2-4135-9beb-b74bda464a23");
    _tracker?.discoverServices().then((services) {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
        in service.characteristics) {
          if (characteristic.uuid == callbackID) {
            characteristic.setNotifyValue(true);
            if (bleConnected == false) {
              bleConnected = true;
            }
            String utfValue = "";
            subscriptionMV = characteristic.value.listen((value) {
              utfValue = utf8.decode(value, allowMalformed: true);
              processMovementDetect(utfValue);
            });

          }
        }
      }
    });
  }

  // Defines a function for handling incoming BLE responses
  void processResponse(String utfValue) {
    if (utfValue.length >= 3) {
      switch (utfValue.substring(0, 3)) {
        case "gpn": // GPN String - issues with substring require such an identifier
          gpsStatus = false;
          debugPrint("processResponse: GPS Unavailable");
          break;
        case "lat": // LAT String - issues with substring require such an identifier
          _currentLatBLE = utfValue.substring(4, 13);
          gpsStatus = true;
          latPrep = true;
          break;
        case "lng": // LNG String - issues with substring require such an identifier
          _currentLngBLE = utfValue.substring(4, 12);
          gpsStatus = true;
          lngPrep = true;
          break;
        case "alt": // ALT String - issues with substring require such an identifier
          currentAlt = utfValue.substring(4, 7);
          currentAlt += "m";
          gpsStatus = true;
          break;
        default:
          break;
      }

      if (latPrep == true && lngPrep == true) {
        bleDataReady = true;
      }

      if (bleDataReady) {
        double lat = double.parse(_currentLatBLE);
        double lng = double.parse(_currentLngBLE);

        HomeMaps.locationHandler(LatLng(lat, lng), 2);
        debugPrint("----------------------------------------");
        debugPrint("processResponse: BLE Response Processed!");
        debugPrint("----------------------------------------");
        //HomeMapsState.getCurrentLocationInfo(LatLng(lat, lng));

        latPrep = false;
        lngPrep = false;
        bleDataReady = false;
      }
    }
  }

  void processMovementDetect(String utfValue) {
    if (utfValue == "mvd") {
      movementDetected = true;
      debugPrint("processResponse: Movement Detected!");
    }
  }

  // Function for requesting Bluetooth permission on user device
  Future<void> requestPermission() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect
    ].request();
  }

  // Future method for generating recurring searching string eclipses
  Future<String> searchValGen() async {
    int i = 0;
    while (bleConnecting) {

      searchingVal += ".";

      i++;
      await Future.delayed(const Duration(seconds: 1));
      if (i > 2 || searchingVal == "State - Searching...") {

        searchingVal = "State - Searching";
        i = 0;

        //break;
      }
    }
    searchingVal = "State - Searching";
    return "State - Searching";
  }
}

// Class BLEHandler Definition
class BLEHandler extends StatelessWidget {
  const BLEHandler({Key? key, this.state}) : super(key: key);
  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}


