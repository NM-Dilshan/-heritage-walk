/// A routable coordinate, independent of catalog persistence.
abstract interface class RouteDestination {
  String get id;
  String get name;
  String get subtitle;
  bool get hasName;
  double? get latitude;
  double? get longitude;
}
