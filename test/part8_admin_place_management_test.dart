import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/admin/services/place_validation.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/models/itinerary.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/discovery_planning/services/favorites_service.dart';
import 'package:heritage_walk/main.dart';

import 'support/part7_fakes.dart';

final fixture = DiscoveryService.localPlaces.first;

class TestRoles implements RoleRepository {
  TestRoles(this.role);
  String role;
  final events = StreamController<String>.broadcast(sync: true);
  @override
  Stream<String> watch(String uid) => Stream.multi((controller) {
    final sub = events.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.add(role);
    controller.onCancel = sub.cancel;
  });
  void set(String value) {
    role = value;
    events.add(value);
  }
}

class ControlledPlaces extends InMemoryPlaceRepository {
  ControlledPlaces(super.initial);
  bool hold = false, fail = false;
  Completer<void>? writeGate;
  int createCalls = 0;
  final attemptedIds = <String>[];
  @override
  Stream<List<HeritagePlace>> watch({bool activeOnly = true}) => hold
      ? const Stream.empty()
      : fail
      ? Stream.error(const BackendFailure('Unable to load catalog.'))
      : super.watch(activeOnly: activeOnly);
  @override
  Future<bool> create(HeritagePlace place, String uid) async {
    createCalls++;
    attemptedIds.add(place.id);
    if (writeGate != null) await writeGate!.future;
    if (fail) throw const BackendFailure('Place save failed.');
    return super.create(place, uid);
  }
}

Future<AppServices> app({
  bool admin = true,
  PlaceRepository? places,
  TestRoles? roles,
  FakeData? data,
}) async {
  final account = FakeAccount();
  await account.register('Test User', 'test@example.com', 'Secure123');
  final old = account.profiles[account.current]!;
  account.profiles[old.id] = UserProfile.fromMap({
    ...old.toMap(),
    'role': admin ? 'admin' : 'user',
  });
  final services = AppServices(
    account: account,
    data: data,
    places: places ?? InMemoryPlaceRepository(),
    roles: roles,
  );
  await services.profile.ready;
  await Future<void>.value();
  await Future<void>.value();
  return services;
}

