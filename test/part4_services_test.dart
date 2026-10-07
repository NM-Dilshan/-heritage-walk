import 'support/part9_fakes.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/navigation_guide/models/facility.dart';

import 'support/part91_fakes.dart';

import 'package:heritage_walk/features/navigation_guide/models/guide_note.dart';
import 'package:heritage_walk/features/navigation_guide/models/route_info.dart';
import 'package:heritage_walk/features/navigation_guide/services/navigation_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/guide_notes_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/emergency_service.dart';

void main() {
  test('Navigation requires a GPS route and resets active state', () async {
    final gps = FakeGps(), routing = FakeRouting();
    final service = NavigationService(location: gps, routing: routing);
    addTearDown(gps.dispose);
    final discovery = DiscoveryService();
    addTearDown(service.dispose);
    addTearDown(discovery.dispose);
    expect(service.route, isNull);
    expect(service.start(), isFalse);
    service.selectDestination(coordinatePlace(discovery.places.first));
    expect(service.route, isNull);
    await service.locate();
    expect(service.route!.minutes, 10);
    expect(service.route!.distanceKm, 3.8);
    service.start();
    expect(service.isActive, isTrue);
    service.selectMode(TravelMode.walking);
    await flushGps();
    expect(service.route!.minutes, 58);
    expect(service.isActive, isFalse);
    service.start();
    service.end();
    expect(service.isActive, isFalse);
    service.clear();
    expect(service.destination, isNull);
  });
  test(
    'Notes CRUD is place-scoped, immutable and retains creation metadata',
    () {
      final service = GuideNotesService();
      addTearDown(service.dispose);
      final note = service.add('sigiriya', ' First note ');
      service.add('galle', 'Another note');
      expect(service.forPlace('sigiriya').single.text, 'First note');
      expect(
        () => service.forPlace('sigiriya').clear(),
        throwsUnsupportedError,
      );
      service.update(note.id, 'Updated note');
      final updated = service.forPlace('sigiriya').single;
      expect(updated.createdAt, note.createdAt);
      expect(updated.updatedAt.isBefore(note.updatedAt), isFalse);
      expect(GuideNote.fromMap(updated.toMap()).toMap(), updated.toMap());
      service.delete(note.id);
      expect(service.forPlace('sigiriya'), isEmpty);
      expect(service.forPlace('galle').length, 1);
      service.clear();
      expect(service.forPlace('galle'), isEmpty);
    },
  );
  test(
    'Notes reject empty text, missing places and more than 500 characters',
    () {
      final service = GuideNotesService();
      addTearDown(service.dispose);
      expect(() => service.add('sigiriya', '  '), throwsArgumentError);
      expect(() => service.add('', 'text'), throwsArgumentError);
      expect(() => service.add('sigiriya', 'x' * 501), throwsArgumentError);
      expect(() => service.update('missing', 'text'), throwsArgumentError);
      final note = service.add('sigiriya', 'valid');
      expect(() => service.update(note.id, ''), throwsArgumentError);
      expect(service.forPlace('sigiriya').single.text, 'valid');
    },
  );
  test(
    'Facility search combines real OSM categories and GPS proximity',
    () async {
      final service = FakeNearbyFacilityService();
      final food = await service.search(
        origin: facilityOrigin,
        category: FacilityCategory.food,
      );
      expect(food, hasLength(3));
      expect(
        food.where((f) => f.name!.toLowerCase().contains('cafe')).single.osmId,
        'node/8',
      );
      expect(
        (await service.search(
          origin: facilityOrigin,
          category: FacilityCategory.parking,
        )).where((f) => f.name!.contains('Cafe')),
        isEmpty,
      );
      expect(
        (await service.search(
          origin: facilityOrigin,
          category: FacilityCategory.hospital,
        )),
        hasLength(3),
      );
      expect(
        (await service.search(
          origin: facilityOrigin,
          category: FacilityCategory.police,
        )).single.category,
        FacilityCategory.police,
      );
      expect(food.every((f) => f.distanceMeters > 0), isTrue);
    },
  );
  test('Emergency records contain no unverified phone numbers', () {
    final contacts = EmergencyService().getContacts();
    expect(contacts.length, 4);
    expect(contacts.every((contact) => contact.phoneNumber == null), isTrue);
  });
}
