enum FacilityType {
  restaurant,
  cafe,
  restroom,
  parking,
  hospital,
  atm,
  police,
  information,
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.distanceKm,
    required this.description,
    required this.isOpen,
    this.openingHours,
  });
  final String id, name, description;
  final FacilityType type;
  final double distanceKm;
  final bool isOpen;
  final String? openingHours;
}
