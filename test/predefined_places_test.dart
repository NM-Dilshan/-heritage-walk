import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/admin/services/predefined_places.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/discovery_planning/widgets/place_card.dart';

import 'part8_admin_place_management_test.dart' as fixtures;

class PendingImport extends InMemoryPlaceRepository {
  final gate = Completer<void>();
  @override
  Future<PlaceImportResult> importPredefined(String uid) async {
    await gate.future;
    return super.importPredefined(uid);
  }
}

void main() {
  const places = PredefinedPlaces.places;
  test('dataset contains 17 unique stable IDs and names', () {
    expect(places, hasLength(17));
    expect(places.map((p) => p.id).toSet(), hasLength(17));
    expect(places.map((p) => p.name).toSet(), hasLength(17));
  });
  test('all coordinates and existing categories are valid', () {
    for (final p in places) {
      expect(p.latitude, inInclusiveRange(-90, 90));
      expect(p.longitude, inInclusiveRange(-180, 180));
      expect(DiscoveryService.categories.skip(1), contains(p.category));
      expect(p.latitude, isNotNull);
      expect(p.longitude, isNotNull);
    }
  });
  test('all 17 packaged images exist and are distinct', () {
    expect(places.map((p) => p.imagePath).toSet(), hasLength(17));
    for (final p in places) {
      expect(File(p.imagePath).existsSync(), isTrue, reason: p.imagePath);
    }
  });
  test('all requested text fields and highlights contain supplied content', () {
    for (final p in places) {
      for (final text in [
        p.name,
        p.shortDescription,
        p.description,
        p.city,
        p.district,
        p.address,
        p.historicalPeriod,
        p.openingHours,
        p.entranceFee,
        p.accessibilityInfo,
      ]) {
        expect(text, isNotEmpty);
      }
      expect(p.highlights, isNotEmpty);
      expect(p.rating, 0);
      expect(p.reviewCount, 0);
      expect(p.isActive, isTrue);
    }
    expect(places.first.description, contains('King Kashyapa'));
    expect(places[2].description, contains('Portuguese fortifications'));
  });
  test('legacy stable IDs preserve existing seed references', () {
    expect(
      places.map((p) => p.id),
      containsAll([
        'sigiriya',
        'tooth-temple',
        'galle-fort',
        'dambulla',
        'nine-arch',
        'jaffna-fort',
      ]),
    );
    expect(places.map((p) => p.id), isNot(contains('anuradhapura')));
    expect(places.map((p) => p.id), isNot(contains('polonnaruwa')));
  });
  test(
    'limited featured subset respects Home limit and Explore active filtering',
    () {
      expect(places.where((p) => p.isFeatured), hasLength(7));
      final featured = featuredPlaces(places);
      expect(featured, hasLength(4));
      expect(featured.every((p) => p.isFeatured && p.isActive), isTrue);
      final discovery = DiscoveryService()..replaceCatalog(places);
      addTearDown(discovery.dispose);
      expect(discovery.filteredPlaces, hasLength(17));
      discovery.replaceCatalog([
        places.first.copyWith(isActive: false),
        ...places.skip(1),
      ]);
      expect(discovery.filteredPlaces, hasLength(16));
      expect(featuredPlaces(discovery.places).every((p) => p.isActive), isTrue);
    },
  );

  test('admin import creates exactly 17 and repeated import skips unchanged records', () async {
    final repo = InMemoryPlaceRepository();
    final services = await fixtures.app(places: repo);
    addTearDown(services.dispose);
    addTearDown(repo.dispose);
    final first = await services.catalog.importPredefined();
    expect(first.created, 17);
    expect(first.updated, 0);
    expect(first.skipped, 0);
    final second = await services.catalog.importPredefined();
    expect(second.created, 0);
    expect(second.updated, 0);
    expect(second.skipped, 17);
    expect(await repo.list(activeOnly: false), hasLength(17));
  });
  test('non-admin and signed-out sessions cannot import', () async {
    final repo = InMemoryPlaceRepository();
    final services = await fixtures.app(admin: false, places: repo);
    addTearDown(services.dispose);
    addTearDown(repo.dispose);
    await expectLater(
      services.catalog.importPredefined(),
      throwsA(isA<BackendFailure>()),
    );
    await services.profile.signOut();
    await expectLater(
      services.catalog.importPredefined(),
      throwsA(isA<BackendFailure>()),
    );
    expect(await repo.list(activeOnly: false), isEmpty);
  });
  test(
    'duplicate in-flight imports are blocked and busy clears after completion',
    () async {
      final repo = PendingImport();
      final services = await fixtures.app(places: repo);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      final first = services.catalog.importPredefined();
      expect(services.catalog.busy, isTrue);
      await expectLater(
        services.catalog.importPredefined(),
        throwsA(isA<BackendFailure>()),
      );
      repo.gate.complete();
      await first;
      expect(services.catalog.busy, isFalse);
      expect(await repo.list(), hasLength(17));
    },
  );
  test('Firestore import is idempotent with server audit timestamps', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestorePlaceRepository(db);
    expect((await repo.importPredefined('admin')).created, 17);
    expect((await repo.importPredefined('admin')).skipped, 17);
    final docs = await db.collection('places').get();
    expect(docs.docs, hasLength(17));
    for (final doc in docs.docs) {
      expect(doc['id'], doc.id);
      expect(doc['createdAt'], isA<Timestamp>());
      expect(doc['updatedAt'], isA<Timestamp>());
      expect(doc['createdBy'], 'admin');
    }
  });
  test('merge preserves reviews, unknown fields, aggregates, favorites and itinerary references', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestorePlaceRepository(db);
    final createdAt = Timestamp.fromDate(DateTime.utc(2020));
    await db.doc('places/sigiriya').set({
      ...places.first.toMap(),
      'name': 'Old metadata',
      'createdAt': createdAt,
      'createdBy': 'original-admin',
      'rating': 4.8,
      'reviewCount': 7,
      'customMetadata': {'preserved': true},
    });
    await db.doc('places/sigiriya/reviews/review-1').set({
      'comment': 'Keep review',
    });
    await db.doc('users/member/favorites/sigiriya').set({
      'placeId': 'sigiriya',
    });
    await db.doc('users/member/itineraries/trip').set({
      'placeIds': ['sigiriya'],
    });
    final result = await repo.importPredefined('admin');
    expect(result.created, 16);
    expect(result.updated, 1);
    final saved = (await db.doc('places/sigiriya').get()).data()!;
    expect(saved['name'], places.first.name);
    expect(saved['createdAt'], createdAt);
    expect(saved['createdBy'], 'original-admin');
    expect(saved['rating'], 4.8);
    expect(saved['reviewCount'], 7);
    expect(saved['customMetadata'], {'preserved': true});
    expect(
      (await db.doc('places/sigiriya/reviews/review-1').get())['comment'],
      'Keep review',
    );
    expect(
      (await db.doc('users/member/favorites/sigiriya').get())['placeId'],
      'sigiriya',
    );
    expect((await db.doc('users/member/itineraries/trip').get())['placeIds'], [
      'sigiriya',
    ]);
    final second = await repo.importPredefined('admin');
    expect(second.skipped, 17);
  });
  test('existing supplied long-ID documents are updated without duplicate legacy IDs', () async {
    final db = FakeFirebaseFirestore();
    final p = places.first;
    const alias = 'sigiriya-rock-fortress';
    await db.doc('places/$alias').set({
      ...p.toMap(),
      'id': alias,
      'name': 'Old',
    });
    await db.doc('places/$alias/reviews/keep').set({'comment': 'Keep'});
    final result = await FirestorePlaceRepository(db).importPredefined('admin');
    expect(result.created, 16);
    expect(result.updated, 1);
    expect((await db.collection('places').get()).docs, hasLength(17));
    expect((await db.doc('places/sigiriya').get()).exists, isFalse);
    expect((await db.doc('places/$alias').get())['id'], alias);
    expect((await db.doc('places/$alias/reviews/keep').get()).exists, isTrue);
  });
  test(
    'favorite IDs reconcile to imported metadata without changing references',
    () async {
      final repo = InMemoryPlaceRepository([fixtures.fixture]);
      final services = await fixtures.app(places: repo);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      services.discovery.favorites.addFavorite(fixtures.fixture);
      await services.catalog.importPredefined();
      await Future<void>.delayed(Duration.zero);
      expect(services.discovery.favorites.isFavorite('sigiriya'), isTrue);
      expect(
        services.discovery.favorites.getFavorites().single.description,
        places.first.description,
      );
    },
  );
  test(
    'manual create edit delete remain available alongside imported places',
    () async {
      final repo = InMemoryPlaceRepository();
      final services = await fixtures.app(places: repo);
      addTearDown(services.dispose);
      addTearDown(repo.dispose);
      await services.catalog.importPredefined();
      final manual = HeritagePlace.fromMap({
        ...places.first.toMap(),
        'id': 'manual-place',
        'name': 'Manual',
      });
      await services.catalog.save(manual, create: true);
      await services.catalog.save(
        manual.copyWith(name: 'Edited'),
        create: false,
      );
      expect(
        (await repo.list()).singleWhere((p) => p.id == 'manual-place').name,
        'Edited',
      );
      await services.catalog.delete('manual-place');
      expect(await repo.list(), hasLength(17));
    },
  );

  for (final place in [places.first, places[2]]) {
    testWidgets('${place.name} auto-fills all form fields without saving', (
      tester,
    ) async {
      final repo = InMemoryPlaceRepository();
      final services = await fixtures.app(places: repo);
      await fixtures.showApp(tester, services, AppRoutes.adminPlaceAdd);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('load-predefined-place')),
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: find.byKey(const ValueKey('load-predefined-place')),
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .items,
        hasLength(17),
      );
      dropdown.onChanged!(place.id);
      await tester.pumpAndSettle();
      final values = place.toMap();
      for (final entry in values.entries) {
        final field = find.byKey(ValueKey('place-field-${entry.key}'));
        if (field.evaluate().isEmpty) continue;
        final expected = entry.key == 'highlights'
            ? place.highlights.join('\n')
            : entry.value.toString();
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          expected,
          reason: entry.key,
        );
      }
      final category = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(ValueKey('place-category-${place.category}')),
      );
      expect(category.initialValue, place.category);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((s) => s.value),
        [true, place.isFeatured],
      );
      final image = tester.widget<PlaceImage>(find.byType(PlaceImage));
      expect(image.place.imagePath, place.imagePath);
      expect(await repo.list(activeOnly: false), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.dispose();
    });
  }
  testWidgets('auto-filled values remain editable and save under stable ID', (
    tester,
  ) async {
    final repo = InMemoryPlaceRepository();
    final services = await fixtures.app(places: repo);
    await fixtures.showApp(tester, services, AppRoutes.adminPlaceAdd);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('load-predefined-place')),
        )
        .onChanged!('sigiriya');
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('place-field-name'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Admin edited Sigiriya');
    await fixtures.press(tester, 'Save Place');
    final saved = (await repo.list()).single;
    expect(saved.id, 'sigiriya');
    expect(saved.name, 'Admin edited Sigiriya');
    expect(saved.highlights, places.first.highlights);
    expect(saved.imagePath, places.first.imagePath);
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });
  testWidgets('Edit keeps existing values and does not expose auto-fill', (
    tester,
  ) async {
    final original = places.first.copyWith(name: 'Keep admin edit');
    final repo = InMemoryPlaceRepository([original]);
    final services = await fixtures.app(places: repo);
    await fixtures.showApp(tester, services, AppRoutes.adminPlaces);
    await fixtures.press(tester, 'Edit');
    expect(find.byKey(const ValueKey('load-predefined-place')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('place-field-name')))
          .controller!
          .text,
      'Keep admin edit',
    );
    await tester.pumpWidget(const SizedBox());
    await repo.dispose();
  });
  testWidgets(
    'Import action requires confirmation, cancellation writes nothing',
    (tester) async {
      final repo = InMemoryPlaceRepository();
      final services = await fixtures.app(places: repo);
      await fixtures.showApp(tester, services, AppRoutes.adminPlaces);
      await fixtures.press(tester, 'Import All 17 Places');
      expect(
        find.text('Import all 17 predefined historical places?'),
        findsOneWidget,
      );
      await fixtures.press(tester, 'Cancel');
      expect(await repo.list(), isEmpty);
      await fixtures.press(tester, 'Import All 17 Places');
      await fixtures.press(tester, 'Import');
      expect(await repo.list(), hasLength(17));
      expect(find.text('Created 17; updated 0; skipped 0.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.dispose();
    },
  );
}
