import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/navigation_guide/models/facility.dart';
import 'package:heritage_walk/features/navigation_guide/models/guide_note.dart';
import 'package:heritage_walk/features/navigation_guide/models/route_info.dart';
import 'package:heritage_walk/features/navigation_guide/services/navigation_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/guide_notes_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/facility_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/emergency_service.dart';

void main() {
  test('Navigation is deterministic, requires a destination and resets active state', () {
    final service = NavigationService();
    final discovery = DiscoveryService();
    addTearDown(service.dispose);
    addTearDown(discovery.dispose);
    expect(service.route, isNull);
    expect(service.start(), isFalse);
    service.selectDestination(discovery.places.first);
    expect(service.route!.minutes, 15);
    expect(service.route!.distanceKm, 4.8);
    service.start();
    expect(service.isActive, isTrue);
    service.selectMode(TravelMode.walking);
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
  test('Facility search combines types, query and filters', () {
    final service = FacilityService();
    expect(service.getFacilities().length, 8);
    expect(service.searchFacilities('', filter: 'Food').length, 2);
    expect(
      service.searchFacilities('CAFE', filter: 'Food').single.type,
      FacilityType.cafe,
    );
    expect(service.searchFacilities('cafe', filter: 'Parking'), isEmpty);
    expect(
      service.getFacilitiesByType(FacilityType.hospital).single.name,
      'Demo Medical Facility',
    );
    expect(
      service.searchFacilities('', filter: 'Police').single.type,
      FacilityType.police,
    );
    expect(
      service.searchFacilities('', filter: 'Medical').single.type,
      FacilityType.hospital,
    );
  });
  test('Emergency records contain no unverified phone numbers', () {
    final contacts = EmergencyService().getContacts();
    expect(contacts.length, 4);
    expect(contacts.every((contact) => contact.phoneNumber == null), isTrue);
  });
}
