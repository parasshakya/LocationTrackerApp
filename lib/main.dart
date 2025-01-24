import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
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
    return MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LocationScreen(),
        )
      ]),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  service.on("stopService").listen((event) async {
    service.stopSelf(); //Stop the service
  });

  final prefs = await SharedPreferences.getInstance();

  Timer.periodic(const Duration(seconds: 8), (timer) async {
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
      final storedUpdates = prefs.getString('locationUpdates');
      List<Map<String, dynamic>> updates = [];
      if (storedUpdates != null) {
        updates = List<Map<String, dynamic>>.from(jsonDecode(storedUpdates));
      }
      updates.add(locationData);

      await prefs.setString('locationUpdates', jsonEncode(updates));
    } catch (e) {
      print("Error while fetching or storing location: $e");
    }
  });
}
