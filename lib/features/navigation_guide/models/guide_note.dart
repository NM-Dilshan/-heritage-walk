import '../../../core/firebase/cloud_values.dart';

class GuideNote {
  const GuideNote({
    required this.id,
    required this.placeId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, placeId, text;
  final DateTime createdAt, updatedAt;
  GuideNote updated(String text, DateTime now) => GuideNote(
    id: id,
    placeId: placeId,
    text: text,
    createdAt: createdAt,
    updatedAt: now,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'placeId': placeId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory GuideNote.fromMap(Map<String, Object?> map) => GuideNote(
    id: CloudValues.text(map['id']),
    placeId: CloudValues.text(map['placeId']),
    text: CloudValues.text(map['text']),
    createdAt: CloudValues.date(map['createdAt']),
    updatedAt: CloudValues.date(map['updatedAt']),
  );
}
