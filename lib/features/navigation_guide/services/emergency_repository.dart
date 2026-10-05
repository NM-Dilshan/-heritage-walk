import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/backend_error.dart';
import '../../../core/firebase/cloud_values.dart';
import '../models/emergency_contact.dart';

abstract interface class EmergencyRepository {
  Stream<List<EmergencyContact>> watch({bool publicOnly = true});
  Future<List<EmergencyContact>> list({bool publicOnly = true});
  String newId();
  Future<bool> create(EmergencyContact contact, String uid);
  Future<void> update(EmergencyContact contact, String uid);
  Future<void> delete(String id);
}

List<EmergencyContact> sortContacts(Iterable<EmergencyContact> contacts) =>
    contacts.toList()..sort((a, b) {
      final priority = a.priority.compareTo(b.priority);
      return priority == 0 ? a.name.compareTo(b.name) : priority;
    });

class FirestoreEmergencyRepository implements EmergencyRepository {
  FirestoreEmergencyRepository(this.db);
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> get _contacts =>
      db.collection('emergencyContacts');
  Query<Map<String, dynamic>> _query(bool publicOnly) => publicOnly
      ? _contacts
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true)
      : _contacts;
  List<EmergencyContact> _decode(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => sortContacts(
    snapshot.docs.map(
      (doc) => EmergencyContact.fromMap({...doc.data(), 'id': doc.id}),
    ),
  );
  @override
  Stream<List<EmergencyContact>> watch({bool publicOnly = true}) =>
      _query(publicOnly)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_decode);
  @override
  Future<List<EmergencyContact>> list({bool publicOnly = true}) async =>
      _decode(
        await _query(publicOnly).get(const GetOptions(source: Source.server)),
      );
  @override
  String newId() => _contacts.doc().id;
  @override
  Future<bool> create(EmergencyContact contact, String uid) =>
      db.runTransaction((tx) async {
        final ref = _contacts.doc(contact.id);
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          ...CloudValues.timestamps(contact.toMap()),
          'createdBy': uid,
          'updatedBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
  @override
  Future<void> update(EmergencyContact contact, String uid) =>
      db.runTransaction((tx) async {
        final ref = _contacts.doc(contact.id);
        if (!(await tx.get(ref)).exists) {
          throw const BackendFailure(
            'This contact no longer exists. Reload the list.',
          );
        }
        final data = CloudValues.timestamps(contact.toMap())
          ..remove('createdAt')
          ..remove('createdBy');
        tx.update(ref, {
          ...data,
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
  @override
  Future<void> delete(String id) => db.runTransaction((tx) async {
    final ref = _contacts.doc(id);
    if (!(await tx.get(ref)).exists) {
      throw const BackendFailure('This contact was already deleted.');
    }
    tx.delete(ref);
  });
}

class InMemoryEmergencyRepository implements EmergencyRepository {
  InMemoryEmergencyRepository([Iterable<EmergencyContact> initial = const []]) {
    for (final contact in initial) {
      items[contact.id] = contact;
    }
  }
  final Map<String, EmergencyContact> items = {};
  final changes = StreamController<void>.broadcast(sync: true);
  int _sequence = 0;
  @override
  String newId() {
    var id = 'contact-${++_sequence}';
    while (items.containsKey(id)) {
      id = 'contact-${++_sequence}';
    }
    return id;
  }

  List<EmergencyContact> _read(bool publicOnly) => sortContacts(
    items.values.where((c) => !publicOnly || c.isActive && c.isVerified),
  );
  @override
  Future<List<EmergencyContact>> list({bool publicOnly = true}) async =>
      _read(publicOnly);
  @override
  Stream<List<EmergencyContact>> watch({bool publicOnly = true}) =>
      Stream.multi((controller) {
        final sub = changes.stream.listen(
          (_) => controller.add(_read(publicOnly)),
        );
        controller.add(_read(publicOnly));
        controller.onCancel = sub.cancel;
      });
  @override
  Future<bool> create(EmergencyContact contact, String uid) async {
    if (items.containsKey(contact.id)) return false;
    final now = DateTime.now().toUtc();
    items[contact.id] = EmergencyContact.fromMap({
      ...contact.toMap(),
      'createdAt': now,
      'updatedAt': now,
      'createdBy': uid,
      'updatedBy': uid,
    });
    changes.add(null);
    return true;
  }

  @override
  Future<void> update(EmergencyContact contact, String uid) async {
    final old = items[contact.id];
    if (old == null) {
      throw const BackendFailure('This contact no longer exists.');
    }
    items[contact.id] = EmergencyContact.fromMap({
      ...contact.toMap(),
      'createdAt': old.createdAt,
      'createdBy': old.createdBy,
      'updatedAt': DateTime.now().toUtc(),
      'updatedBy': uid,
    });
    changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    if (items.remove(id) == null) {
      throw const BackendFailure('This contact no longer exists.');
    }
    changes.add(null);
  }

  Future<void> dispose() => changes.close();
}
