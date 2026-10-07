import '../../../core/firebase/cloud_values.dart';
import '../../navigation_guide/models/navigation_destination.dart';

class HeritagePlace implements RouteDestination {
  const HeritagePlace({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.category,
    required this.shortDescription,
    required this.description,
    required this.imagePath,
    required this.rating,
    required this.reviewCount,
    this.isFeatured = false,
    this.latitude,
    this.longitude,
    this.openingHours,
    this.entranceFee,
    this.address = '',
    this.historicalPeriod = '',
    this.accessibilityInfo = '',
    this.highlights = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.isActive = true,
  });
  @override
  final String id;
  @override
  final String name;
  final String city,
      district,
      category,
      shortDescription,
      description,
      imagePath;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  @override
  final double? latitude, longitude;
  final String? openingHours, entranceFee;
  final String address,
      historicalPeriod,
      accessibilityInfo,
      createdBy,
      updatedBy;
  final List<String> highlights;
  final DateTime? createdAt, updatedAt;
  final bool isActive;
  @override
  String get subtitle => '$city, $district';
  @override
  bool get hasName => true;
  HeritagePlace copyWith({String? name, bool? isActive}) =>
      HeritagePlace.fromMap({...toMap(), 'name': ?name, 'isActive': ?isActive});
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'city': city,
    'district': district,
    'category': category,
    'shortDescription': shortDescription,
    'description': description,
    'imagePath': imagePath,
    'rating': rating,
    'reviewCount': reviewCount,
    'isFeatured': isFeatured,
    'latitude': latitude,
    'longitude': longitude,
    'openingHours': openingHours,
    'entranceFee': entranceFee,
    'address': address,
    'historicalPeriod': historicalPeriod,
    'accessibilityInfo': accessibilityInfo,
    'highlights': highlights,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'isActive': isActive,
  };
  factory HeritagePlace.fromMap(Map<String, Object?> map) => HeritagePlace(
    id: CloudValues.text(map['id']),
    address: CloudValues.text(map['address']),
    historicalPeriod: CloudValues.text(map['historicalPeriod']),
    accessibilityInfo: CloudValues.text(map['accessibilityInfo']),
    highlights: CloudValues.list(map['highlights'])
        .whereType<String>()
        .toList(),
    createdAt: CloudValues.optionalDate(map['createdAt']),
    updatedAt: CloudValues.optionalDate(map['updatedAt']),
    createdBy: CloudValues.text(map['createdBy']),
    updatedBy: CloudValues.text(map['updatedBy']),
    isActive: CloudValues.boolean(map['isActive'], true),
    name: CloudValues.text(map['name']),
    city: CloudValues.text(map['city']),
    district: CloudValues.text(map['district']),
    category: CloudValues.text(map['category']),
    shortDescription: CloudValues.text(map['shortDescription']),
    description: CloudValues.text(map['description']),
    imagePath: CloudValues.text(map['imagePath']),
    rating: (_finiteNumber(map['rating']) ?? 0),
    reviewCount: (_finiteNumber(map['reviewCount'])?.toInt() ?? 0),
    isFeatured: CloudValues.boolean(map['isFeatured'], false),
    latitude: _coordinate(map['latitude'], 90),
    longitude: _coordinate(map['longitude'], 180),
    openingHours: (map['openingHours'] is String
        ? CloudValues.text(map['openingHours'])
        : null),
    entranceFee: (map['entranceFee'] is String
        ? CloudValues.text(map['entranceFee'])
        : null),
  );
  static double? _coordinate(Object? value, double limit) {
    final number = _finiteNumber(value);
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  static double? _finiteNumber(Object? value) {
    final number = CloudValues.number(value);
    return number != null && number.isFinite ? number : null;
  }
}
