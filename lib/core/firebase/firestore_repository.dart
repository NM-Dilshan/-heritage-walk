import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth_profile/models/user_profile.dart';
import '../../features/group_support/models/group_member.dart';
import '../../features/group_support/models/tour_group.dart';
import 'data_repository.dart';
import 'cloud_values.dart';
import 'backend_error.dart';
import 'sync_controller.dart' show cloudEqual;

class FirestoreRepository implements DataRepository {
  FirestoreRepository(this.db);
  final FirebaseFirestore db;
  Query<Map<String, dynamic>> _query(String uid, String collection) =>
      collection == 'groups'
      ? db.collection('groups').where('memberIds', arrayContains: uid)
      : db.collection('users').doc(uid).collection(collection);
  CloudDocuments _documents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String collection,
  ) => {
    for (final document in snapshot.docs)
      document.id: _decode(document.id, document.data(), collection),
  };
  Map<String, Object?> _decode(
    String id,
    Map<String, dynamic> data,
    String collection,
  ) {
    final result = CloudValues.normalize(data)..['id'] = id;
    if (collection == 'groups' && result['members'] is Map) {
      result['members'] = CloudValues.map(result['members']).entries
          .map((entry) => {...CloudValues.map(entry.value), 'id': entry.key})
          .toList();
    }
    return result;
  }

  @override
  Future<CloudDocuments> load(String uid, String collection) async =>
      _documents(
        await _query(
          uid,
          collection,
        ).get(const GetOptions(source: Source.server)),
        collection,
      );
  @override
  Stream<CloudDocuments> watch(String uid, String collection) =>
      _query(uid, collection)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map((snapshot) => _documents(snapshot, collection));
  @override
  String newId() => db.collection('groups').doc().id;
  @override
  Future<void> write(
    String uid,
    String collection,
    CloudDocuments before,
    CloudDocuments after,
  ) async {
    if (collection == 'groups') {
      for (final id in {...before.keys, ...after.keys}) {
        if (cloudEqual(before[id], after[id])) continue;
        await _group(uid, before[id], after[id]);
      }
      return;
    }
    final batch = db.batch();
    var changes = 0;
    for (final id in {...before.keys, ...after.keys}) {
      if (cloudEqual(before[id], after[id])) continue;
      final reference = db
          .collection('users')
          .doc(uid)
          .collection(collection)
          .doc(id);
      final data = after[id];
      if (data == null) {
        batch.delete(reference);
      } else {
        batch.set(reference, {
          ...CloudValues.timestamps(data),
          if (before[id] == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      changes++;
    }
    if (changes > 0) await batch.commit();
  }

  Map<String, dynamic> _members(Map<String, Object?> group) => {
    for (final value in CloudValues.list(group['members']))
      CloudValues.text(CloudValues.map(value)['id']): CloudValues.timestamps(
        CloudValues.map(value),
      ),
  };
  Future<void> _group(
    String uid,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) async {
    final data = after ?? before!;
    final reference = db.collection('groups').doc(CloudValues.text(data['id']));
    final invite = db
        .collection('groupInvites')
        .doc(CloudValues.text(data['inviteCode']));
    if (before == null) {
      await db.runTransaction((transaction) async {
        if ((await transaction.get(invite)).exists) {
          throw const BackendFailure(
            'Invite code collision. Please create the group again.',
          );
        }
        final members = _members(after!);
        transaction.set(reference, {
          ...CloudValues.timestamps(after),
          'members': members,
          'memberIds': members.keys.toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(invite, {'groupId': reference.id, 'leaderId': uid});
      });
    } else if (after == null) {
      final batch = db.batch()
        ..delete(reference)
        ..delete(invite);
      await batch.commit();
    } else {
      final oldMembers = _members(before), newMembers = _members(after);
      final changes = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final key in [
        'name',
        'destinationPlaceId',
        'destinationName',
        'leaderName',
      ]) {
        if (before[key] != after[key]) changes[key] = after[key];
      }
      for (final id in {...oldMembers.keys, ...newMembers.keys}) {
        if (!mapEquals(oldMembers[id], newMembers[id])) {
          changes['members.$id'] = newMembers[id] ?? FieldValue.delete();
        }
      }
      if (!setEquals(oldMembers.keys.toSet(), newMembers.keys.toSet())) {
        changes['memberIds'] = newMembers.keys.toList();
        changes['memberOperationId'] = {...oldMembers.keys, ...newMembers.keys}
            .singleWhere(
              (id) => oldMembers.containsKey(id) != newMembers.containsKey(id),
            );
      }
      await reference.update(changes);
    }
  }

  @override
  Future<TourGroup?> join(String code, UserProfile profile) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^HW-[A-Z0-9]{4,32}$').hasMatch(normalized)) return null;
    final invite = await db
        .collection('groupInvites')
        .doc(normalized)
        .get(const GetOptions(source: Source.server));
    if (!invite.exists) return null;
    final reference = db
        .collection('groups')
        .doc(CloudValues.text(invite.data()?['groupId']));
    // A blind atomic update permits code holders to join without exposing groups
    // to nonmembers. Rules require this exact code and a self-only member change.
    final member = GroupMember(
      id: profile.id,
      name: profile.fullName,
      avatarPath: profile.photoPath,
      lastUpdated: DateTime.now(),
    );
    await reference.update({
      'members.${profile.id}': CloudValues.timestamps(
        member.toMap()
          ..remove('isOnline')
          ..remove('relativeX')
          ..remove('relativeY'),
      ),
      'memberIds': FieldValue.arrayUnion([profile.id]),
      'joinCode': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    return TourGroup.fromMap(_decode(snapshot.id, snapshot.data()!, 'groups'));
  }
}
