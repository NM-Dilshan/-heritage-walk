import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:heritage_walk/features/navigation_guide/services/location_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/routing_service.dart';
import 'package:heritage_walk/features/navigation_guide/models/route_info.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';

class FakeGps implements LocationService {
  FakeGps({this.failure, this.fix = const LatLng(6.032, 80.218)});
  LocationState? failure;
  LatLng fix;
  Completer<LatLng>? pending;
  int currentCalls = 0, watches = 0, cancellations = 0, settingsCalls = 0;
  late final updates = StreamController<LatLng>.broadcast(
    onListen: () => watches++,
    onCancel: () => cancellations++,
  );
  @override
  Future<LatLng> current() async {
    currentCalls++;
    if (failure != null) throw LocationFailure(failure!);
    return pending?.future ?? fix;
  }

  @override
  Stream<LatLng> watch() => updates.stream;
  @override
  Future<bool> openSettings({bool device = false}) async {
    settingsCalls++;
    return true;
  }

  Future<void> dispose() => updates.close();
}

class FakeRouting implements RoutingService {
  RouteFailure? failure;
  Completer<RoutedPath>? pending;
  int calls = 0;
  LatLng? start, destination;
  TravelMode? mode;
  @override
  Future<RoutedPath> route(
    LatLng start,
    LatLng destination,
    TravelMode mode,
  ) async {
    calls++;
    this.start = start;
    this.destination = destination;
    this.mode = mode;
    if (failure != null) throw RoutingException(failure!);
    return pending?.future ??
        RoutedPath(
          [
            start,
            LatLng(start.latitude + .001, start.longitude + .001),
            destination,
          ],
          3800,
          mode == TravelMode.walking ? 3480 : 600,
        );
  }
}

HeritagePlace coordinatePlace(
  HeritagePlace place, {
  double? latitude = 6.026,
  double? longitude = 80.217,
}) => HeritagePlace.fromMap({
  ...place.toMap(),
  'latitude': latitude,
  'longitude': longitude,
});
Future<void> flushGps() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.value();
  }
}
