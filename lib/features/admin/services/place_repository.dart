import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/backend_error.dart';
import '../../../core/firebase/cloud_values.dart';
import '../../discovery_planning/models/heritage_place.dart';

abstract interface class PlaceRepository {
  Stream<List<HeritagePlace>> watch({bool activeOnly = true});
  Future<List<HeritagePlace>> list({bool activeOnly = true});
  String newId();
  Future<bool> create(HeritagePlace place, String uid);
  Future<void> update(HeritagePlace place, String uid);
  Future<void> delete(String id);
}

abstract interface class RoleRepository {
  Stream<String> watch(String uid);
}

class FirestoreRoleRepository implements RoleRepository {
  FirestoreRoleRepository(this.db);
  final FirebaseFirestore db;
  @override
  Stream<String> watch(String uid) => db
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      // Privileged UI requires a server-confirmed role, never an offline cache.
      .map(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites &&
                snapshot.data()?['role'] == 'admin'
            ? 'admin'
            : 'user',
      );
}

class FirestorePlaceRepository implements PlaceRepository {
  FirestorePlaceRepository(this.db);
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> get _places =>
      db.collection('places');
  Query<Map<String, dynamic>> _query(bool activeOnly) =>
      activeOnly ? _places.where('isActive', isEqualTo: true) : _places;
  List<HeritagePlace> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map((doc) => HeritagePlace.fromMap({...doc.data(), 'id': doc.id}))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  @override
  Stream<List<HeritagePlace>> watch({bool activeOnly = true}) =>
      _query(activeOnly)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_decode);
  @override
  Future<List<HeritagePlace>> list({bool activeOnly = true}) async => _decode(
    await _query(activeOnly).get(const GetOptions(source: Source.server)),
  );
  @override
  String newId() => _places.doc().id;
  @override
  Future<bool> create(HeritagePlace place, String uid) =>
      db.runTransaction((tx) async {
        final ref = _places.doc(place.id);
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          ...CloudValues.timestamps(place.toMap()),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'updatedBy': uid,
        });
        return true;
      });
  @override
  Future<void> update(HeritagePlace place, String uid) =>
      db.runTransaction((tx) async {
        final ref = _places.doc(place.id);
        final old = await tx.get(ref);
        if (!old.exists) {
          throw const BackendFailure(
            'This place no longer exists. Reload the catalog.',
          );
        }
        final values = CloudValues.timestamps(place.toMap())
          ..remove('createdAt')
          ..remove('createdBy');
        tx.update(ref, {
          ...values,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      });
  @override
  Future<void> delete(String id) => db.runTransaction((tx) async {
    final ref = _places.doc(id);
    if (!(await tx.get(ref)).exists) {
      throw const BackendFailure(
        'This place was already deleted. Reload the catalog.',
      );
    }
    tx.delete(ref);
  });
}

/// Isolated catalog used by tests; no Firebase calls or startup seeding.
class InMemoryPlaceRepository implements PlaceRepository {
  InMemoryPlaceRepository([Iterable<HeritagePlace> initial = const []]) {
    for (final place in initial) {
      _items[place.id] = place;
    }
  }
  final Map<String, HeritagePlace> _items = {};
  final _changes = StreamController<void>.broadcast(sync: true);
  int _sequence = 0;
  @override
  String newId() {
    var id = 'place-${++_sequence}';
    while (_items.containsKey(id)) {
      id = 'place-${++_sequence}';
    }
    return id;
  }

  @override
  Future<List<HeritagePlace>> list({bool activeOnly = true}) async =>
      _items.values.where((place) => !activeOnly || place.isActive).toList();
  @override
  Stream<List<HeritagePlace>> watch({bool activeOnly = true}) =>
      Stream.multi((controller) {
        void emit() => controller.add(
          _items.values.where((p) => !activeOnly || p.isActive).toList(),
        );
        final sub = _changes.stream.listen((_) => emit());
        emit();
        controller.onCancel = sub.cancel;
      });
  @override
  Future<bool> create(HeritagePlace place, String uid) async {
    if (_items.containsKey(place.id)) return false;
    final now = DateTime.now().toUtc();
    _items[place.id] = HeritagePlace.fromMap({
      ...place.toMap(),
      'createdAt': now,
      'updatedAt': now,
      'createdBy': uid,
      'updatedBy': uid,
    });
    _changes.add(null);
    return true;
  }

  @override
  Future<void> update(HeritagePlace place, String uid) async {
    final old = _items[place.id];
    if (old == null) throw const BackendFailure('This place no longer exists.');
    _items[place.id] = HeritagePlace.fromMap({
      ...place.toMap(),
      'createdAt': old.createdAt,
      'createdBy': old.createdBy,
      'updatedAt': DateTime.now().toUtc(),
      'updatedBy': uid,
    });
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    if (_items.remove(id) == null) {
      throw const BackendFailure('This place no longer exists.');
    }
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
