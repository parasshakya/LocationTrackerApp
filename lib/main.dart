import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_app/helper.dart';
import 'package:location_app/location_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();

  runApp(const MainApp());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
    androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LocationScreen(),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize Completer
  Completer<void> storageCompleter = Completer<void>();

  service.on("stopService").listen((event) async {
    // Wait for storage operation to complete if not already done
    if (!storageCompleter.isCompleted) {
      try {
        await storageCompleter.future; // Wait for completer to complete
      } catch (e) {
        print("Error while waiting for storage operation: $e");
      }
    }

    service.stopSelf(); //Stop the service after storage operation
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      final timeStamp = formateDateTime(DateTime.now());

      final locationData = {
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp": timeStamp,
      };

      service.invoke("updateLocation", locationData);

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Tracking your location",
            content:
                "$timeStamp, lat: ${position.latitude}, long: ${position.longitude} ",
          );
        }
      }
      // Save location to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedUpdates = prefs.getString('locationUpdates');
      List<Map<String, dynamic>> updates = [];
      if (storedUpdates != null) {
        updates = List<Map<String, dynamic>>.from(jsonDecode(storedUpdates));
      }
      updates.add(locationData);

      await prefs.setString('locationUpdates', jsonEncode(updates));

      // Complete the Completer after storage operation
      if (!storageCompleter.isCompleted) {
        storageCompleter.complete();
      }
    } catch (e) {
      print("Error while fetching or storing location: $e");
      if (!storageCompleter.isCompleted) {
        storageCompleter.completeError(e);
      }
    }
  });
}
