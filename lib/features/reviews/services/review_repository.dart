import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/backend_error.dart';
import '../models/place_review.dart';

abstract interface class ReviewRepository {
  Stream<List<PlaceReview>> watchPlace(String placeId);
  Stream<List<PlaceReview>> watchAll();
  Future<bool> create(PlaceReview review, String uid);
  Future<void> update(PlaceReview review, String uid);
  Future<void> delete(
    String placeId,
    String reviewId,
    String uid, {
    bool moderate = false,
  });
}

class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository(this.db);
  final FirebaseFirestore db;
  DocumentReference<Map<String, dynamic>> _ref(String place, String uid) =>
      db.collection('places').doc(place).collection('reviews').doc(uid);
  List<PlaceReview> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .where(
            (doc) =>
                doc.reference.path.split('/').length == 4 &&
                doc.reference.path.startsWith('places/'),
          )
          .map(
            (doc) => PlaceReview.fromMap({
              ...doc.data(),
              'id': doc.id,
              'placeId': doc.reference.parent.parent!.id,
            }),
          )
          .where((r) => r.isValid)
          .toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
  Stream<List<PlaceReview>> _watch(Query<Map<String, dynamic>> query) => query
      .snapshots(includeMetadataChanges: true)
      .where((s) => !s.metadata.hasPendingWrites)
      .map(_decode);
  @override
  Stream<List<PlaceReview>> watchPlace(String placeId) =>
      _watch(db.collection('places').doc(placeId).collection('reviews'));
  @override
  Stream<List<PlaceReview>> watchAll() => _watch(db.collectionGroup('reviews'));
  @override
  Future<bool> create(PlaceReview review, String uid) {
    _validate(review, uid);
    return db.runTransaction((tx) async {
      final ref = _ref(review.placeId, uid);
      if ((await tx.get(ref)).exists) return false;
      tx.set(ref, {
        ...review.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<void> update(PlaceReview review, String uid) {
    _validate(review, uid);
    return db.runTransaction((tx) async {
      final ref = _ref(review.placeId, uid);
      if (!(await tx.get(ref)).exists) {
        throw const BackendFailure(
          'Your review no longer exists. Reload reviews.',
        );
      }
      tx.update(ref, {
        'rating': review.rating,
        'comment': review.comment.trim(),
        'userDisplayName': PlaceReview.publicName(review.userDisplayName),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> delete(
    String placeId,
    String reviewId,
    String uid, {
    bool moderate = false,
  }) async {
    if (reviewId != uid && !moderate) {
      throw const BackendFailure('You can only delete your own review.');
    }
    await _ref(
      placeId,
      reviewId,
    ).delete(); // Trusted role/ownership is enforced by Firestore rules.
  }
}

void _validate(PlaceReview review, String uid) {
  if (!review.isValid || review.id != uid || review.userId != uid) {
    throw const BackendFailure('Check review ownership, rating and comment.');
  }
}

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository([Iterable<PlaceReview> initial = const []]) {
    for (final r in initial) {
      _items['${r.placeId}/${r.id}'] = r;
    }
  }
  final _items = <String, PlaceReview>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  List<PlaceReview> _list() => _items.values.where((r) => r.isValid).toList()
    ..sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
  Stream<List<PlaceReview>> _watch(String? place) => Stream.multi((controller) {
    void emit() => controller.add(
      _list().where((r) => place == null || r.placeId == place).toList(),
    );
    final sub = _changes.stream.listen((_) => emit());
    emit();
    controller.onCancel = sub.cancel;
  });
  @override
  Stream<List<PlaceReview>> watchPlace(String placeId) => _watch(placeId);
  @override
  Stream<List<PlaceReview>> watchAll() => _watch(null);
  @override
  Future<bool> create(PlaceReview review, String uid) async {
    _validate(review, uid);
    final key = '${review.placeId}/$uid';
    if (_items.containsKey(key)) return false;
    _items[key] = PlaceReview.fromMap({
      ...review.toMap(),
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    _changes.add(null);
    return true;
  }

  @override
  Future<void> update(PlaceReview review, String uid) async {
    _validate(review, uid);
    final key = '${review.placeId}/$uid';
    final old = _items[key];
    if (old == null) {
      throw const BackendFailure(
        'Your review no longer exists. Reload reviews.',
      );
    }
    _items[key] = PlaceReview.fromMap({
      ...review.toMap(),
      'createdAt': old.createdAt,
      'updatedAt': DateTime.now(),
    });
    _changes.add(null);
  }

  @override
  Future<void> delete(
    String placeId,
    String reviewId,
    String uid, {
    bool moderate = false,
  }) async {
    if (reviewId != uid && !moderate) {
      throw const BackendFailure('You can only delete your own review.');
    }
    _items.remove('$placeId/$reviewId');
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
