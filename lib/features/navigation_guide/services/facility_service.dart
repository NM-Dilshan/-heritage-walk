import '../models/facility.dart';

class FacilityService {
  static const filters = [
    'All',
    'Food',
    'Restrooms',
    'Parking',
    'Medical',
    'ATM',
    'Police',
  ];
  // Fictional generic examples. Not verified nearby businesses or care services.
  static const _facilities = [
    Facility(
      id: 'restaurant',
      name: 'Demo Restaurant',
      type: FacilityType.restaurant,
      distanceKm: 0.4,
      description: 'Illustrative place for a meal.',
      isOpen: true,
    ),
    Facility(
      id: 'cafe',
      name: 'Demo Cafe',
      type: FacilityType.cafe,
      distanceKm: 0.3,
      description: 'Illustrative refreshment stop.',
      isOpen: false,
    ),
    Facility(
      id: 'restroom',
      name: 'Demo Restroom',
      type: FacilityType.restroom,
      distanceKm: 0.2,
      description: 'Illustrative restroom listing.',
      isOpen: true,
    ),
    Facility(
      id: 'parking',
      name: 'Demo Parking',
      type: FacilityType.parking,
      distanceKm: 0.5,
      description: 'Illustrative parking listing.',
      isOpen: true,
    ),
    Facility(
      id: 'medical',
      name: 'Demo Medical Facility',
      type: FacilityType.hospital,
      distanceKm: 1.2,
      description: 'Example only; not a verified medical facility.',
      isOpen: true,
    ),
    Facility(
      id: 'atm',
      name: 'Demo ATM',
      type: FacilityType.atm,
      distanceKm: 0.8,
      description: 'Illustrative ATM listing.',
      isOpen: true,
    ),
    Facility(
      id: 'police',
      name: 'Demo Police Station',
      type: FacilityType.police,
      distanceKm: 1.5,
      description: 'Example only; not a verified police station.',
      isOpen: true,
    ),
    Facility(
      id: 'info',
      name: 'Demo Information Point',
      type: FacilityType.information,
      distanceKm: 0.1,
      description: 'Illustrative visitor-information listing.',
      isOpen: true,
    ),
  ];
  List<Facility> getFacilities() => List.unmodifiable(_facilities);
  List<Facility> getFacilitiesByType(FacilityType type) =>
      _facilities.where((facility) => facility.type == type).toList();
  List<Facility> searchFacilities(String query, {String filter = 'All'}) {
    final term = query.trim().toLowerCase();
    return _facilities
        .where(
          (facility) =>
              '${facility.name} ${facility.type.name} ${facility.description}'
                  .toLowerCase()
                  .contains(term) &&
              switch (filter) {
                'Food' => [
                  FacilityType.restaurant,
                  FacilityType.cafe,
                ].contains(facility.type),
                'Restrooms' => facility.type == FacilityType.restroom,
                'Parking' => facility.type == FacilityType.parking,
                'Medical' => facility.type == FacilityType.hospital,
                'ATM' => facility.type == FacilityType.atm,
                'Police' => facility.type == FacilityType.police,
                _ => true,
              },
        )
        .toList();
  }
}
