// Development-only Android GPS/route smoke test. No Firebase or production writes.
import 'package:flutter/material.dart';
import 'package:heritage_walk/features/navigation_guide/services/location_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/routing_service.dart';
import 'package:heritage_walk/features/navigation_guide/models/route_info.dart';
import 'package:latlong2/latlong.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Part 9 Android GPS / OSRM smoke')),
      ),
    ),
  );
  final routing = FossgisRoutingService();
  try {
    final gps = DeviceLocationService();
    final position = await gps.current();
    debugPrint('PART9_DEVICE_GPS: ${position.latitude},${position.longitude}');
    final stream = gps.watch().listen((_) {});
    await stream.cancel();
    final route = await routing.route(
      position,
      const LatLng(6.026, 80.217),
      TravelMode.driving,
    );
    if (route.points.length <= 2 ||
        route.distanceMeters <= 0 ||
        route.durationSeconds <= 0) {
      throw StateError(
        'Expected a real road route with geometry and server metrics',
      );
    }
    debugPrint(
      'PART9_DEVICE_PASS: GPS stream started/cancelled; OSRM ${route.points.length} vertices, ${route.distanceMeters}m, ${route.durationSeconds}s',
    );
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'PART9_DEVICE_PASS\nGPS: $position\nRoute: ${route.points.length} vertices\n${route.distanceMeters} m / ${route.durationSeconds} s',
            ),
          ),
        ),
      ),
    );
  } catch (error, stack) {
    debugPrint('PART9_DEVICE_FAIL: $error\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('PART9_DEVICE_FAIL: $error'))),
      ),
    );
  } finally {
    routing.dispose();
  }
}
