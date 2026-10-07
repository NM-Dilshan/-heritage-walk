import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/navigation_destination.dart';
import '../models/route_info.dart';
import 'location_service.dart';
import 'routing_service.dart';

class NavigationService extends ChangeNotifier {
  NavigationService({LocationService? location, RoutingService? routing})
    : location = location ?? DeviceLocationService(),
      routing = routing ?? FossgisRoutingService();
  final LocationService location;
  final RoutingService routing;
  RouteDestination? _destination;
  TravelMode _mode = TravelMode.driving;
  bool _active = false, loadingRoute = false, _disposed = false;
  int _generation = 0, _locationGeneration = 0;
  StreamSubscription<LatLng>? _subscription;
  LocationState locationState = LocationState.notRequested;
  RouteFailure? routeFailure;
  LatLng? currentPosition;
  RoutedPath? path;
  RouteDestination? get destination => _destination;
  TravelMode get mode => _mode;
  bool get isActive => _active;
  bool get validDestination =>
      validCoordinates(_destination?.latitude, _destination?.longitude);
  LatLng? get destinationPosition => validDestination
      ? LatLng(_destination!.latitude!, _destination!.longitude!)
      : null;
  RouteInfo? get route => path == null || _destination == null
      ? null
      : RouteInfo(
          destination: _destination!,
          mode: _mode,
          distanceKm: path!.distanceMeters / 1000,
          minutes: (path!.durationSeconds / 60).ceil(),
        );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void selectDestination(RouteDestination place) {
    end();
    _generation++;
    _destination = place;
    path = null;
    routeFailure = null;
    loadingRoute = false;
    _notify();
    if (currentPosition != null && validDestination) {
      unawaited(calculateRoute());
    }
  }

  void selectMode(TravelMode mode) {
    end();
    _mode = mode;
    _generation++;
    path = null;
    unawaited(calculateRoute());
    _notify();
  }

  Future<void> locate() async {
    final generation = ++_locationGeneration;
    end();
    _generation++;
    loadingRoute = false;
    currentPosition = null;
    path = null;
    locationState = LocationState.loading;
    _notify();
    try {
      final position = await location.current();
      if (_disposed || generation != _locationGeneration) return;
      currentPosition = position;
      locationState = LocationState.granted;
      _notify();
      await calculateRoute();
    } on LocationFailure catch (e) {
      if (generation == _locationGeneration) locationState = e.state;
    } catch (_) {
      if (generation == _locationGeneration) {
        locationState = LocationState.error;
      }
    }
    _notify();
  }

  Future<void> calculateRoute() async {
    if (currentPosition == null || !validDestination || _disposed) return;
    final generation = ++_generation;
    loadingRoute = true;
    routeFailure = null;
    path = null;
    _notify();
    try {
      final result = await routing.route(
        currentPosition!,
        destinationPosition!,
        _mode,
      );
      if (!_disposed && generation == _generation) path = result;
    } on RoutingException catch (e) {
      if (generation == _generation) routeFailure = e.reason;
    } catch (_) {
      if (generation == _generation) routeFailure = RouteFailure.offline;
    }
    if (generation == _generation) loadingRoute = false;
    _notify();
  }

  bool start() {
    if (path == null || currentPosition == null) return false;
    end();
    _active = true;
    try {
      _subscription = location.watch().listen(
        (position) {
          currentPosition = position;
          locationState = LocationState.granted;
          _notify();
        },
        onError: (Object error) {
          locationState = error is LocationFailure
              ? error.state
              : LocationState.unavailable;
          end();
        },
      );
    } catch (_) {
      locationState = LocationState.unavailable;
      end();
      return false;
    }
    _notify();
    return true;
  }

  void end({bool notify = true}) {
    _active = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (notify) _notify();
  }

  void suspend({bool notify = true}) {
    _locationGeneration++;
    _generation++;
    loadingRoute = false;
    if (locationState == LocationState.loading) {
      locationState = LocationState.unavailable;
    }
    end(notify: notify);
  }

  void clear() {
    suspend();
    _destination = null;
    _mode = TravelMode.driving;
    currentPosition = null;
    path = null;
    locationState = LocationState.notRequested;
    routeFailure = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _locationGeneration++;
    _generation++;
    unawaited(_subscription?.cancel());
    if (routing is FossgisRoutingService) {
      (routing as FossgisRoutingService).dispose();
    }
    super.dispose();
  }
}
