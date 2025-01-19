/*
Profile Page

- class ProfilePage extends StatefulWidget

- class ProfilePageState extends State<ProfilePage>

    // Build Method
    Widget build(BuildContext context)

    // Utility Methods
    Future<AlertDialog?> tripDetails(BuildContext context) async        // Function for getting trip details of current day
*/


// Import Dart Libraries
import 'dart:convert';
import 'dart:io';

// Import Flutter Packages
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geo_location;
import 'package:path_provider/path_provider.dart';

// Import App Classes
import 'google_maps.dart';

/*
----------- Code Section Start -----------
*/

// ProfilePage State Definition
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);
  final HomeMaps _googleMaps = const HomeMaps();

  get context => null;

  @override
  ProfilePageState createState() => ProfilePageState();
}

// ProfilePage Class Definition
class ProfilePageState extends State<ProfilePage> {
  User? user = FirebaseAuth.instance.currentUser; // Variable for current logged in user
  String? email; // Late var for current user's email

  late double firstLat; // Late Var - Lat of first position of day
  late double firstLng; // Late Var - Lng of first position of day

  late double lastLat;  // Late Var - Lat of last position of day
  late double lastLng;  // Late Var - Lng of last position of day

  /*
  ----------- Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    email = user?.email;

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            color: const Color(0xD3CA9EFF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const Divider(height: 30),

                // Profile Image
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(image: NetworkImage('https://thispersondoesnotexist.xyz/img/4033.jpg'), fit: BoxFit.cover),
                  ),
                ),

                const Divider(height: 20),

                // Name Text
                const Text(
                  'John Doe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),

                const Divider(height: 20),

                // Email Text
                Text(email ?? 'No email found', style: const TextStyle(fontSize: 18)),

                const Divider(height: 20),

                // Speed Limit Option
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: () {
                      // navigate to speed alerts page
                    },
                    color: Colors.deepPurple,
                    child: const Text(
                      'Get Speed Limit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const Divider(height: 10),

                // Panic Button Option
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: () {
                    // navigate to panic button page
                    },
                    color: Colors.deepPurple,
                    child: const Text(
                      'Panic Button',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const Divider(height: 10),

                // Share Location Option
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: () async {
                      widget._googleMaps.shareLocation();
                    },
                    color: Colors.deepPurple,
                    child: const Text('Share Location', style: TextStyle(color: Colors.white)),
                  ),
                ),

                const Divider(height: 10),

                // Trip Details Option
                SizedBox(
                  width: double.infinity,
                  child: MaterialButton(
                    onPressed: () {
                      tripDetails(context);
                    },
                    color: Colors. deepPurple,
                    child: const Text(
                      'Trip Details',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const Divider(height: 10),

                // Logout Option
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: MaterialButton(
                    onPressed: () {
                      // perform logout action
                    },
                    color: Colors.red,
                    child: const Text('Logout', style: TextStyle(color: Colors.white)),
                  ),
                ),

                SizedBox(
                  height: MediaQuery.of(context).size.height,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
  ----------- Utility Methods -----------
  */

  // Function for getting trip details of current day
  Future<AlertDialog?> tripDetails(BuildContext context) async {
    DateTime day = DateTime.now(); // Get the current day
    String dayString = DateFormat("yyyy-MM-dd").format(
        day); // Convert the day to a string in the format 'yyyy-MM-dd'

    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/car_position.json";
    final file = File(filePath);

    if (await file.exists()) {
      debugPrint("tripDetails: File Exists, Parsing..");
      final storeValue = await file.readAsString();
      final storeData = jsonDecode(storeValue);

      if (storeData.containsKey(dayString)) {
        debugPrint("tripDetails: Day Exists");
        if (storeData[dayString].containsKey("positions")) {
          debugPrint("tripDetails: Positions Entry Exists");
          List<dynamic> positions = storeData[dayString]["positions"];
          if (positions.isNotEmpty) {
            Map<String, dynamic> lastPosition = positions.last;
            Map<String, dynamic> firstPosition = positions.first;

            lastLat = lastPosition["latitude"];
            lastLng = lastPosition["longitude"];
            firstLat = firstPosition["longitude"];
            firstLng = firstPosition["longitude"];

            double proximityCalc = geo_location.Geolocator.distanceBetween(
                firstLat, firstLng, lastLat, lastLng);
            String travelDistance = "You travelled a whopping $proximityCalc today with RideSafe!\n";

            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Trip Details'),
                  icon: const Icon(Icons.travel_explore_sharp),
                  content: Text(travelDistance),
                  actions: [
                    TextButton(
                      child: const Text("OK"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          }
        } else {
          debugPrint("getLatestLocation: Error! No Positions for Current Day!");
        }
      }
    }
    return null;
  }
}