// This file imports the necessary libraries to make an HTTP request
import 'dart:convert'; // for decoding JSON
import 'dart:io'; // for handling HTTP headers
import 'package:http/http.dart' as http_client; // for making HTTP requests

// This class represents the device information that will be returned from the TTN API
class DeviceInfo {
  final String deviceId; // the ID of the device
  final bool activated; // whether or not the device is activated

  DeviceInfo({
    required this.deviceId,
    required this.activated,
  });

// This method constructs a new DeviceInfo object from a JSON map
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['device_id'],
      activated: json['activated'],
    );
  }
}

// This function makes an HTTP request to the TTN API to get information about a device
Future<DeviceInfo> getDeviceInfo() async {

  final deviceInfoResponse = await http_client.get(
    Uri.parse('https://console.thethingsnetwork.org/xxxx'),
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer NNSXS.xxxxxxxxxxxxxxxxxxx.xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    },
  );

  final deviceInfo = jsonDecode(deviceInfoResponse.body);

  return DeviceInfo.fromJson(deviceInfo);
}