Future<void> showApp(
  WidgetTester tester,
  AppServices services,
  String route,
) async {
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: route),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('Profile defaults to user; only exact admin role is recognized', () {
    expect(
      const UserProfile(id: '1', fullName: 'A', email: 'a').isAdmin,
      false,
    );
    expect(UserProfile.fromMap({'role': 'Admin'}).isAdmin, false);
    expect(UserProfile.fromMap({'role': 'admin'}).isAdmin, true);
  });
  test('Normal profile copy preserves trusted role', () {
    final profile = UserProfile.fromMap({'id': 'a', 'role': 'admin'});
    expect(profile.copyWith(fullName: 'New').role, 'admin');
  });
  test(
    'HeritagePlace serializes all management fields and legacy display fields',
    () {
      final value = HeritagePlace.fromMap({
        ...fixture.toMap(),
        'address': 'Main Road',
        'historicalPeriod': 'Ancient',
        'accessibilityInfo': 'Steps',
        'highlights': ['Gardens'],
        'isActive': false,
        'createdBy': 'a',
        'updatedBy': 'b',
      });
      final restored = HeritagePlace.fromMap(value.toMap());
      expect(restored.toMap(), value.toMap());
      expect(restored.rating, fixture.rating);
      expect(restored.isActive, false);
    },
  );
  test('Firestore Timestamp, DateTime and legacy ISO dates are accepted', () {
    final now = DateTime.utc(2026, 10, 5);
    for (final date in [Timestamp.fromDate(now), now, now.toIso8601String()]) {
      expect(
        HeritagePlace.fromMap({'createdAt': date, 'updatedAt': date}).createdAt,
        now,
      );
      expect(
        HeritagePlace.fromMap({'createdAt': date, 'updatedAt': date}).updatedAt,
        now,
      );
    }
  });
  test('Malformed optional fields and out-of-range coordinates are safe', () {
    final value = HeritagePlace.fromMap({
      'latitude': double.nan,
      'rating': double.nan,
      'reviewCount': double.infinity,
      'longitude': 181,
      'createdAt': {},
      'updatedAt': null,
      'highlights': ['Valid', 2],
      'openingHours': false,
    });
    expect(value.latitude, null);
    expect(value.rating, 0);
    expect(value.reviewCount, 0);
    expect(value.longitude, null);
    expect(value.createdAt, null);
    expect(value.highlights, ['Valid']);
    expect(value.openingHours, null);
    expect(value.isActive, true);
  });
  test('Required place values reject whitespace', () {
    expect(PlaceValidation.requiredText('  '), isNotNull);
    expect(PlaceValidation.requiredText('Temple'), null);
  });
  for (final limit in [90.0, 180.0]) {
    test('Coordinate limit $limit accepts bounds and optional blanks', () {
      for (final value in ['', '-$limit', '$limit', '0']) {
        expect(PlaceValidation.coordinate(value, limit), null);
      }
    });
    test('Coordinate limit $limit rejects invalid values', () {
      for (final value in [
        'NaN',
        'Infinity',
        'x',
        '${limit + 1}',
        '-${limit + 1}',
      ]) {
        expect(PlaceValidation.coordinate(value, limit), isNotNull);
      }
    });
  }
  test(
    'Image reference validates packaged assets and rejects remote/traversal',
    () {
      expect(PlaceValidation.image('assets/placeholders/place.png'), null);
      expect(PlaceValidation.image(''), null);
      expect(PlaceValidation.image('http://example.com/photo'), isNotNull);
      expect(PlaceValidation.image('assets/../secret'), isNotNull);
    },
  );
  test('Repository creates stable ID once and records audit fields', () async {
    final repo = InMemoryPlaceRepository();
    addTearDown(repo.dispose);
    expect(await repo.create(fixture, 'admin'), true);
    expect(
      await repo.create(fixture.copyWith(name: 'Duplicate'), 'admin'),
      false,
    );
    final saved = (await repo.list()).single;
    expect(saved.id, fixture.id);
    expect(saved.name, fixture.name);
    expect(saved.createdBy, 'admin');
    expect(saved.updatedBy, 'admin');
    expect(saved.createdAt, isNotNull);
  });
  test(
    'Repository lists active catalog separately from full admin list',
    () async {
      final repo = InMemoryPlaceRepository([
        fixture,
        fixture.copyWith(name: 'Inactive', isActive: false),
      ]);
      addTearDown(repo.dispose);
      expect(await repo.list(), isEmpty);
      expect((await repo.list(activeOnly: false)).length, 1);
    },
  );
  test('Repository update preserves original creation metadata', () async {
    final repo = InMemoryPlaceRepository();
    addTearDown(repo.dispose);
    await repo.create(fixture, 'first');
    final before = (await repo.list()).single;
    await repo.update(fixture.copyWith(name: 'Updated'), 'second');
    final after = (await repo.list()).single;
    expect(after.createdAt, before.createdAt);
    expect(after.createdBy, 'first');
    expect(after.updatedBy, 'second');
    expect(after.name, 'Updated');
  });
  test(
    'Repository delete removes only catalog item and missing operations fail',
    () async {
      final repo = InMemoryPlaceRepository([fixture]);
      addTearDown(repo.dispose);
      await repo.delete(fixture.id);
      expect(await repo.list(), isEmpty);
      await expectLater(
        repo.delete(fixture.id),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        repo.update(fixture, 'a'),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test(
    'Repository watch receives create, edit, deactivate and delete',
    () async {
      final repo = InMemoryPlaceRepository();
      addTearDown(repo.dispose);
      final stream = StreamIterator(repo.watch());
      addTearDown(stream.cancel);
      await stream.moveNext();
      expect(stream.current, isEmpty);
      await repo.create(fixture, 'a');
      await stream.moveNext();
      expect(stream.current.single.id, fixture.id);
      await repo.update(fixture.copyWith(name: 'Changed'), 'a');
      await stream.moveNext();
      expect(stream.current.single.name, 'Changed');
      await repo.update(fixture.copyWith(isActive: false), 'a');
      await stream.moveNext();
      expect(stream.current, isEmpty);
      await repo.delete(fixture.id);
      await stream.moveNext();
      expect(stream.current, isEmpty);
    },
  );
  test('Normal user is denied controller create, delete and seed', () async {
    final services = await app(admin: false);
    addTearDown(services.dispose);
    expect(services.catalog.isAdmin, false);
    await expectLater(
      services.catalog.save(fixture, create: true),
      throwsA(isA<BackendFailure>()),
    );
    await expectLater(
      services.catalog.delete(fixture.id),
      throwsA(isA<BackendFailure>()),
    );
    await expectLater(services.catalog.seed(), throwsA(isA<BackendFailure>()));
  });
  test(
    'Live role revocation clears management data and denies further writes',
    () async {
      final roles = TestRoles('admin');
      addTearDown(roles.events.close);
      final services = await app(
        roles: roles,
        places: InMemoryPlaceRepository([fixture]),
      );
      addTearDown(services.dispose);
      expect(services.catalog.isAdmin, true);
      expect(services.catalog.places, isNotEmpty);
      roles.set('user');
      await Future<void>.delayed(Duration.zero);
      expect(services.catalog.isAdmin, false);
      expect(services.catalog.places, isEmpty);
      await expectLater(
        services.catalog.delete(fixture.id),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test(
    'Server role source overrides an admin-looking profile when denied',
    () async {
      final roles = TestRoles('user');
      addTearDown(roles.events.close);
      final services = await app(roles: roles);
      addTearDown(services.dispose);
      expect(services.profile.profile.isAdmin, true);
      expect(services.catalog.isAdmin, false);
    },
  );
  test('Admin search and category filter include inactive places', () async {
    final services = await app(
      places: InMemoryPlaceRepository(DiscoveryService.localPlaces),
    );
    addTearDown(services.dispose);
    expect(
      services.catalog.search(query: '  kAnDy ').single.id,
      'tooth-temple',
    );
    expect(services.catalog.search(category: 'Forts').length, 3);
    expect(services.catalog.search(query: 'Kandy', category: 'Forts'), isEmpty);
  });
  test(
    'Seed is explicit, idempotent, preserves IDs and never overwrites',
    () async {
      final repo = InMemoryPlaceRepository([
        fixture.copyWith(name: 'Owner Edited'),
      ]);
      final services = await app(places: repo);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      expect((await repo.list()).length, 1);
      final first = await services.catalog.seed();
      expect(first.created, 7);
      expect(first.skipped, 1);
      final second = await services.catalog.seed();
      expect(second.created, 0);
      expect(second.skipped, 8);
      expect(
        (await repo.list()).singleWhere((p) => p.id == fixture.id).name,
        'Owner Edited',
      );
    },
  );
  test(
    'Admin saves validate required fields before repository writes',
    () async {
      final services = await app();
      addTearDown(services.dispose);
      await expectLater(
        services.catalog.save(fixture.copyWith(name: ' '), create: true),
        throwsA(isA<BackendFailure>()),
      );
      expect(await services.catalog.repository!.list(), isEmpty);
    },
  );
  test('Duplicate submissions are blocked during a pending create', () async {
    final repo = ControlledPlaces([])..writeGate = Completer<void>();
    final services = await app(places: repo);
    addTearDown(services.dispose);
    addTearDown(repo.dispose);
    final save = services.catalog.save(fixture, create: true);
    await expectLater(
      services.catalog.save(fixture, create: true),
      throwsA(isA<BackendFailure>()),
    );
    expect(repo.createCalls, 1);
    repo.writeGate!.complete();
    await save;
    expect(services.catalog.busy, false);
  });
  test('Failed save reports safely and clears pending state', () async {
    final repo = ControlledPlaces([]);
    final services = await app(places: repo);
    addTearDown(services.dispose);
    addTearDown(repo.dispose);
    repo.fail = true;
    await expectLater(
      services.catalog.save(fixture, create: true),
      throwsA(isA<BackendFailure>()),
    );
    expect(services.catalog.busy, false);
    expect(await repo.list(), isEmpty);
  });
  test(
    'Production-style discovery follows create edit active and delete changes',
    () async {
      final repo = InMemoryPlaceRepository();
      final services = await app(places: repo);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      expect(services.discovery.discovery.places, isEmpty);
      await services.catalog.save(fixture, create: true);
      await Future<void>.delayed(Duration.zero);
      expect(services.discovery.discovery.places.single.id, fixture.id);
      await services.catalog.save(
        fixture.copyWith(name: 'Current'),
        create: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(services.discovery.discovery.places.single.name, 'Current');
      await services.catalog.save(
        fixture.copyWith(isActive: false),
        create: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(services.discovery.discovery.places, isEmpty);
      expect(services.catalog.places.single.isActive, false);
      await services.catalog.delete(fixture.id);
      await Future<void>.delayed(Duration.zero);
      expect(services.catalog.places, isEmpty);
    },
  );
  test(
    'Favorite IDs survive catalog deletion without unintended cloud writes',
    () async {
      final repo = InMemoryPlaceRepository([fixture]);
      final data = FakeData();
      final services = await app(places: repo, data: data);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      services.discovery.favorites.addFavorite(fixture);
      await services.sync!.flush();
      final writes = data.writes;
      await services.catalog.save(
        fixture.copyWith(name: 'Renamed'),
        create: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        services.discovery.favorites.getFavorites().single.name,
        'Renamed',
      );
      await services.catalog.delete(fixture.id);
      await Future<void>.delayed(Duration.zero);
      await services.sync!.flush();
      expect(services.discovery.favorites.isFavorite(fixture.id), true);
      expect(
        services.discovery.favorites.getFavorites().single.name,
        'Unavailable place',
      );
      expect(data.writes, writes);
      expect(
        data.private['uid-1']!['favorites']!.containsKey(fixture.id),
        true,
      );
    },
  );
  test('Unresolved cloud favorite restores before catalog arrives and resolves later', () {
    final favorites = FavoritesService();
    addTearDown(favorites.dispose);
    favorites.restoreIds([fixture.id], []);
    expect(favorites.isFavorite(fixture.id), true);
    favorites.reconcile([fixture]);
    expect(favorites.getFavorites().single.name, fixture.name);
  });
  test('Saved itinerary snapshots survive place edits and deletion', () async {
    final services = await app(places: InMemoryPlaceRepository([fixture]));
    addTearDown(services.dispose);
    final generated = services.discovery.itineraries.generate(
      TourPlan(
        destination: fixture.city,
        date: DateTime.now().add(const Duration(days: 1)),
        duration: '1 Day',
        interests: ['History'],
        travelStyle: 'Balanced',
      ),
    );
    services.discovery.itineraries.save(generated.id);
    await services.catalog.delete(fixture.id);
    final saved = services.discovery.itineraries.savedItineraries.single;
    expect(saved.places.single.name, fixture.name);
    expect(Itinerary.fromMap(saved.toMap()).places.single.id, fixture.id);
  });
  test(
    'Tour destinations derive from cloud places including new cities',
    () async {
      final place = HeritagePlace.fromMap({
        ...fixture.toMap(),
        'city': 'New City',
      });
      final services = await app(places: InMemoryPlaceRepository([place]));
      addTearDown(services.dispose);
      expect(services.discovery.discovery.availableDestinations, ['New City']);
      final itinerary = services.discovery.itineraries.generate(
        TourPlan(
          destination: 'New City',
          date: DateTime.now(),
          duration: '1 Day',
          interests: ['History'],
          travelStyle: 'Balanced',
        ),
      );
      expect(itinerary.places.single.id, fixture.id);
    },
  );
  for (final route in [
    AppRoutes.admin,
    AppRoutes.adminPlaces,
    AppRoutes.adminPlaceAdd,
    AppRoutes.adminPlaceEdit,
    AppRoutes.adminPlacePreview,
  ]) {
    testWidgets('Normal user denied direct route $route', (tester) async {
      await showApp(tester, await app(admin: false), route);
      expect(find.text('Admin access required'), findsOneWidget);
      expect(find.text('Save Place'), findsNothing);
      expect(find.text('Add Place'), findsNothing);
    });
  }
  testWidgets('Profile shows Admin Panel only for authorized admin', (
    tester,
  ) async {
    await showApp(tester, await app(), AppRoutes.profile);
    expect(find.text('Admin Panel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await showApp(tester, await app(admin: false), AppRoutes.profile);
    expect(find.text('Admin Panel'), findsNothing);
  });
  testWidgets('Dashboard displays actual catalog totals and categories', (
    tester,
  ) async {
    await showApp(
      tester,
      await app(places: InMemoryPlaceRepository([fixture])),
      AppRoutes.admin,
    );
    expect(find.textContaining('Total Places: 1'), findsOneWidget);
    expect(find.text('Forts: 1'), findsOneWidget);
    expect(find.text('Manage Historical Places'), findsOneWidget);
  });
  testWidgets('Admin empty state provides add and explicit seed actions', (
    tester,
  ) async {
    await showApp(tester, await app(), AppRoutes.adminPlaces);
    expect(find.textContaining('No historical places yet'), findsOneWidget);
    expect(find.text('Add Place'), findsOneWidget);
    expect(find.text('Seed original catalog (one-time setup)'), findsOneWidget);
  });
  testWidgets('Admin loading state is visible', (tester) async {
    final repo = ControlledPlaces([])..hold = true;
    final services = await app(places: repo);
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.adminPlaces),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('No historical places yet'), findsNothing);
  });
  testWidgets('Admin backend error shows reload and recovers', (tester) async {
    final repo = ControlledPlaces([])..fail = true;
    await showApp(tester, await app(places: repo), AppRoutes.adminPlaces);
    expect(find.text('Unable to load catalog.'), findsOneWidget);
    repo.fail = false;
    await press(tester, 'Reload catalog');
    expect(find.textContaining('No historical places yet'), findsOneWidget);
  });
  testWidgets('Role revocation guards an already-open admin form', (
    tester,
  ) async {
    final roles = TestRoles('admin');
    await showApp(tester, await app(roles: roles), AppRoutes.adminPlaceAdd);
    expect(find.text('Save Place'), findsOneWidget);
    roles.set('user');
    await tester.pumpAndSettle();
    expect(find.text('Admin access required'), findsOneWidget);
    expect(find.text('Save Place'), findsNothing);
  });
  testWidgets('Add form validates required information and coordinates', (
    tester,
  ) async {
    await showApp(tester, await app(), AppRoutes.adminPlaceAdd);
    await press(tester, 'Save Place');
    expect(find.text('This field is required'), findsNWidgets(5));
    final latitude = find.widgetWithText(TextFormField, 'Latitude');
    await tester.ensureVisible(latitude);
    await tester.enterText(latitude, '91');
    await press(tester, 'Save Place');
    expect(find.text('Enter a number between -90 and 90'), findsOneWidget);
  });
  testWidgets(
    'Admin edit opens with existing data and preview reuses details',
    (tester) async {
      final services = await app(places: InMemoryPlaceRepository([fixture]));
      await showApp(tester, services, AppRoutes.adminPlaces);
      await press(tester, 'Edit');
      expect(find.text('Edit Historical Place'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, fixture.name), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await press(tester, 'Preview');
      expect(find.text('Place Details'), findsOneWidget);
      expect(find.text(fixture.name), findsOneWidget);
    },
  );
  testWidgets('Delete confirmation identifies place and cancel retains it', (
    tester,
  ) async {
    final services = await app(places: InMemoryPlaceRepository([fixture]));
    await showApp(tester, services, AppRoutes.adminPlaces);
    await press(tester, 'Delete');
    expect(find.text('Delete ${fixture.name}?'), findsOneWidget);
    await press(tester, 'Cancel');
    expect(services.catalog.places.length, 1);
    await press(tester, 'Delete');
    await press(tester, 'Delete');
    expect(services.catalog.places, isEmpty);
  });
  testWidgets(
    'Add form saves validated data and reuses its ID after a failed save',
    (tester) async {
      final repo = ControlledPlaces([]);
      final services = await app(places: repo);
      await showApp(tester, services, AppRoutes.adminPlaces);
      await press(tester, 'Add Place');
      await tester.tap(find.byKey(const ValueKey('place-category-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forts').last);
      await tester.pumpAndSettle();
      for (final entry in {
        'Name *': 'New Fortress',
        'Description *': 'Historical description',
        'City *': 'Kandy',
        'District *': 'Kandy',
        'Latitude': '7.2',
        'Longitude': '80.6',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      repo.fail = true;
      await press(tester, 'Save Place');
      expect(find.text('Place save failed.'), findsOneWidget);
      repo.fail = false;
      await press(tester, 'Save Place');
      expect(repo.attemptedIds.toSet().length, 1);
      expect(repo.createCalls, 2);
      final saved = (await repo.list()).single;
      expect(saved.name, 'New Fortress');
      expect(saved.latitude, 7.2);
      expect(saved.createdBy, 'uid-1');
      expect(find.text('Manage Historical Places'), findsOneWidget);
    },
  );
  testWidgets(
    'Edit form saves changes and preserves original creation metadata',
    (tester) async {
      final repo = InMemoryPlaceRepository();
      await repo.create(fixture, 'original-admin');
      final before = (await repo.list()).single;
      final services = await app(places: repo);
      await showApp(tester, services, AppRoutes.adminPlaces);
      await press(tester, 'Edit');
      final field = find.widgetWithText(TextFormField, 'Name *');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Edited Fortress');
      await press(tester, 'Save Place');
      final after = (await repo.list()).single;
      expect(after.name, 'Edited Fortress');
      expect(after.createdAt, before.createdAt);
      expect(after.createdBy, 'original-admin');
      expect(after.updatedBy, 'uid-1');
    },
  );
  testWidgets('Admin form scrolls on small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: HeritageWalkApp(
          services: await app(),
          initialRoute: AppRoutes.adminPlaceAdd,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Place'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
}
