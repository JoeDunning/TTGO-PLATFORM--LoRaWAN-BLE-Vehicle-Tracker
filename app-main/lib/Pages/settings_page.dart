/*
Settings Page
- class SettingsPage extends StatefulWidget
- class SettingsPage extends State<SettingsPage>
    // Build Method
    Widget build(BuildContext context)

    // State Handling
    @override void initState()              // Called upon state initialization
    @override void dispose()                // Called during disposing of state

    // State Methods
    void toggleLiveFeed()                   // Function for toggling live feed - shows live status of app values
    void _updateMACAddress(String value)    // Function for updating MAC address
*/

// Import Flutter Packages
import 'package:flutter/material.dart';

// Import App Classes
import 'history.dart';
import 'google_maps.dart';
import 'package:RideSafe/Service Handlers/ble_handler.dart';

/*
----------- Definitions & Variables -----------
*/

bool enableNotifications = true; // Class variable for notification status
int vehicleType = 2; // Class variable for vehicle type

/*
----------- Code Section Start -----------
*/

// SettingsPage State Definition
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  final History _history = const History();


  @override
  SettingsPageState createState() => SettingsPageState();
}

// SettingsPage Class Definition
class SettingsPageState extends State<SettingsPage>  {
  int currentIndex = 0; // Int to determine current page index
  String contactSOS = "03938182391"; // Class String for SOS number storage
  bool feedStatus = false; // Class bool for toggling live feed status
  bool debugStatus = false; // Class bool for toggling live feed status
  bool localArm = readStatus == 1 ? true : false; // Class bool for ARM status

