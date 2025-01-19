/*
History

- class History extends StatelessWidget

    // Build Method   // Features lazy-build approach

    Widget build(BuildContext context)

    // JSON Methods (READ)
    Future<int?> readArmStatus() async            // Called for reading saved arm status from JSON upon app initialisation
    Future<double?> readGeoFenceRange() async     // Called for reading saved geofence value from JSON upon app initialisation
    Stream<dynamic> readJsonFile() async*         // Called for reading car positions for generating list tiles

    // JSON Methods (WRITE)
    void saveArmStatus(int appStatus) async                                   // Called for saving arm status into JSON file
    void saveGeoFenceRange(double geoFence) async                             // Called for saving geofence value into JSON file
    void saveCarPosition(LatLng carPosition, bool priority) async     // Called for for saving car positions into a JSON file

    // Utility Methods
    Future<String?> getLatestLocation() async     // Called for getting most recent location in JSON and setting to savedLat & savedLng vars
    void wipeLocations()                          // Called for wiping JSON of data, used for debug purposes
    void deleteFile()                             //Called for deleting current JSON file, used for debug purposes
*/

// Import Dart Libraries
import 'dart:convert';
import 'dart:io';

// Import Flutter Libraries
import 'package:RideSafe/Pages/google_maps.dart';
import 'package:RideSafe/Service%20Handlers/ble_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

// Import App Classes
import 'home_page.dart';
import 'package:path_provider/path_provider.dart';

/*
----------- Definitions & Variables -----------
*/

int readStatus = 0;       // Global def for most recent saved ARM value
double geoRange = 10.0;    // Global def for most recent saved geofence value, defaulted to 10 until set
late LatLng armPosition;

/*
----------- Code Section Start -----------
*/

// Home Maps State Definition
class History extends StatelessWidget {
  const History({super.key});
  /*
  ----------- Build Section -----------
  */

