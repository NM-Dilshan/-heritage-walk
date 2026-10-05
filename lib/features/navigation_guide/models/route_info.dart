import '../../discovery_planning/models/heritage_place.dart';

enum TravelMode { walking, driving }

class RouteInfo {
  const RouteInfo({
    required this.destination,
    required this.mode,
    required this.distanceKm,
    required this.minutes,
  });
  final HeritagePlace destination;
  final TravelMode mode;
  final double distanceKm;
  final int minutes;
  static const directions = [
    'Start from the current-location demo marker',
    'Continue toward the heritage area',
    'Follow the illustrated route',
    'Arrive at the destination demo marker',
  ];
}
