import 'dart:async';

import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/navigation_guide/models/emergency_contact.dart';
import 'package:heritage_walk/features/navigation_guide/services/emergency_repository.dart';
import 'package:heritage_walk/features/navigation_guide/services/phone_launcher.dart';

const testContact = EmergencyContact(
  id: 'synthetic-contact',
  name: 'Synthetic Test Contact',
  description: 'Test fixture only, not a real emergency service.',
  phoneNumber: '+12025550123',
  category: 'other',
  isActive: true,
  isVerified: true,
  priority: 10,
);

class FakePhone implements PhoneLauncher {
  final uris = <Uri>[];
  bool result = true, throwsError = false;
  @override
  Future<bool> openDialer(Uri uri) async {
    uris.add(uri);
    if (throwsError) throw StateError('Native test failure');
    return result;
  }
}

class ControlledEmergency extends InMemoryEmergencyRepository {
  ControlledEmergency(super.initial);
  bool hold = false, fail = false, failWrite = false;
  Completer<void>? gate;
  int createCalls = 0;
  @override
  Stream<List<EmergencyContact>> watch({bool publicOnly = true}) => hold
      ? const Stream.empty()
      : fail
      ? Stream.error(const BackendFailure('Contacts could not be loaded.'))
      : super.watch(publicOnly: publicOnly);
  @override
  Future<bool> create(EmergencyContact contact, String uid) async {
    createCalls++;
    if (gate != null) await gate!.future;
    if (failWrite) throw const BackendFailure('Contact save failed.');
    return super.create(contact, uid);
  }
}

class FailingPlaceWrites extends InMemoryPlaceRepository {
  FailingPlaceWrites(super.initial);
  bool fail = true;
  @override
  Future<bool> create(HeritagePlace place, String uid) async {
    if (fail) throw const BackendFailure('Place save failed.');
    return super.create(place, uid);
  }

  @override
  Future<void> update(HeritagePlace place, String uid) async {
    if (fail) throw const BackendFailure('Place save failed.');
    return super.update(place, uid);
  }
}

class FakeLiveRoles implements RoleRepository {
  FakeLiveRoles(this.role);
  String role;
  final changes = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> watch(String uid) => Stream.multi((controller) {
    final sub = changes.stream.listen(controller.add);
    controller.add(role);
    controller.onCancel = sub.cancel;
  });
  void set(String value) {
    role = value;
    changes.add(value);
  }
}
