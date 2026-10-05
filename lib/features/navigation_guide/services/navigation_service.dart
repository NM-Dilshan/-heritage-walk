import 'package:flutter/foundation.dart';

import '../../discovery_planning/models/heritage_place.dart';
import '../models/route_info.dart';

/// Deterministic illustration only; no coordinates, GPS or route calculation.
class NavigationService extends ChangeNotifier {
  HeritagePlace? _destination;
  TravelMode _mode = TravelMode.driving;
  bool _active = false;
  HeritagePlace? get destination => _destination;
  TravelMode get mode => _mode;
  bool get isActive => _active;
  RouteInfo? get route => _destination == null
      ? null
      : RouteInfo(
          destination: _destination!,
          mode: _mode,
          distanceKm: 4.8,
          minutes: _mode == TravelMode.walking ? 58 : 15,
        );
  void selectDestination(HeritagePlace place) {
    _destination = place;
    _active = false;
    notifyListeners();
  }

  void selectMode(TravelMode mode) {
    _mode = mode;
    _active = false;
    notifyListeners();
  }

  bool start() {
    if (_destination == null) return false;
    _active = true;
    notifyListeners();
    return true;
  }

  void end() {
    _active = false;
    notifyListeners();
  }

  void clear() {
    _destination = null;
    _mode = TravelMode.driving;
    _active = false;
    notifyListeners();
  }
}
