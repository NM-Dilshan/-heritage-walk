import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/firebase/cloud_values.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/auth_profile/services/auth_validators.dart';
import 'package:heritage_walk/features/discovery_planning/models/itinerary.dart';
import 'package:heritage_walk/features/navigation_guide/models/guide_note.dart';
import 'package:heritage_walk/features/group_support/models/support_request.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/models/group_member.dart';

import 'support/part7_fakes.dart';

Future<AppServices> signed(FakeAccount account, FakeData data) async {
  final services = AppServices(account: account, data: data);
  await services.profile.ready;
  if (!services.profile.isAuthenticated) {
    await services.profile.register(
      fullName: 'Alice',
      email: 'alice@test.com',
      password: 'Secure123',
    );
  }
  return services;
}

void main() {
  test(
    'Calendar tour date keeps its chosen day while audit fields use timestamps',
    () {
      final calendar = DateTime(2026, 10, 8).toIso8601String();
      final converted = CloudValues.timestamps({
        'date': calendar,
        'createdAt': calendar,
      });
      expect(converted['date'], calendar);
      expect(converted['createdAt'], isA<Timestamp>());
    },
  );
  test('Cloud auth validates without contacting repository', () async {
    final account = FakeAccount();
    final services = AppServices(account: account, data: FakeData());
    addTearDown(services.dispose);
    await services.profile.ready;
    expect(
      () => services.profile.signIn('bad', password: '123456'),
      throwsA(isA<BackendFailure>()),
    );
    expect(
      () => services.profile.register(
        fullName: 'A',
        email: 'a@test.com',
        password: 'short',
      ),
      throwsA(isA<BackendFailure>()),
    );
    expect(account.calls, 0);
    expect(AuthValidators.password('123456'), isNull);
  });
  test(
    'Registration uses canonical UID and entered credentials with clean data',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      expect(services.profile.profile.id, 'uid-1');
      expect(services.profile.profile.fullName, 'Alice');
      expect(account.receivedPassword, 'Secure123');
      expect(services.discovery.favorites.getFavorites(), isEmpty);
      expect(services.groups.getGroups(), isEmpty);
      expect(data.writes, 0);
    },
  );
  test(
    'Login abstraction uses password, logout detaches without remote deletes',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      services.discovery.favorites.addFavorite(
        services.discovery.discovery.places.first,
      );
      await services.sync!.flush();
      final writes = data.writes;
      await services.profile.signOut();
      expect(services.profile.isAuthenticated, isFalse);
      expect(services.discovery.favorites.getFavorites(), isEmpty);
      expect(data.writes, writes);
      expect(data.private['uid-1']!['favorites'], isNotEmpty);
      await services.profile.signIn('alice@test.com', password: 'Secure123');
      expect(services.profile.isAuthenticated, isTrue);
      expect(services.discovery.favorites.getFavorites(), hasLength(1));
    },
  );
  test(
    'Auth restoration loads profile and user data without demo upload',
    () async {
      final account = FakeAccount(), data = FakeData();
      final first = await signed(account, data);
      first.language.setLanguage('ta');
      await first.sync!.flush();
      first.dispose();
      final restored = AppServices(account: account, data: data);
      addTearDown(restored.dispose);
      await restored.profile.ready;
      expect(restored.profile.isAuthenticated, isTrue);
      expect(restored.profile.profile.id, account.current);
      expect(restored.language.selectedLanguageCode, 'ta');
      expect(data.writes, 1);
    },
  );
  test('Profile changes persist and foreign IDs are rejected', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    await services.profile.update(
      services.profile.profile.copyWith(
        fullName: 'Alice Updated',
        phone: '0771234567',
        bio: 'Traveler',
      ),
    );
    await services.profile.signOut();
    await services.profile.signIn('alice@test.com', password: 'Secure123');
    expect(services.profile.profile.fullName, 'Alice Updated');
    expect(services.profile.profile.phone, '0771234567');
    expect(
      () => services.profile.update(
        const UserProfile(
          id: 'foreign',
          fullName: 'Other',
          email: 'other@test.com',
        ),
      ),
      throwsA(isA<BackendFailure>()),
    );
  });
  test(
    'Favorites persist, deduplicate and delete through repository',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      final place = services.discovery.discovery.places.first;
      services.discovery.favorites.addFavorite(place);
      await services.sync!.flush();
      services.discovery.favorites.addFavorite(place);
      await services.sync!.flush();
      expect(data.writes, 1);
      expect(data.private['uid-1']!['favorites']![place.id], {
        'placeId': place.id,
      });
      services.discovery.favorites.removeFavorite(place.id);
      await services.sync!.flush();
      expect(data.private['uid-1']!['favorites'], isEmpty);
    },
  );
  test('Itinerary saved CRUD persists while drafts remain local', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    final plan = TourPlan(
      destination: 'Kandy',
      date: DateTime.now().add(const Duration(days: 3)),
      duration: '1 Day',
      interests: ['History'],
      travelStyle: 'Balanced',
    );
    final itinerary = services.discovery.itineraries.generate(plan);
    await services.sync!.flush();
    expect(data.writes, 0);
    services.discovery.itineraries.save(itinerary.id);
    await services.sync!.flush();
    services.discovery.itineraries.rename(itinerary.id, 'Saved trip');
    await services.sync!.flush();
    await services.profile.signOut();
    await services.profile.signIn('alice@test.com', password: 'Secure123');
    expect(
      services.discovery.itineraries.find(itinerary.id)!.title,
      'Saved trip',
    );
    services.discovery.itineraries.delete(itinerary.id);
    await services.sync!.flush();
    expect(data.private['uid-1']!['itineraries'], isEmpty);
  });
  test('Guide note CRUD persists and retains place association', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    final note = services.navigation.notes.add('sigiriya', 'First note');
    await services.sync!.flush();
    services.navigation.notes.update(note.id, 'Edited note');
    await services.sync!.flush();
    await services.profile.signOut();
    await services.profile.signIn('alice@test.com', password: 'Secure123');
    expect(
      services.navigation.notes.forPlace('sigiriya').single.text,
      'Edited note',
    );
    services.navigation.notes.delete(note.id);
    await services.sync!.flush();
    expect(data.private['uid-1']!['guideNotes'], isEmpty);
  });
  test('Support CRUD, resolved/reopen status and random IDs persist', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    final request = services.support.createSupportRequest(
      subject: 'Help',
      message: 'Message',
      category: SupportCategory.general,
    );
    await services.sync!.flush();
    services.support.updateSupportRequest(
      request.id,
      subject: 'Edited',
      message: 'Changed',
      category: SupportCategory.account,
    );
    await services.sync!.flush();
    services.support.markResolved(request.id);
    await services.sync!.flush();
    await services.profile.signOut();
    await services.profile.signIn('alice@test.com', password: 'Secure123');
    expect(
      services.support.getById(request.id)!.status,
      SupportStatus.resolved,
    );
    services.support.markResolved(request.id, resolved: false);
    await services.sync!.flush();
    expect(
      data.private['uid-1']!['supportRequests']![request.id]!['status'],
      'open',
    );
    services.support.deleteSupportRequest(request.id);
    await services.sync!.flush();
    expect(data.private['uid-1']!['supportRequests'], isEmpty);
  });
  test(
    'Private content and language remain isolated between accounts',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      services.language.setLanguage('si');
      await services.sync!.flush();
      services.navigation.notes.add('place', 'Private A');
      await services.sync!.flush();
      await services.profile.signOut();
      await services.profile.register(
        fullName: 'Bob',
        email: 'bob@test.com',
        password: 'Secure123',
      );
      expect(services.profile.profile.id, 'uid-2');
      expect(services.language.selectedLanguageCode, 'en');
      expect(services.navigation.notes.allNotes, isEmpty);
      await services.profile.signOut();
      await services.profile.signIn('alice@test.com', password: 'Secure123');
      expect(services.language.selectedLanguageCode, 'si');
      expect(services.navigation.notes.allNotes.single.text, 'Private A');
    },
  );
  test(
    'Group create/update/delete persists and leader protection remains',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      final group = services.groups.createGroup(
        'Friends',
        services.discovery.discovery.places.first,
      );
      await services.sync!.flush();
      expect(group.inviteCode, matches(r'^HW-[A-Z0-9]{16}$'));
      services.groups.renameGroup(group.id, 'Renamed');
      await services.sync!.flush();
      services.groups.updateDestination(
        group.id,
        services.discovery.discovery.places.last,
      );
      await services.sync!.flush();
      final demo = services.groups.addMember(group.id, 'Demo member');
      await services.sync!.flush();
      expect(
        () => services.groups.removeMember(group.id, 'uid-1'),
        throwsStateError,
      );
      services.groups.removeMember(group.id, demo.id);
      await services.sync!.flush();
      await services.profile.signOut();
      await services.profile.signIn('alice@test.com', password: 'Secure123');
      expect(services.groups.getGroupById(group.id)!.name, 'Renamed');
      expect(
        services.groups.getGroupById(group.id)!.destinationPlaceId,
        services.discovery.discovery.places.last.id,
      );
      services.groups.deleteGroup(group.id);
      await services.sync!.flush();
      expect(data.groups, isEmpty);
    },
  );
  test('Cross-account invite joining is idempotent and nonleader operations rejected', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    final group = services.groups.createGroup(
      'Friends',
      services.discovery.discovery.places.first,
    );
    await services.sync!.flush();
    await services.profile.signOut();
    await services.profile.register(
      fullName: 'Bob',
      email: 'bob@test.com',
      password: 'Secure123',
    );
    expect(await services.groups.join('wrong-code'), isNull);
    await services.groups.join(group.inviteCode.toLowerCase());
    await services.groups.join(group.inviteCode);
    expect(
      services.groups
          .getGroupById(group.id)!
          .members
          .where((member) => member.id == 'uid-2'),
      hasLength(1),
    );
    expect(
      () => services.groups.renameGroup(group.id, 'Forbidden'),
      throwsStateError,
    );
    expect(() => services.groups.deleteGroup(group.id), throwsStateError);
    expect(
      () =>
          services.groups.toggleMemberLocationSharing(group.id, 'uid-1', true),
      throwsStateError,
    );
  });
  test(
    'Sharing state persists but demo movement never uploads positions',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      final group = services.groups.createGroup(
        'Friends',
        services.discovery.discovery.places.first,
      );
      await services.sync!.flush();
      services.groups.toggleMemberLocationSharing(group.id, 'uid-1', true);
      await services.sync!.flush();
      final writes = data.writes;
      services.groups.refreshTracking(group.id);
      await services.sync!.flush();
      expect(data.writes, writes);
      final member = CloudValues.map(
        CloudValues.list(data.groups[group.id]!['members']).single,
      );
      expect(member.containsKey('relativeX'), isFalse);
      expect(member['isSharingLocation'], isTrue);
    },
  );
  test('Save failures restore prior view and block further writes until reload', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    data.failWrites = true;
    services.language.setLanguage('ta');
    await services.sync!.flush();
    expect(services.sync!.error, contains('Save failed'));
    expect(services.language.selectedLanguageCode, 'en');
    data.failWrites = false;
    await services.sync!.retry();
    expect(services.sync!.error, isNull);
    services.language.setLanguage('ta');
    await services.sync!.flush();
    expect(
      data.private['uid-1']!['preferences']!['settings']!['selectedLanguageCode'],
      'ta',
    );
  });
  test('Loading failure does not authenticate or upload defaults', () async {
    final account = FakeAccount(), data = FakeData()..failLoads = true;
    final services = AppServices(account: account, data: data);
    addTearDown(services.dispose);
    await services.profile.ready;
    expect(
      () => services.profile.register(
        fullName: 'Alice',
        email: 'alice@test.com',
        password: 'Secure123',
      ),
      throwsA(isA<BackendFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(services.profile.isAuthenticated, isFalse);
    expect(data.writes, 0);
    expect(services.sync!.error, isNotNull);
  });
  test(
    'Busy reflects asynchronous writes and resets after completion',
    () async {
      final account = FakeAccount(), data = FakeData();
      final services = await signed(account, data);
      addTearDown(services.dispose);
      data.gate = Completer<void>();
      services.language.setLanguage('si');
      expect(services.sync!.busy, isTrue);
      data.gate!.complete();
      await services.sync!.flush();
      expect(services.sync!.busy, isFalse);
    },
  );
  test('Remote snapshots restore local views without another upload', () async {
    final account = FakeAccount(), data = FakeData();
    final services = await signed(account, data);
    addTearDown(services.dispose);
    data.streams['uid-1/preferences']!.add({
      'settings': {'selectedLanguageCode': 'si'},
    });
    await Future<void>.delayed(Duration.zero);
    expect(services.language.selectedLanguageCode, 'si');
    expect(data.writes, 0);
  });
  test('Timestamp, DateTime, ISO and malformed optional data are safe', () {
    final date = DateTime.utc(2026, 10, 5);
    for (final value in [
      Timestamp.fromDate(date),
      date,
      date.toIso8601String(),
    ]) {
      expect(CloudValues.date(value), date);
      expect(
        GuideNote.fromMap({
          'id': 'n',
          'placeId': 'p',
          'text': 'T',
          'createdAt': value,
          'updatedAt': value,
        }).createdAt,
        date,
      );
      expect(
        SupportRequest.fromMap({
          'createdAt': value,
          'updatedAt': value,
          'category': 'future',
          'status': null,
        }).status,
        SupportStatus.open,
      );
      expect(
        TourGroup.fromMap({'createdAt': value, 'members': []}).createdAt,
        date,
      );
    }
    expect(
      UserProfile.fromMap({'id': 42, 'phone': null, 'photoPath': false}).phone,
      '',
    );
    expect(
      GroupMember.fromMap({
        'name': null,
        'relativeX': 'bad',
        'lastUpdated': 'bad',
      }).relativeX,
      isNull,
    );
    expect(CloudValues.optionalDate(null), isNull);
  });
  test(
    'Firebase errors map to safe actionable messages without raw details',
    () {
      for (final code in [
        'invalid-email',
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'user-disabled',
        'email-already-in-use',
        'network-request-failed',
        'permission-denied',
        'unknown',
      ]) {
        final message = backendMessage(
          FirebaseAuthException(
            code: code,
            message: 'SECRET technical details',
          ),
        );
        expect(message, isNotEmpty);
        expect(message, isNot(contains('SECRET')));
      }
    },
  );
  test(
    'Invite codes are collision resistant and use only allowed characters',
    () {
      final codes = List.generate(1000, (_) => AppServices.newInviteCode());
      expect(codes.toSet(), hasLength(1000));
      expect(
        codes.every((code) => RegExp(r'^HW-[A-Z0-9]{16}$').hasMatch(code)),
        isTrue,
      );
    },
  );
}
