import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List<Map<String, dynamic>> locationUpdates = [];
  bool? isRunning;
  final service = FlutterBackgroundService();
  bool isLoading = true;

  Future<void> startBackgroundService() async {
    try {
      setState(() {
        isRunning = true;
      });
      await _checkPermissions();
      await service.startService();
    } catch (e) {
      print("EXCEPTION WHILE STARTING BACKGROUND SERVICE: $e");

      stopBackgroundService();
    }
  }

  Future<void> _loadLocationUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUpdates = prefs.getString('locationUpdates');
    if (storedUpdates != null) {
      setState(() {
        locationUpdates = List<Map<String, dynamic>>.from(
          jsonDecode(storedUpdates),
        );
      });
    }
  }

  Future<void> _checkPermissions() async {
    // Check if location services are enabled
    bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (mounted) {
        await Geolocator.openLocationSettings();
      }

      throw Exception("Location service not enabled");
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();

    // Request "Allow all the time" location permission
    if (permission != LocationPermission.always) {
      await _showPermissionDialog();

      throw Exception(
          "Location permission should be set to 'Allow all the time' to access location even when the app is in background or closed");
    }
  }

  Future<void> _showPermissionDialog({String? message}) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permission Required"),
          content: Text(message ??
              "Please enable 'Allow all the time' location permission in the app settings to allow location tracking in the background or when the app is closed."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        );
      },
    );
  }

  stopBackgroundService() {
    try {
      // Invoke the "stopService" action via the background service
      service.invoke("stopService");
      isRunning = false;
      setState(() {});
    } catch (e) {
      // Handle the error here if the service cannot be stopped
      print("Error stopping background service: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Something went wrong, Please try again later")));
    }
  }

  Future<void> isServiceRunning() async {
    isRunning = await service.isRunning();
    setState(() {});
  }

  listenToLocationUpdates() {
    service.on("updateLocation").listen((data) {
      if (data != null) {
        setState(() {
          locationUpdates.add(data);
        });
      }
    });
  }

  Future<void> _deleteLocationUpdates() async {
    try {
      stopBackgroundService();

      final prefs = await SharedPreferences.getInstance();
      await prefs
          .remove('locationUpdates'); // Remove data from SharedPreferences

      setState(() {
        locationUpdates.clear(); // Clear the UI list
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location updates deleted successfully")),
      );
    } catch (e) {
      print("Error while deleting location updates: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete location updates")),
      );
    }
  }

  initialize() async {
    await isServiceRunning();
    await _loadLocationUpdates();

    listenToLocationUpdates();
    isLoading = false;
    setState(() {});
  }

  @override
  void initState() {
    initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView.builder(
                      itemCount: locationUpdates.length,
                      itemBuilder: (context, index) {
                        final update = locationUpdates[index];
                        return ListTile(
                          title: Text(
                              "Lat: ${update['latitude']}, Lng: ${update['longitude']}"),
                          subtitle: Text("Time: ${update['timestamp']}"),
                        );
                      },
                    ),
            ),
            Divider(),
            ElevatedButton(
              onPressed: isRunning == null
                  ? null // Prevent pressing if state is loading
                  : () {
                      if (isRunning!) {
                        stopBackgroundService();
                      } else {
                        startBackgroundService();
                      }
                    },
              child: isRunning != null
                  ? Text(isRunning! ? "Stop Tracking" : "Start Tracking")
                  : const CircularProgressIndicator(),
            ),
            ElevatedButton(
              onPressed: _deleteLocationUpdates,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                "Delete Data",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
