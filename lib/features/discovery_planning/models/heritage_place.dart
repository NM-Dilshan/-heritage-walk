class HeritagePlace {
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
  });
  final String id,
      name,
      city,
      district,
      category,
      shortDescription,
      description,
      imagePath;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final double? latitude, longitude;
  final String? openingHours, entranceFee;
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
  };
  factory HeritagePlace.fromMap(Map<String, Object?> map) => HeritagePlace(
    id: map['id'] as String,
    name: map['name'] as String,
    city: map['city'] as String,
    district: map['district'] as String,
    category: map['category'] as String,
    shortDescription: map['shortDescription'] as String,
    description: map['description'] as String,
    imagePath: map['imagePath'] as String,
    rating: (map['rating'] as num).toDouble(),
    reviewCount: (map['reviewCount'] as num).toInt(),
    isFeatured: map['isFeatured'] as bool? ?? false,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    openingHours: map['openingHours'] as String?,
    entranceFee: map['entranceFee'] as String?,
  );
}
