import '../../../core/firebase/cloud_values.dart';

class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userDisplayName,
    required this.rating,
    required this.comment,
    this.createdAt,
    this.updatedAt,
  });
  final String id, placeId, userId, userDisplayName, comment;
  final int rating;
  final DateTime? createdAt, updatedAt;
  static const maxCommentLength = 1000;
  static String publicName(String name) =>
      name.trim().isEmpty || name.contains('@')
      ? 'Traveler'
      : name.trim().substring(0, name.trim().length.clamp(0, 80));
  static String? validate(int? rating, String comment) =>
      rating == null || rating < 1 || rating > 5
      ? 'Choose a rating from 1 to 5.'
      : comment.trim().isEmpty
      ? 'Write a comment.'
      : comment.trim().length > maxCommentLength
      ? 'Use at most 1000 characters.'
      : null;
  bool get isValid =>
      id == userId &&
      placeId.isNotEmpty &&
      userId.isNotEmpty &&
      validate(rating, comment) == null;
  Map<String, Object?> toMap() => {
    'id': id,
    'placeId': placeId,
    'userId': userId,
    'userDisplayName': publicName(userDisplayName),
    'rating': rating,
    'comment': comment.trim(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory PlaceReview.fromMap(Map<String, Object?> map) {
    final rating = CloudValues.number(map['rating']);
    return PlaceReview(
      id: CloudValues.text(map['id']),
      placeId: CloudValues.text(map['placeId']),
      userId: CloudValues.text(map['userId']),
      userDisplayName: publicName(CloudValues.text(map['userDisplayName'])),
      rating:
          rating != null &&
              rating.isFinite &&
              rating == rating.truncateToDouble() &&
              rating >= 1 &&
              rating <= 5
          ? rating.toInt()
          : 0,
      comment: CloudValues.text(map['comment']),
      createdAt: CloudValues.optionalDate(map['createdAt']),
      updatedAt: CloudValues.optionalDate(map['updatedAt']),
    );
  }
}

class ReviewFeed {
  const ReviewFeed({this.reviews = const [], this.loading = false, this.error});
  final List<PlaceReview> reviews;
  final bool loading;
  final String? error;
  int get reviewCount => reviews.length;
  double get averageRating => reviews.isEmpty
      ? 0
      : reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
}
