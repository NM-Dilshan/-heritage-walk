import 'heritage_place.dart';

class TourPlan {
  TourPlan({
    required this.destination,
    required this.date,
    required this.duration,
    required List<String> interests,
    required this.travelStyle,
  }) : interests = List.unmodifiable(interests);
  final String destination, duration, travelStyle;
  final DateTime date;
  final List<String> interests;
  Map<String, Object?> toMap() => {
    'destination': destination,
    'date': date.toIso8601String(),
    'duration': duration,
    'interests': interests,
    'travelStyle': travelStyle,
  };
  factory TourPlan.fromMap(Map<String, Object?> map) => TourPlan(
    destination: map['destination'] as String,
    date: DateTime.parse(map['date'] as String),
    duration: map['duration'] as String,
    interests: (map['interests'] as List).cast<String>(),
    travelStyle: map['travelStyle'] as String,
  );
}

class Itinerary {
  Itinerary({
    required this.id,
    required this.title,
    required this.plan,
    required List<HeritagePlace> places,
    required this.createdAt,
    this.isSaved = false,
  }) : places = List.unmodifiable(places);
  final String id, title;
  final TourPlan plan;
  final List<HeritagePlace> places;
  final bool isSaved;
  final DateTime createdAt;
  String get destination => plan.destination;
  DateTime get date => plan.date;
  String get duration => plan.duration;
  List<String> get interests => plan.interests;
  String get travelStyle => plan.travelStyle;
  Itinerary copyWith({String? title, bool? isSaved}) => Itinerary(
    id: id,
    title: title ?? this.title,
    plan: plan,
    places: places,
    createdAt: createdAt,
    isSaved: isSaved ?? this.isSaved,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    ...plan.toMap(),
    'places': places.map((place) => place.toMap()).toList(),
    'isSaved': isSaved,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Itinerary.fromMap(Map<String, Object?> map) => Itinerary(
    id: map['id'] as String,
    title: map['title'] as String,
    plan: TourPlan.fromMap(map),
    places: (map['places'] as List)
        .map(
          (place) =>
              HeritagePlace.fromMap(Map<String, Object?>.from(place as Map)),
        )
        .toList(),
    isSaved: map['isSaved'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}