  // Build Method - Features lazy-build approach
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: readJsonFile(), // stream from the readJsonFile function
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {

        return SizedBox(
          height: MediaQuery.of(context).size.height, // Set a fixed height for the container
          child: ListView.builder(
            itemCount: 30, // number of items in the list view
            itemBuilder: (context, index) {
              // get the date for the current index by subtracting the number of days from the current date
              DateTime day = DateTime.now().subtract(Duration(days: index));
              String subheading = "No data available for this day";
              // check if the snapshot has data and it is not null
              if (snapshot.hasData && snapshot.data != null) {
                dynamic data = snapshot.data;
                // check if the data is a map and contains the key for the current day
                if (data is Map && data.containsKey("${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}"))
                {
                  dynamic dayData = data[DateFormat("yyyy-MM-dd").format(day)];
                  // check if the dayData is not null and contains positions

                  if (dayData != null && dayData["positions"] != null && dayData["positions"].isNotEmpty) {
                    List<Widget> positionWidgets = [];
                    // iterate through the positions and create Text widgets for each
                    for (dynamic position in dayData["positions"]) {
                      positionWidgets.add(Text("Latitude: ${position["latitude"]}, Longitude: ${position["longitude"]}"));
                    }
                    return ListTile(
                      tileColor: Colors.white,
                      title: Text(DateFormat("dd-MM-yyyy").format(day), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        children: positionWidgets,
                      ),
                    );
                  }
                }
              }

              // if no data is available for the current day, display the subheading
              return ListTile(
                tileColor: Colors.deepPurple,
                title: Text(DateFormat("dd-MM-yyyy").format(day), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(subheading),
              );
            },
          ),
        );
      },
    );
  }

  /*
  ----------- JSON Methods (READ) -----------
  */

  // Function for reading saved arm status from JSON upon app initialisation  - arm_status.json
  static Future<int?> readArmStatus() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/arm_status.json";
    final file = File(filePath);

    if (await file.exists()) {
      final storeValue = await file.readAsString();
      final storeData = jsonDecode(storeValue);

      if (storeData.containsKey("arm_status")) {
        readStatus = int.parse(storeData["arm_status"]);
        debugPrint(readStatus.toString());
        return int.parse(storeData["arm_status"]);
      }
    }
    return null;
  }

  // Function for reading saved geofence value from JSON upon app initialisation - geo_fence.json
  Future<double?> readGeoFenceRange() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/geo_fence.json";
    final file = File(filePath);

    if (await file.exists()) {
      final storeValue = await file.readAsString();
      final storeData = jsonDecode(storeValue);
      if (storeData.containsKey("geo_fence")) {
        geoRange = storeData["geo_fence"];
        debugPrint(geoRange.toString());
        return storeData["geo_fence"];
      }
    }
    return null;
  }

  // Function for reading saved geofence value from JSON upon app initialisation - arm_position.json
  static Future<String?> readArmPosition() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/arm_position.json";
    final file = File(filePath);

    if (await file.exists()) {
      final storeValue = await file.readAsString();
      debugPrint(storeValue);
      final storeData = jsonDecode(storeValue);
      if (storeData.containsKey("arm_location")) {
        debugPrint(storeValue);
        armPosition = LatLng(storeData["arm_location"]["arm_pos_lat"], storeData["arm_location"]["arm_pos_lng"]);
        debugPrint('ARMPOS LOADING TESTY');
        debugPrint(armPosition.toString());
        return null;
      }
    }
    return null;
  }

  // Function for for reading car positions for generating list tiles - car_position.json
  Stream<dynamic> readJsonFile() async* {
    // Get the directory where the file is saved
    Directory directory = await getApplicationDocumentsDirectory();
    String filePath = "${directory.path}/car_position.json";

    // Read the contents of the file
    File file = File(filePath);
    String fileContents = await file.readAsString();

    // Parse the JSON string
    dynamic data = jsonDecode(fileContents);

// Initialize the data with an empty Map if it is null or not a Map
    if (data == null || data is! Map) {
      data = {};
    }
// Iterate through the data and create an entry for each day with an empty list
    for (var i = 0; i < 30; i++) {
      DateTime day = DateTime.now().subtract(Duration(days: i));
      // Convert the day to a string in the format 'yyyy-MM-dd'
      String dayString = DateFormat("yyyy-MM-dd").format(day);
      if (!data.containsKey(dayString)) {
        data[dayString] = {
          "day": dayString,
          "positions": []
        };
      }
    }
    // Yield the data as a stream
    yield data;
  }

  /*
  ----------- JSON Methods (WRITE) -----------
  */


  // Function for saving arm status into JSON file - arm_status.json
  static void saveArmStatus(int appStatus) async {
    debugPrint("saveArmStatus: Fired");
    debugPrint("saveArmStatus: App Int: $appStatusInt");
    String armValue = appStatus.toString();

    // Get the directory where the file is saved
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/arm_status.json";
    final file = File(filePath);

    late dynamic storeData = int;

    // Check if the file exist
    if (!await file.exists()) {
      debugPrint("saveArmStatus: File Created");
      // Create the file if it doesn't exist
      await file.create();
      await file.writeAsString(jsonEncode({}));
    }

    // If file exists
    else if (await file.exists()) {
      final storeValue = await file.readAsString();
      storeData = jsonDecode(storeValue);
    }

    // Check if the data contains an entry for arm value
    if (!storeData.containsKey("arm_status")) {
      storeData["arm_status"] = {
        "arm_status": armValue,
      };
    }

    storeData['arm_status'] = armValue;
    await file.writeAsString(jsonEncode(storeData));

    debugPrint("The data1 is $storeData");
    debugPrint("The data2 is $storeData");
  }

  // Function for saving initial arm location into JSON file for re-initialising geo-fence on restart - arm_position.json
  static void saveArmPosition(LatLng location) async {

    // Get the directory where the file is saved
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/arm_position.json";
    final file = File(filePath);

    late dynamic storeData = int;

    // Check if the file exist
    if (!await file.exists()) {
      // Create the file if it doesn't exist
      await file.create();
      await file.writeAsString(jsonEncode({}));
    }

    // If file exists
    else if (await file.exists()) {
      final storeValue = await file.readAsString();
      storeData = jsonDecode(storeValue);
    }

    // Check if the data contains an entry for arm value
    if (!storeData.containsKey("arm_location")) {
      storeData["arm_location"] = {
        "arm_pos_lat": location.latitude,
        "arm_pos_lng": location.longitude
      };
      storeData['arm_pos_lat'] = location.latitude;
      storeData["arm_pos_lng"] = location.longitude;

      await file.writeAsString(jsonEncode(storeData));

      debugPrint("saveArmPosition: The data1 is $storeData");
      debugPrint("saveArmPosition: The data2 is $storeData");
    }

    if(storeData["arm_pos_lat"] == 0.0) {
      storeData['arm_pos_lat'] = location.latitude;
      storeData["arm_pos_lng"] = location.longitude;
      await file.writeAsString(jsonEncode(storeData));

      debugPrint("saveArmPosition: The data1 is $storeData");
      debugPrint("saveArmPosition: The data2 is $storeData");
    } else {
      return;
    }
  }

  // Function for saving geofence value into JSON file - geo_fence.json
  void saveGeoFenceRange(double geoFence) async {
    geoRange = geoFence;

    // Get the directory where the file is saved
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/geo_fence.json";
    final file = File(filePath);

    debugPrint("File path: $filePath");

    late dynamic storeData = double;

    // Check if the file exist
    if (!await file.exists()) {
      // Create the file if it doesn't exist
      await file.create();
      await file.writeAsString(jsonEncode({}));
    }

    // If file exists
    else if (await file.exists()) {
      final storeValue = await file.readAsString();
      storeData = jsonDecode(storeValue);
    }

    // Check if the data contains an entry for arm value
    if (!storeData.containsKey(geoRange)) {
      storeData["geo_fence"] = {
        "geo_fence" : geoRange
      };
    }

    storeData['geo_fence'] = geoRange;
    await file.writeAsString(jsonEncode(storeData));

    debugPrint("saveGeoFenceRange: The data1 is $storeData");
    debugPrint("saveGeoFenceRange: The data2 is $storeData");
  }

  // Function for saving car positions into a JSON file - car_position.json
  static void saveCarPosition(LatLng carPosition, bool priority) async {

    if (carPosition == const LatLng(0.0,0.0)) {
      debugPrint("saveCarPosition: Invalid Position, Discarding..");
      return null;
    }

    // Get the current day
    DateTime day = DateTime.now();
    // Convert the day to a string in the format 'yyyy-MM-dd'
    String dayString = DateFormat("yyyy-MM-dd").format(day);

    // Get the directory where the file is saved
    Directory directory = await getApplicationDocumentsDirectory();
    String filePath = "${directory.path}/car_position.json";

    debugPrint("File path: $filePath");
    // Check if the file exists
    File file = File(filePath);
    if (!await file.exists()) {
      // Create the file if it doesn't exist
      await file.create();
      await file.writeAsString(jsonEncode({}));
    }

    String fileContents = await file.readAsString();
    if (fileContents.isEmpty) {
      debugPrint("saveCarPosition: Data is Null, Discarding..");
      return;
    } else {

      // Parse the JSON string
      dynamic data = jsonDecode(fileContents);

      // Initialize the data with an empty Map if it is null or not a Map - maybe this?
      if (data == null || data is! Map) {
        data = {};
        //return;
      }

      // Check if the data contains an entry for the current day
      if (!data.containsKey(dayString)) {
        data[dayString] = {
          "day": dayString,
          "positions": []
        };
      }

      // debugPrint("saveCarPosition: The data1 is $data");
      // Get the positions list for the current day
      List<dynamic> positions = data[dayString]["positions"];

      // Bool storage for positions check - checks if positions are present to avoid duplicate entries
      bool locPresent = positions.any((position) =>
      position["latitude"] == carPosition.latitude &&
          position["longitude"] == carPosition.longitude);

      if (!locPresent) {
        positions.add({
          "latitude": carPosition.latitude,
          "longitude": carPosition.longitude,
        });
        // Convert the updated data to a JSON string and write it to the file
        file.writeAsString(jsonEncode(data));
        // debugPrint("saveCarPosition: The data2 is $data");
      } else {
        debugPrint("saveCarPosition: Error! Duplicate Location!");
      }
    }
  }

  /*
  ----------- Utility Methods -----------
  */

  // Function for getting most recent location in JSON and setting to savedLat & savedLng vars
  Future<String?> getLatestLocation() async {
    DateTime day = DateTime.now(); // Get the current day
    String dayString = DateFormat("yyyy-MM-dd").format(day); // Convert the day to a string in the format 'yyyy-MM-dd'

    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/car_position.json");

    if (await file.exists()) {
      final storeValue = await file.readAsString();
      dynamic storeData;
      if (storeValue.isNotEmpty) {
        storeData = jsonDecode(storeValue);
      } else {
        debugPrint("getLatestLocation: Error! JSON string is empty!");
        return null;
      }
      if (storeData.containsKey(dayString)) {
        if (storeData[dayString].containsKey("positions")) {
          List<dynamic> positions = storeData[dayString]["positions"];
          if (positions.isNotEmpty) {
            Map<String, dynamic> latestPosition = positions.last;
            debugPrint('----------------------------');
            debugPrint('getLatestLocation: Success!');

            savedLat = latestPosition["latitude"];
            savedLng = latestPosition["longitude"];

            debugPrint('getLatestLocation: lat - $savedLat');
            debugPrint('getLatestLocation: lng - $savedLng');
            debugPrint('----------------------------\n');

            carPosition = LatLng(latestPosition["latitude"], latestPosition["longitude"]);

            if (positions.length > 1) {
              Map<String, dynamic> secondLatestPosition = positions[positions.length - 2];
              if (secondLatestPosition["latitude"] == savedLat && secondLatestPosition["longitude"] == savedLng) {
                positions.removeLast();
                debugPrint("getLatestLocation: Removed Duplicate Position");
              }
            }
          }
        } else {
          debugPrint("getLatestLocation: Error! No Positions for Current Day!");
          return null;
        }
      } else {
        debugPrint("getLatestLocation: Error! Locations Array Empty!");
        return null;
      }
    }
    return null;
  }

  // Function for wiping JSON of data, used for debug purposes
  void wipeLocations() async {
    // Get the current day
    DateTime day = DateTime.now();
    // Convert the day to a string in the format 'yyyy-MM-dd'
    String dayString = DateFormat("yyyy-MM-dd").format(day);

    final directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/car_position.json");

    if (await file.exists()) {
      debugPrint("getLatestLocation: File Exists, Parsing..");
      final storeValue = await file.readAsString();
      final storeData = jsonDecode(storeValue);

      if (storeData.containsKey(dayString)) {
        debugPrint("getLatestLocation: Day Exists");
        if (storeData[dayString].containsKey("positions")) {
          debugPrint("getLatestLocation: Positions Entry Exists");
          List<dynamic> positions = storeData[dayString]["positions"];
          if (positions.isNotEmpty) {
            const dummyData = "";
            file.writeAsString(jsonEncode(dummyData));
            debugPrint('getLatestLocation: Success! Positions Wiped!');
          }
        } else {
          debugPrint("getLatestLocation: Error! No Positions to wipe.");
        }
      }
    }
    return null;
  }

  // Called for deleting current JSON file, used for debug purposes
  // Type 1 - Arm File
  // Type 2 - Device Locations File
  // Type 3 - Arm Positions File
  // Type 4 -
  void deleteFile(int type) async {
    final directory = await getApplicationDocumentsDirectory();

    final fileArmVal = File("${directory.path}/status.json");
    final fileCarPos = File("${directory.path}/car_position.json");
    final fileArmPos = File("${directory.path}/arm_position.json");
    final fileGeo = File("${directory.path}/geo_fence.json");

    switch (type) {
      case 1:
        if (await fileArmVal.exists()) {
          debugPrint("getLatestLocation: Arm Value File Exists, Deleting..");
          fileArmVal.delete();
        }
        break;
      case 2:
        if (await fileCarPos.exists()) {
          debugPrint("getLatestLocation: Car Positions File Exists, Deleting..");
          fileCarPos.delete();
        }
        break;
      case 3:
        if (await fileArmPos.exists()) {
          debugPrint("getLatestLocation: Arm Position File Exists, Deleting..");
          fileArmPos.delete();
        }
        break;
      case 4:
        if (await fileGeo.exists()) {
          debugPrint("getLatestLocation: Geo Radius File Exists, Deleting..");
          fileGeo.delete();
        }
        break;
    }
    return null;
  }
}




















