import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationState {
  notRequested,
  loading,
  granted,
  denied,
  deniedForever,
  servicesOff,
  unavailable,
  timeout,
  error,
}

class LocationFailure implements Exception {
  const LocationFailure(this.state);
  final LocationState state;
}

bool validCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

abstract interface class LocationService {
  Future<LatLng> current();
  Stream<LatLng> watch();
  Future<bool> openSettings({bool device = false});
}

class DeviceLocationService implements LocationService {
  @override
  Future<LatLng> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationState.servicesOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(LocationState.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(LocationState.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!validCoordinates(position.latitude, position.longitude)) {
        throw const LocationFailure(LocationState.unavailable);
      }
      return LatLng(position.latitude, position.longitude);
    } on TimeoutException {
      throw const LocationFailure(LocationState.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationState.servicesOff);
    }
  }

  @override
  Stream<LatLng> watch() =>
      Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          // Android's direct provider starts/stops synchronously. This avoids
          // a delayed fused-provider settings callback restarting updates after
          // an immediate foreground-session cancellation.
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          intervalDuration: const Duration(seconds: 10),
        ),
      ).map((p) {
        if (!validCoordinates(p.latitude, p.longitude)) {
          throw const LocationFailure(LocationState.unavailable);
        }
        return LatLng(p.latitude, p.longitude);
      });
  @override
  Future<bool> openSettings({bool device = false}) =>
      device ? Geolocator.openLocationSettings() : Geolocator.openAppSettings();
}

/// Hardware-free harness: explicitly unavailable, never fabricated GPS.
class UnavailableLocationService implements LocationService {
  @override
  Future<LatLng> current() async =>
      throw const LocationFailure(LocationState.unavailable);
  @override
  Stream<LatLng> watch() => const Stream.empty();
  @override
  Future<bool> openSettings({bool device = false}) async => false;
}
