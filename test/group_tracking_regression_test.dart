import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/features/group_support/models/group_member.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/screens/group_tracking_screen.dart';
import 'package:heritage_walk/features/group_support/services/group_location_service.dart';
import 'package:heritage_walk/features/group_support/services/group_tour_service.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/heritage_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'support/part7_fakes.dart';
import 'support/part9_fakes.dart';

class _Db extends Mock implements FirebaseFirestore {}

// Test doubles inject metadata transitions unavailable in fake_cloud_firestore.
// ignore: subtype_of_sealed_class
class _Collection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _Document extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _Snapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _LocationDocument extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _Metadata extends Mock implements SnapshotMetadata {}

SnapshotMetadata metadata({bool cache = false, bool pending = false}) {
  final value = _Metadata();
  when(() => value.isFromCache).thenReturn(cache);
  when(() => value.hasPendingWrites).thenReturn(pending);
  return value;
}

QueryDocumentSnapshot<Map<String, dynamic>> locationDocument(
  String uid, {
  bool pending = false,
}) {
  final value = _LocationDocument();
  final meta = metadata(pending: pending);
  when(() => value.id).thenReturn(uid);
  when(() => value.metadata).thenReturn(meta);
  when(() => value.data()).thenReturn({
    'userId': uid,
    'displayName': uid,
    'latitude': 7,
    'longitude': 81,
    'updatedAt': Timestamp.now(),
  });
  return value;
}

TourGroup trackingGroup() => TourGroup(
  id: 'shared-group',
  name: 'Friends',
  inviteCode: 'ABC123',
  leaderId: 'alice-uid',
  leaderName: 'Alice',
  createdAt: DateTime.now(),
  members: const [
    GroupMember(id: 'alice-uid', name: 'Alice', isLeader: true),
    GroupMember(id: 'bob-uid', name: 'Bob'),
  ],
);

Future<AppServices> memberServices(
  String uid,
  GroupLocationRepository repo, {
  FakeGps? gps,
  bool restoreGroup = true,
}) async {
  final account = FakeAccount();
  account.current = uid;
  account.profiles[uid] = UserProfile(
    id: uid,
    fullName: uid == 'alice-uid' ? 'Alice' : 'Bob',
    email: '$uid@test.com',
  );
  final services = AppServices(
    account: account,
    groupLocations: repo,
    location: gps ?? FakeGps(),
  );
  await services.profile.ready;
  if (restoreGroup) services.groups.restore([trackingGroup()]);
  return services;
}

