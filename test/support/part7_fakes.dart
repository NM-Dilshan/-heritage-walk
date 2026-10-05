import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:heritage_walk/core/firebase/account_repository.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/firebase/data_repository.dart';
import 'package:heritage_walk/core/firebase/cloud_values.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/models/group_member.dart';

class FakeAccount implements AccountRepository {
  final profiles = <String, UserProfile>{};
  final passwords = <String, String>{};
  String? current;
  final events = StreamController<String?>.broadcast(sync: true);
  Completer<void>? gate;
  Completer<void>? restoreGate;
  String? failureCode;
  String? receivedPassword;
  int calls = 0;
  @override
  Stream<String?> get authChanges => events.stream;
  @override
  Future<UserProfile?> restore() async {
    if (restoreGate != null) {
      await restoreGate!.future;
    }
    return current == null ? null : profiles[current];
  }

  @override
  Future<UserProfile> register(
    String name,
    String email,
    String password,
  ) async {
    calls++;
    receivedPassword = password;
    if (gate != null) await gate!.future;
    if (failureCode != null) throw FirebaseAuthException(code: failureCode!);
    if (passwords.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    final uid = 'uid-${profiles.length + 1}';
    final profile = UserProfile(id: uid, fullName: name, email: email);
    profiles[uid] = profile;
    passwords[email] = password;
    current = uid;
    events.add(uid);
    return profile;
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    calls++;
    receivedPassword = password;
    if (gate != null) await gate!.future;
    if (failureCode != null) throw FirebaseAuthException(code: failureCode!);
    if (passwords[email] != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    final profile = profiles.values.singleWhere(
      (profile) => profile.email == email,
    );
    current = profile.id;
    events.add(current);
    return profile;
  }

  @override
  Future<void> update(UserProfile profile) async {
    if (profile.id != current) throw const BackendFailure('Own profile only');
    profiles[profile.id] = profile;
  }

  @override
  Future<void> resetPassword(String email) async {
    calls++;
  }

  @override
  Future<void> signOut() async {
    current = null;
    events.add(null);
  }
}

class FakeData implements DataRepository {
  final private = <String, Map<String, CloudDocuments>>{};
  final groups = <String, Map<String, Object?>>{};
  final streams = <String, StreamController<CloudDocuments>>{};
  int sequence = 0, writes = 0;
  bool failWrites = false, failLoads = false;
  Completer<void>? gate;
  @override
  String newId() => 'cloud-${++sequence}';
  @override
  Future<CloudDocuments> load(String uid, String collection) async {
    if (failLoads) throw const BackendFailure('Unable to load saved data.');
    if (collection == 'groups') {
      return {
        for (final entry in groups.entries)
          if (CloudValues.list(entry.value['members'])
              .any((member) => CloudValues.map(member)['id'] == uid))
            entry.key: entry.value,
      };
    }
    return Map.of(private[uid]?[collection] ?? {});
  }

  @override
  Stream<CloudDocuments> watch(String uid, String collection) =>
      (streams['$uid/$collection'] ??= StreamController.broadcast()).stream;
  @override
  Future<void> write(
    String uid,
    String collection,
    CloudDocuments before,
    CloudDocuments after,
  ) async {
    if (gate != null) await gate!.future;
    if (failWrites) throw const BackendFailure('Save failed.');
    writes++;
    if (collection == 'groups') {
      for (final id in {...before.keys, ...after.keys}) {
        final old = groups[id];
        if (old != null &&
            old['leaderId'] != uid &&
            after[id]?['name'] != old['name']) {
          throw const BackendFailure('Leader only');
        }
        if (after[id] == null) {
          groups.remove(id);
        } else {
          groups[id] = after[id]!;
        }
      }
    } else {
      (private[uid] ??= {})[collection] = Map.of(after);
    }
  }

  @override
  Future<TourGroup?> join(String code, UserProfile profile) async {
    final data = groups.values
        .where((group) => group['inviteCode'] == code.trim().toUpperCase())
        .firstOrNull;
    if (data == null) return null;
    final group = TourGroup.fromMap(data);
    if (group.members.any((member) => member.id == profile.id)) return group;
    final joined = group.copyWith(
      members: [
        ...group.members,
        GroupMember(id: profile.id, name: profile.fullName),
      ],
    );
    groups[group.id] = joined.toMap();
    return joined;
  }
}