  late TextEditingController _controllerMAC;  // Text controller for MAC address
  late TextEditingController _controllerSOS; // Text controller for SOS contact

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    Color getColor(Set<MaterialState> states) {
      const Set<MaterialState> interactiveStates = <MaterialState> {
        MaterialState.pressed,
        MaterialState.hovered,
        MaterialState.focused,
      };
      if (states.any(interactiveStates.contains)) {
        return Colors.lightGreen;
      }
      return Colors.green;
    }
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Scaffold(
        body: Flex(
          direction: Axis.vertical,
          children: <Widget>[

            const Divider(height: 2, thickness: 2, color: Colors.white),

            // Device Settings
            AppBar(
              title: const Text('Device Settings', style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.deepPurple,
            ),

            const Divider(height: 15),

            // Vehicle Type Setting
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2.2,
                  child: const Text('   Use Type: ', style: TextStyle(fontSize: 18,)),
                ),

                // Vehicle Type Select
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 1.5,
                  child: SizedBox(
                    width: 25,
                    child: DropdownButton<int>(
                      value: vehicleType,
                      items: const [
                        DropdownMenuItem<int>(
                          alignment: AlignmentDirectional.center,
                          value: 0,
                          child: Text('Personal', style: TextStyle(fontSize: 18), textAlign: TextAlign.start),
                        ),

                        DropdownMenuItem<int>(
                          alignment: AlignmentDirectional.center,
                          value: 1,
                          child: Text('Bicycle ', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                        ),

                        DropdownMenuItem<int>(
                          alignment: AlignmentDirectional.center,
                          value: 2,
                          child: Text('Motorbike', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                        ),

                        DropdownMenuItem<int>(
                          alignment: AlignmentDirectional.center,
                          value: 3,
                          child: Text('Car', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                        ),

                        DropdownMenuItem<int>(
                          alignment: AlignmentDirectional.center,
                          value: 4,
                          child: Text('Truck', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                        ),

                      ],
                      onChanged: (value) {
                        setState(() {
                          vehicleType = value!;
                        });
                      },
                    ),
                  ),
                ),
              ]
            ),

            const Divider(height: 10, thickness: 3,),

            // Enable Notifications Setting
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  child: const Text('   Enable Notifications ', style: TextStyle(fontSize: 18)),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,

                  child: Checkbox(
                    checkColor: Colors.white,
                    fillColor: MaterialStateProperty.resolveWith(getColor),
                    value: enableNotifications,
                    onChanged: (bool? value) {
                      setState(() {
                        enableNotifications = value!;
                      });
                    },
                  ),
                ),
              ]
            ),

            const Divider(height: 15),

            // SOS Settings
            AppBar(
              title: const Text('SOS Settings', style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.deepPurple,
            ),

            // Emergency Contact Setting - Submitted to HTTP ??
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  child: const Text('   Emergency Contact:', style: TextStyle(fontSize: 18)),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,

                  child: TextField(
                    controller: _controllerSOS,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                    onSubmitted: (String value) async {
                      _updateMACAddress(value);
                    },
                  ),
                ),
              ]
            ),

            // Hardware Settings
            AppBar(
              title: const Text('Hardware Settings', style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.deepPurple,
            ),

            const Divider(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,
                  child: const Text('   MAC Config:', style: TextStyle(fontSize: 18)),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,
                  child: TextField(
                    controller: _controllerMAC,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black),
                    onSubmitted: (String value) async {
                      _updateMACAddress(value);
                    },
                  ),
                ),
              ]
            ),

            const Divider(height: 15),

            // Debug Settings / Live Feed
            AppBar(
              title: const Text('Debug Settings / Live Feed', style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.black,
            ),

            const Divider(height: 15),

            // Toggle Live Feed- Debug Option
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 22,
                    child: const Text('   Toggle Live Feed:', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 35,
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: feedStatus ? MaterialStateProperty.all<Color>(Colors.green) : MaterialStateProperty.all<Color>(Colors.red),
                      ),
                      onPressed: () {
                        toggleLiveFeed();
                      },
                      child: const Text('Toggle', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ]
            ),

            if (feedStatus == true) const Divider(height: 15),

            if (feedStatus == true) Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2.3,
                    height: 20,
                    child: const Text('BLE Status: ', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 1.3,
                    height: 20,
                    child: Text(bleConnected ? 'Connected' : 'Disconnected', style: const TextStyle(fontSize: 17)), // ),
                  ),
                ]
            ),

            if (feedStatus == true) const Divider(height: 15),

            // GPS Status
            if (feedStatus == true) Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery
                        .of(context)
                        .size
                        .width / 4) * 2.3,
                    height: 20,
                    child: const Text(
                        'GPS Status: ', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery
                        .of(context)
                        .size
                        .width / 4) * 1.3,
                    height: 20,
                    child: Text(gpsStatus ? 'Accurate Fix' : 'No Fix',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ]
            ),

            if (feedStatus) const Divider(height: 15),

            // Saved Arm Status
            if (feedStatus) Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2.3,
                    height: 20,
                    child: const Text('Saved ARM Status: ', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 1.3,
                    height: 20,
                    child: Text(localArm ? 'Armed - 1' : 'Disarmed - 0', style: const TextStyle(fontSize: 17)),
                  ),
                ]
            ),

            if (feedStatus) const Divider(height: 15),

            if (feedStatus) const Divider(height: 2, thickness: 2, color: Colors.black),

            const Divider(height: 15),

            // Toggle Live Feed- Debug Option
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 22,
                    child: const Text('   Toggle Debug Options:', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 35,
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: debugStatus ? MaterialStateProperty.all<Color>(Colors.green) : MaterialStateProperty.all<Color>(Colors.red),
                      ),
                      onPressed: () {
                        toggleDebugFeed();
                      },
                      child: const Text('Toggle', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ]
            ),

            if (debugStatus) const Divider(height: 15),

            if (debugStatus) Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: const <Widget>[
                SizedBox(
                  child: Text('BLE / Arm Debug:', style: TextStyle(fontSize: 18)),

                ),
              ]
            ),

            if (debugStatus) const Divider(height: 15),

            // Force ARM - Debug Option
            if (debugStatus) Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 20,
                    child: const Text('   Force ARM:', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 35,
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.purple),
                      ),
                      onPressed: () {
                        setState(() {
                          if (readStatus == 1 || readStatus == 0) {
                            BLESystemState.bleReadWrite();
                          } else {
                            // notif
                          }
                        });
                      },
                      child: Text(localArm ? 'FORCE DISARM' : 'FORCE ARM', style: const TextStyle(fontSize: 17)),
                    ),
                  ),
                ]
            ),

            if (debugStatus) const Divider(height: 25, thickness: 2, color: Colors.black),

            // Reset Locations - Debug Option
            if (debugStatus) Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 20,
                    child: const Text('   Location Value Reset:', style: TextStyle(fontSize: 18)),
                  ),

                  SizedBox(
                    width: (MediaQuery.of(context).size.width / 4) * 2,
                    height: 35,
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                      ),
                      onPressed: () async {
                        // Show a confirmation dialog before wiping locations
                        bool? confirmWipe = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Reset'),
                              content: const Text('Are you sure you want to reset location values?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: const Text('Yes, Reset'),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmWipe == true) {
                          widget._history.wipeLocations();
                        }
                      },
                      child: const Text('Reset Values', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                ]
            ),

            if (debugStatus) const Divider(height: 15),

            // Delete JSON File - Stored Arm
            if (debugStatus) Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,
                  child: const Text('   Delete Arm File:', style: TextStyle(fontSize: 18)),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 35,
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.black)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text('Do you really want to delete the JSON file?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () {
                                  widget._history.deleteFile(1);
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Delete File', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ),

            if (debugStatus) const Divider(height: 15),

            // Delete JSON File - Stored Device Locations
            if (debugStatus) Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,
                  child: const Text('   Delete Locations File:', style: TextStyle(fontSize: 18)),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 35,
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.black)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text('Do you really want to delete the JSON file?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () {
                                  widget._history.deleteFile(2);
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Delete File', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ),

            if (debugStatus) const Divider(height: 15),

            // Delete JSON File - Stored Arm Position
            if (debugStatus) Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 20,
                  child: const Text('   Delete Arm Pos File:', style: TextStyle(fontSize: 18)),
                ),

                SizedBox(
                  width: (MediaQuery.of(context).size.width / 4) * 2,
                  height: 35,
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.black)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text('Do you really want to delete the JSON file?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () {
                                  widget._history.deleteFile(3);
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Delete File', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /*
  ----------- State Handling -----------
  */

  // Called upon state initialization
  @override
  void initState() {
    super.initState();
    _controllerMAC = TextEditingController(text: macAddress);
    _controllerSOS = TextEditingController(text: contactSOS);
  }

  // Called during disposing of state
  @override
  void dispose() {
    super.dispose();
    _controllerMAC.dispose();
    _controllerSOS.dispose();
  }

  /*
  ----------- State Methods -----------
  */

  // Function for toggling live feed - shows live status of app values
  void toggleLiveFeed() {
    setState(() {
      feedStatus = !feedStatus;
    });
  }

  // Function for toggling live feed - shows live status of app values
  void toggleDebugFeed() {
    setState(() {
      debugStatus = !debugStatus;
    });
  }

  // Function for updating MAC address
  void _updateMACAddress(String value) {
    if (mounted) {
      setState(() {
        macAddress = value;
      });
    }
  }
}