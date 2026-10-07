import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:heritage_walk/features/navigation_guide/models/facility.dart';
import 'package:heritage_walk/features/navigation_guide/services/facility_service.dart';

const facilityOrigin = LatLng(6.032, 80.218);
Map<String, Object?> osmFacility(
  String amenity, {
  int id = 1,
  String? name = 'Test facility',
  double lat = 6.033,
  double lon = 80.218,
  String type = 'node',
  Map<String, Object?> tags = const {},
}) => {
  'type': type,
  'id': id,
  if (type == 'node') ...{
    'lat': lat,
    'lon': lon,
  } else
    'center': {'lat': lat, 'lon': lon},
  'tags': {'amenity': amenity, 'name': ?name, ...tags},
};
List<Map<String, Object?>> facilityFixtures() => [
  osmFacility('hospital', name: 'Test Hospital', id: 1),
  osmFacility('clinic', name: 'Test Clinic', id: 2, lat: 6.034),
  osmFacility('doctors', name: 'Test Doctors', id: 3, lat: 6.035),
  osmFacility('pharmacy', name: 'Test Pharmacy', id: 4),
  osmFacility('police', name: 'Test Police', id: 5),
  osmFacility('atm', name: 'Test ATM', id: 6),
  osmFacility('restaurant', name: 'Test Restaurant', id: 7),
  osmFacility('cafe', name: 'Test Cafe', id: 8),
  osmFacility('fast_food', name: 'Test Fast Food', id: 9),
  osmFacility('toilets', name: 'Test Toilet', id: 10),
  osmFacility('fuel', name: 'Test Fuel', id: 11),
  osmFacility('parking', name: 'Test Parking', id: 12),
];

class FakeNearbyFacilityService extends NearbyFacilityService {
  List<Map<String, Object?>> elements = facilityFixtures();
  FacilityFailure? failure;
  Completer<List<NearbyFacility>>? pending;
  final requests =
      <
        ({LatLng origin, FacilityCategory category, int radius, bool refresh})
      >[];
  @override
  Future<List<NearbyFacility>> search({
    required LatLng origin,
    required FacilityCategory category,
    int radiusMeters = 5000,
    bool refresh = false,
  }) async {
    requests.add((
      origin: origin,
      category: category,
      radius: radiusMeters,
      refresh: refresh,
    ));
    if (failure != null) throw FacilityException(failure!);
    return pending?.future ??
        OverpassNearbyFacilityService.decode(
          jsonEncode({'elements': elements}),
          origin,
          category,
          radiusMeters,
        );
  }
}
