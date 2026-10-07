import 'navigation_destination.dart';

enum TravelMode { walking, driving }

class RouteInfo {
  const RouteInfo({
    required this.destination,
    required this.mode,
    required this.distanceKm,
    required this.minutes,
  });
  final RouteDestination destination;
  final TravelMode mode;
  final double distanceKm;
  final int minutes;
}
