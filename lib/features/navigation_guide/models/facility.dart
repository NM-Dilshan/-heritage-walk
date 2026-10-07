import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import 'navigation_destination.dart';

enum FacilityCategory {
  hospital('Hospital / Medical', ['hospital', 'clinic', 'doctors']),
  pharmacy('Pharmacy', ['pharmacy']),
  police('Police', ['police']),
  atm('ATM', ['atm']),
  food('Restaurant / Food', ['restaurant', 'cafe', 'fast_food']),
  toilet('Public Toilet', ['toilets']),
  fuel('Fuel Station', ['fuel']),
  parking('Parking', ['parking']);

  const FacilityCategory(this.label, this.amenities);
  final String label;
  final List<String> amenities;
  bool matches(Map tags) => amenities.contains(tags['amenity']);
}

class NearbyFacility {
  const NearbyFacility({
    required this.osmId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.name,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
  });
  final String osmId;
  final FacilityCategory category;
  final double latitude, longitude, distanceMeters;
  final String? name, address, phone, website, openingHours;
  LatLng get position => LatLng(latitude, longitude);
  RouteDestination get destination => FacilityDestination(this);

  /// Nodes have coordinates; ways/relations use Overpass's bounding-box center.
  /// Missing or malformed elements are skipped; metadata is never invented.
  static NearbyFacility? fromOsm(
    Map element,
    LatLng origin,
    FacilityCategory category,
  ) {
    final type = element['type'], id = element['id'], tags = element['tags'];
    if (!['node', 'way', 'relation'].contains(type) ||
        id is! int ||
        id <= 0 ||
        tags is! Map ||
        !category.matches(tags)) {
      return null;
    }
    final coordinates = type == 'node' ? element : element['center'];
    if (coordinates is! Map) return null;
    final lat = coordinates['lat'], lon = coordinates['lon'];
    if (lat is! num ||
        lon is! num ||
        !validCoordinates(lat.toDouble(), lon.toDouble())) {
      return null;
    }
    String? text(String key) {
      final value = tags[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final street = [
      text('addr:housenumber'),
      text('addr:street'),
    ].whereType<String>().join(' ');
    final address =
        text('addr:full') ??
        [
          street.isEmpty ? null : street,
          text('addr:city'),
          text('addr:postcode'),
        ].whereType<String>().join(', ');
    final position = LatLng(lat.toDouble(), lon.toDouble());
    return NearbyFacility(
      osmId: '$type/$id',
      category: category,
      latitude: position.latitude,
      longitude: position.longitude,
      distanceMeters: Distance(roundResult: false)
          .as(LengthUnit.Meter, origin, position),
      name: text('name'),
      address: address.isEmpty ? null : address,
      phone: text('contact:phone') ?? text('phone'),
      website: text('contact:website') ?? text('website'),
      openingHours: text('opening_hours'),
    );
  }
}

/// This adapter is never inserted into the heritage-place catalog or Firestore.
class FacilityDestination implements RouteDestination {
  const FacilityDestination(this.facility);
  final NearbyFacility facility;
  @override
  String get id => 'osm/${facility.osmId}';
  @override
  String get name => facility.name ?? 'Unnamed facility';
  @override
  bool get hasName => facility.name != null;
  @override
  String get subtitle => facility.address ?? '';
  @override
  double get latitude => facility.latitude;
  @override
  double get longitude => facility.longitude;
}