Future<void> pumpTracking(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GroupTourScope(
        service: services.groups,
        child: DiscoveryScope(
          state: services.discovery,
          child: const GroupTrackingScreen(groupId: 'shared-group'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('metadata acknowledgements expose both members; pending self never hides confirmed peer', () async {
    final db = _Db(),
        groups = _Collection(),
        group = _Document(),
        locations = _Collection();
    final changes = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(() => db.collection('groups')).thenReturn(groups);
    when(() => groups.doc('shared-group')).thenReturn(group);
    when(() => group.collection('locations')).thenReturn(locations);
    when(() => locations.snapshots(includeMetadataChanges: true))
        .thenAnswer((_) => changes.stream);
    final received = <List<SharedLocation>>[];
    final subscription = FirestoreGroupLocationRepository(db)
        .watch('shared-group')
        .listen(received.add);
    void emit({bool cache = false, bool pending = false}) {
      final snapshot = _Snapshot();
      final meta = metadata(cache: cache);
      final documents = [
        locationDocument('alice-uid', pending: pending),
        locationDocument('bob-uid'),
      ];
      when(() => snapshot.metadata).thenReturn(meta);
      when(() => snapshot.docs).thenReturn(documents);
      changes.add(snapshot);
    }

    emit(cache: true);
    await flushGps();
    expect(received.last, isEmpty);
    emit(pending: true);
    await flushGps();
    expect(received.last.map((l) => l.userId), ['bob-uid']);
    emit();
    await flushGps();
    expect(received.last.map((l) => l.userId), ['alice-uid', 'bob-uid']);
    await subscription.cancel();
    await changes.close();
  });
  test(
    'live group feed restarts when membership arrives after construction',
    () async {
      final repo = MemoryGroupLocationRepository();
      final services = await memberServices(
        'alice-uid',
        repo,
        restoreGroup: false,
      );
      final session = GroupLocationSession(
        services.groups,
        repo,
        FakeGps(),
        'shared-group',
      );
      addTearDown(() {
        session.dispose();
        services.dispose();
        repo.dispose();
      });
      services.groups.restore([trackingGroup()]);
      await flushGps();
      await repo.write(
        'shared-group',
        SharedLocation('bob-uid', 'Bob', const LatLng(7, 81), DateTime.now()),
      );
      await flushGps();
      expect(session.freshLocations.map((l) => l.userId), ['bob-uid']);
    },
  );

  testWidgets('tracking fits all members arriving after the map is opened', (
    tester,
  ) async {
    final repo = MemoryGroupLocationRepository();
    final services = await memberServices('alice-uid', repo);
    await repo.write(
      'shared-group',
      SharedLocation('alice-uid', 'Alice', const LatLng(6, 80), DateTime.now()),
    );
    await pumpTracking(tester, services);
    await repo.write(
      'shared-group',
      SharedLocation('bob-uid', 'Bob', const LatLng(9, 81), DateTime.now()),
    );
    await tester.pumpAndSettle();
    final map = tester.widget<HeritageMap>(find.byType(HeritageMap));
    expect(map.markers.map((m) => m.id).toSet(), {'alice-uid', 'bob-uid'});
    expect(map.fitMarkers, isTrue);
    expect(find.byKey(const ValueKey('marker-alice-uid')), findsOneWidget);
    expect(find.byKey(const ValueKey('marker-bob-uid')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    repo.dispose();
  });

  testWidgets(
    'old camera behavior culls a distant incoming member; group fitting exposes both',
    (tester) async {
      const own = HeritageMapMarker('a', LatLng(6, 80), 'You', current: true);
      const other = HeritageMapMarker('b', LatLng(9, 81), 'Bob');
      Future<void> render(
        List<HeritageMapMarker> markers, {
        bool fit = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HeritageMap(
                markers: markers,
                fitMarkers: fit,
                tilesEnabled: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render([own]);
      await render([own, other]);
      expect(find.byKey(const ValueKey('marker-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-b')), findsNothing);
      await render([own], fit: true);
      await render([own, other], fit: true);
      expect(find.byKey(const ValueKey('marker-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-b')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'two UID sessions create separate documents and receive each other live',
    () async {
      final db = FakeFirebaseFirestore();
      final repoA = FirestoreGroupLocationRepository(db);
      final repoB = FirestoreGroupLocationRepository(db);
      final a = await memberServices('alice-uid', repoA);
      final b = await memberServices('bob-uid', repoB);
      final gpsA = FakeGps(), gpsB = FakeGps(fix: const LatLng(8, 81));
      var elapsedA = Duration.zero, elapsedB = Duration.zero;
      final sessionA = GroupLocationSession(
        a.groups,
        repoA,
        gpsA,
        'shared-group',
        elapsed: () => elapsedA,
      );
      final sessionB = GroupLocationSession(
        b.groups,
        repoB,
        gpsB,
        'shared-group',
        elapsed: () => elapsedB,
      );
      addTearDown(() async {
        await sessionA.stop();
        await sessionB.stop();
        sessionA.dispose();
        sessionB.dispose();
        a.dispose();
        b.dispose();
        await gpsA.dispose();
        await gpsB.dispose();
      });
      await flushGps();
      expect(
        (await db.collection('groups/shared-group/locations').get()).docs,
        isEmpty,
      );
      await sessionA.start();
      final ownA = await db
          .doc('groups/shared-group/locations/alice-uid')
          .get();
      expect(ownA.data()!['userId'], 'alice-uid');
      expect(ownA.data()!['updatedAt'], isA<Timestamp>());
      expect(
        (await db.collection('groups/shared-group/locations').get())
            .docs
            .length,
        1,
      );
      await sessionB.start();
      await flushGps();
      final ownB = await db.doc('groups/shared-group/locations/bob-uid').get();
      expect(ownB.data()!['userId'], 'bob-uid');
      expect(ownB.data()!['updatedAt'], isA<Timestamp>());
      expect(ownB.data()!.keys.toSet(), {
        'userId',
        'displayName',
        'latitude',
        'longitude',
        'updatedAt',
      });
      expect(sessionA.freshLocations.map((l) => l.userId).toSet(), {
        'alice-uid',
        'bob-uid',
      });
      expect(sessionB.freshLocations.map((l) => l.userId).toSet(), {
        'alice-uid',
        'bob-uid',
      });
      elapsedA += const Duration(seconds: 11);
      gpsA.updates.add(const LatLng(6.05, 80.22));
      await flushGps();
      expect(
        sessionB.freshLocations
            .singleWhere((l) => l.userId == 'alice-uid')
            .position,
        const LatLng(6.05, 80.22),
      );
      expect(
        (await db.doc('groups/shared-group/locations/bob-uid').get()).data(),
        ownB.data(),
      );
      elapsedB += const Duration(seconds: 11);
      gpsB.updates.add(const LatLng(8.02, 81.01));
      await flushGps();
      expect(
        sessionA.freshLocations
            .singleWhere((l) => l.userId == 'bob-uid')
            .position,
        const LatLng(8.02, 81.01),
      );
      await sessionA.stop();
      await flushGps();
      expect(gpsA.cancellations, 1);
      expect(
        (await db.doc('groups/shared-group/locations/alice-uid').get()).exists,
        isFalse,
      );
      expect(
        (await db.doc('groups/shared-group/locations/bob-uid').get()).exists,
        isTrue,
      );
      expect(sessionB.freshLocations.map((l) => l.userId), ['bob-uid']);
      expect(sessionB.sharing, isTrue);
    },
  );

  test('membership loss hides positions and rejoining resubscribes without GPS consent', () async {
    final repo = MemoryGroupLocationRepository();
    final a = await memberServices('alice-uid', repo);
    final gps = FakeGps();
    final session = GroupLocationSession(a.groups, repo, gps, 'shared-group');
    addTearDown(() {
      session.dispose();
      a.dispose();
      repo.dispose();
    });
    await flushGps();
    await repo.write(
      'shared-group',
      SharedLocation('bob-uid', 'Bob', const LatLng(7, 81), DateTime.now()),
    );
    await flushGps();
    expect(session.freshLocations.length, 1);
    a.groups.clear();
    expect(session.freshLocations, isEmpty);
    a.groups.restore([trackingGroup()]);
    await flushGps();
    expect(session.freshLocations.single.userId, 'bob-uid');
    expect(gps.currentCalls, 0);
    expect(session.sharing, isFalse);
  });

  for (final skew in [
    const Duration(minutes: 10),
    const Duration(minutes: -10),
  ]) {
    test(
      'confirmed server time tolerates device skew $skew and still expires stale positions',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = FirestoreGroupLocationRepository(db);
        final a = await memberServices('alice-uid', repo);
        var ticks = Duration.zero;
        var deviceNow = DateTime.now().add(skew);
        final session = GroupLocationSession(
          a.groups,
          repo,
          FakeGps(),
          'shared-group',
          now: () => deviceNow,
          elapsed: () => ticks,
        );
        addTearDown(() async {
          await session.stop();
          session.dispose();
          a.dispose();
        });
        await repo.write(
          'shared-group',
          SharedLocation('bob-uid', 'Bob', const LatLng(7, 81), DateTime(2000)),
        );
        await session.start();
        await flushGps();
        expect(session.freshLocations.map((l) => l.userId).toSet(), {
          'alice-uid',
          'bob-uid',
        });
        deviceNow = deviceNow.subtract(const Duration(days: 1));
        ticks += const Duration(minutes: 3);
        expect(session.freshLocations, isEmpty);
      },
    );
  }

  test('old server records stay stale after clock calibration and outsiders are filtered', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreGroupLocationRepository(db);
    final a = await memberServices('alice-uid', repo);
    final session = GroupLocationSession(
      a.groups,
      repo,
      FakeGps(),
      'shared-group',
      now: () => DateTime.now().add(const Duration(hours: 1)),
    );
    addTearDown(() async {
      await session.stop();
      session.dispose();
      a.dispose();
    });
    final fields = {
      'userId': 'bob-uid',
      'displayName': 'Bob',
      'latitude': 7,
      'longitude': 81,
      'updatedAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    };
    await db.doc('groups/shared-group/locations/bob-uid').set(fields);
    await repo.write(
      'shared-group',
      SharedLocation(
        'outsider-uid',
        'Other',
        const LatLng(7, 81),
        DateTime.now(),
      ),
    );
    await session.start();
    await flushGps();
    expect(session.locations.length, 3);
    expect(session.freshLocations.map((l) => l.userId), ['alice-uid']);
  });

  test('pending null timestamps and mismatched document UIDs do not suppress other valid members', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreGroupLocationRepository(db);
    await repo.write(
      'shared-group',
      SharedLocation('bob-uid', 'Bob', const LatLng(7, 81), DateTime.now()),
    );
    await db.doc('groups/shared-group/locations/alice-uid').set({
      'userId': 'alice-uid',
      'displayName': 'Alice',
      'latitude': 6,
      'longitude': 80,
      'updatedAt': null,
    });
    await db.doc('groups/shared-group/locations/spoof').set({
      'userId': 'bob-uid',
      'displayName': 'Spoof',
      'latitude': 6,
      'longitude': 80,
      'updatedAt': Timestamp.now(),
    });
    final values = await repo.watch('shared-group').first;
    expect(values.map((l) => l.userId), ['bob-uid']);
    expect(values.single.updatedAt.isUtc, isTrue);
  });

  testWidgets(
    'coincident members retain exact geographic anchors, labels and group recenter',
    (tester) async {
      final repo = MemoryGroupLocationRepository();
      final a = await memberServices('alice-uid', repo);
      await repo.write(
        'shared-group',
        SharedLocation(
          'alice-uid',
          'Alice',
          const LatLng(7, 81),
          DateTime.now(),
        ),
      );
      await repo.write(
        'shared-group',
        SharedLocation('bob-uid', 'Bob', const LatLng(7, 81), DateTime.now()),
      );
      await pumpTracking(tester, a);
      final own = find.byKey(const ValueKey('marker-alice-uid'));
      final other = find.byKey(const ValueKey('marker-bob-uid'));
      expect(own, findsOneWidget);
      expect(other, findsOneWidget);
      expect(tester.getCenter(own), tester.getRect(other).bottomCenter);
      final map = tester.widget<HeritageMap>(find.byType(HeritageMap));
      expect(map.markers.singleWhere((m) => m.current).label, 'You');
      expect(map.markers.singleWhere((m) => !m.current).label, 'Bob');
      expect(map.markers.map((m) => m.position).toSet(), {const LatLng(7, 81)});
      await repo.write(
        'shared-group',
        SharedLocation(
          'bob-uid',
          'Bob',
          const LatLng(7.0003, 81.0003),
          DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(own), isNot(tester.getRect(other).bottomCenter));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(0, 0), 12);
      await tester.pump();
      await tester.tap(find.byTooltip('Recenter'));
      await tester.pumpAndSettle();
      expect(
        controller.camera.visibleBounds.contains(const LatLng(7, 81)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      a.dispose();
      repo.dispose();
    },
  );

  testWidgets('non-group maps retain their current-user recenter behavior', (
    tester,
  ) async {
    const current = LatLng(6, 80);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeritageMap(
            current: current,
            fitMarkers: true,
            tilesEnabled: false,
            markers: [
              HeritageMapMarker('a', current, 'You'),
              HeritageMapMarker('b', LatLng(9, 81), 'Other'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recenter'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    expect(controller.camera.center, current);
    expect(controller.camera.zoom, 15);
    await tester.pumpWidget(const SizedBox());
  });
}
