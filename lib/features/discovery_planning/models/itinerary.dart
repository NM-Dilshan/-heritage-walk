import '../../../core/firebase/cloud_values.dart';

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
    destination: CloudValues.text(map['destination']),
    date: CloudValues.date(map['date']),
    duration: CloudValues.text(map['duration']),
    interests: CloudValues.list(map['interests']).whereType<String>().toList(),
    travelStyle: CloudValues.text(map['travelStyle']),
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
    id: CloudValues.text(map['id']),
    title: CloudValues.text(map['title']),
    plan: TourPlan.fromMap(map),
    places: CloudValues.list(map['places'])
        .map((place) => HeritagePlace.fromMap(CloudValues.map(place)))
        .toList(),
    isSaved: CloudValues.boolean(map['isSaved'], false),
    createdAt: CloudValues.date(map['createdAt']),
  );
}
