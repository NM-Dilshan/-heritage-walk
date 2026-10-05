import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/features/discovery_planning/screens/explore_screen.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/discovery_planning/widgets/place_card.dart';
import 'package:heritage_walk/features/navigation_guide/screens/place_details_screen.dart';
import 'package:heritage_walk/features/reviews/models/place_review.dart';
import 'package:heritage_walk/features/reviews/services/review_repository.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

import 'support/part7_fakes.dart';
import 'support/part81_fakes.dart';

final catalog = List.generate(
  10,
  (i) => HeritagePlace.fromMap({
    ...DiscoveryService.localPlaces.first.toMap(),
    'id': 'place-$i',
    'name': 'Heritage ${i.toString().padLeft(2, '0')}',
    'city': i < 5 ? 'Galle' : 'Kandy',
    'district': i < 5 ? 'Southern District' : 'Central District',
    'category': i.isEven ? 'Forts' : 'Temples',
    'isFeatured': i < 2,
    'imagePath': 'assets/places/galle_fort_and_old_town.jpg',
    'rating': 5,
    'reviewCount': 999,
  }),
);
PlaceReview review({
  String uid = 'uid-1',
  String placeId = 'place-0',
  int rating = 4,
  String comment = 'A worthwhile visit.',
}) => PlaceReview(
  id: uid,
  userId: uid,
  placeId: placeId,
  userDisplayName: 'Traveler',
  rating: rating,
  comment: comment,
);

class ControlledPlaces extends InMemoryPlaceRepository {
  ControlledPlaces(super.initial);
  bool hold = false, fail = false;
  @override
  Stream<List<HeritagePlace>> watch({bool activeOnly = true}) => hold
      ? const Stream.empty()
      : fail
      ? Stream.error(const BackendFailure('Places unavailable.'))
      : super.watch(activeOnly: activeOnly);
}

class ControlledReviews extends InMemoryReviewRepository {
  ControlledReviews([super.initial]);
  bool hold = false, fail = false;
  Completer<void>? gate;
  int creates = 0;
  @override
  Stream<List<PlaceReview>> watchPlace(String placeId) => hold
      ? const Stream.empty()
      : fail
      ? Stream.error(const BackendFailure('Reviews unavailable.'))
      : super.watchPlace(placeId);
  @override
  Stream<List<PlaceReview>> watchAll() => hold
      ? const Stream.empty()
      : fail
      ? Stream.error(const BackendFailure('Reviews unavailable.'))
      : super.watchAll();
  @override
  Future<bool> create(PlaceReview review, String uid) async {
    creates++;
    if (gate != null) await gate!.future;
    return super.create(review, uid);
  }
}

Future<AppServices> app({
  PlaceRepository? places,
  ReviewRepository? reviews,
  bool admin = false,
  FakeLiveRoles? roles,
}) async {
  final account = FakeAccount();
  await account.register('Traveler One', 'one@example.test', 'Secure123');
  account.profiles[account.current!] = UserProfile.fromMap({
    ...account.profiles[account.current!]!.toMap(),
    'role': admin ? 'admin' : 'user',
  });
  final repo = places ?? InMemoryPlaceRepository(catalog),
      reviewRepo = reviews ?? InMemoryReviewRepository();
  final services = AppServices(
    account: account,
    places: repo,
    reviews: reviewRepo,
    roles: roles,
  );
  await services.profile.ready;
  await Future<void>.value();
  await Future<void>.value();
  final widgetOwned = TestWidgetsFlutterBinding.instance.inTest;
  addTearDown(() {
    if (!widgetOwned) {
      services.dispose();
    }
  });
  if (repo is InMemoryPlaceRepository) addTearDown(repo.dispose);
  if (reviewRepo is InMemoryReviewRepository) addTearDown(reviewRepo.dispose);
  return services;
}

Future<void> mount(
  WidgetTester tester,
  AppServices services,
  String route,
) async {
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: route),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> details(WidgetTester tester, AppServices services) async {
  await mount(tester, services, AppRoutes.home);
  await press(tester, catalog.first.name);
}

Future<void> query(WidgetTester tester, String value) async {
  await tester.enterText(
    find.widgetWithText(HeritageTextField, 'Search heritage places...'),
    value,
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Featured subset is deterministic limited active and independent of query',
    () {
      expect(featuredPlaces(catalog).map((p) => p.id), [
        'place-0',
        'place-1',
        'place-2',
        'place-3',
      ]);
      expect(featuredPlaces(catalog.reversed).map((p) => p.id), [
        'place-0',
        'place-1',
        'place-2',
        'place-3',
      ]);
      expect(
        featuredPlaces([catalog.first.copyWith(isActive: false)]),
        isEmpty,
      );
    },
  );
  testWidgets('Home shows only four of ten places and dashboard shortcuts', (
    tester,
  ) async {
    await mount(tester, await app(), AppRoutes.home);
    expect(find.byType(PlaceCard), findsNWidgets(4));
    expect(find.text('Featured Places'), findsOneWidget);
    expect(find.text(catalog.last.name), findsNothing);
    expect(find.text('Popular Heritage Sites'), findsNothing);
    expect(find.byType(HeritageTextField), findsNothing);
    expect(find.text('Explore All Places'), findsOneWidget);
  });
  testWidgets('Home featured card opens existing details directly', (
    tester,
  ) async {
    await details(tester, await app());
    expect(find.byType(PlaceDetailsScreen), findsOneWidget);
  });
  testWidgets(
    'Explore shows all active places while excluding inactive records',
    (tester) async {
      final repo = InMemoryPlaceRepository([
        ...catalog,
        catalog.first.copyWith(isActive: false),
      ]);
      await mount(tester, await app(places: repo), AppRoutes.explore);
      expect(find.byType(PlaceCard), findsNWidgets(9));
      expect(find.text(catalog.first.name), findsNothing);
    },
  );
  for (final term in ['Heritage 09', 'Kandy', 'Central District', 'Temples']) {
    testWidgets('Explore searches supported field: $term', (tester) async {
      await mount(tester, await app(), AppRoutes.explore);
      await query(tester, term);
      expect(
        find.byType(PlaceCard),
        findsNWidgets(term == 'Heritage 09' ? 1 : 5),
      );
    });
  }
  testWidgets('Explore category filter and All restore the complete catalog', (
    tester,
  ) async {
    await mount(tester, await app(), AppRoutes.explore);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Temples'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(5));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(10));
  });
  testWidgets(
    'Home Explore All resets query and filter and replaces tab stack',
    (tester) async {
      final services = await app();
      services.discovery.discovery.setQuery('nothing');
      services.discovery.discovery.setCategory('Temples');
      await mount(tester, services, AppRoutes.home);
      expect(find.byType(PlaceCard), findsNWidgets(4));
      await press(tester, 'Explore All Places');
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(PlaceCard), findsNWidgets(10));
      expect(services.discovery.discovery.query, '');
      expect(services.discovery.discovery.category, 'All');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(
        Navigator.of(tester.element(find.byType(ExploreScreen))).canPop(),
        false,
      );
    },
  );
  testWidgets(
    'Home category opens Explore with matching filter and selected tab',
    (tester) async {
      final services = await app();
      await mount(tester, services, AppRoutes.home);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Forts'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Forts'));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(PlaceCard), findsNWidgets(5));
      expect(services.discovery.discovery.category, 'Forts');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
  );
  testWidgets('Favorite changes synchronize Explore Home and Favorites', (
    tester,
  ) async {
    final services = await app();
    await mount(tester, services, AppRoutes.explore);
    final save = find.byTooltip('Save ${catalog.first.name} to favorites');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await press(tester, 'Home');
    expect(
      find.byTooltip('Remove ${catalog.first.name} from favorites'),
      findsOneWidget,
    );
    final favorites = find.byTooltip('My Favorites');
    await tester.tap(favorites);
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsOneWidget);
    final remove = find.byTooltip(
      'Remove ${catalog.first.name} from favorites',
    );
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(services.discovery.favorites.isFavorite(catalog.first.id), false);
  });
  for (final route in [AppRoutes.home, AppRoutes.explore]) {
    testWidgets('$route loading remains usable', (tester) async {
      final repo = ControlledPlaces(catalog)..hold = true;
      final services = await app(places: repo);
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: route),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      if (route == AppRoutes.home) {
        expect(find.text('Explore All Places'), findsOneWidget);
      }
    });
    testWidgets('$route empty state works without a catalog', (tester) async {
      await mount(tester, await app(places: InMemoryPlaceRepository()), route);
      expect(find.byType(PlaceCard), findsNothing);
      expect(
        find.text(
          route == AppRoutes.home
              ? 'No active places yet. Explore will show the catalog when it is available.'
              : 'No places available',
        ),
        findsOneWidget,
      );
    });
    testWidgets('$route error state supports reload', (tester) async {
      final repo = ControlledPlaces(catalog)..fail = true;
      final services = await app(places: repo);
      await mount(tester, services, route);
      expect(find.text('Places unavailable.'), findsOneWidget);
      repo.fail = false;
      await press(tester, 'Reload places');
      expect(
        find.byType(PlaceCard),
        findsNWidgets(route == AppRoutes.home ? 4 : 10),
      );
    });
  }
  testWidgets('Explore no-search-results differs from empty catalog', (
    tester,
  ) async {
    await mount(tester, await app(), AppRoutes.explore);
    await query(tester, 'not anywhere');
    expect(find.text('No places found'), findsOneWidget);
  });
  testWidgets('Live admin catalog changes appear in Explore', (tester) async {
    final repo = InMemoryPlaceRepository(catalog),
        services = await app(places: repo, admin: true);
    await mount(tester, services, AppRoutes.explore);
    await services.catalog.save(
      HeritagePlace.fromMap({
        ...catalog.first.toMap(),
        'id': 'new',
        'name': 'New Active Place',
      }),
      create: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(11));
    await services.catalog.save(
      catalog[1].copyWith(isActive: false),
      create: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(10));
  });
  test('Review model serializes timestamps and masks email display names', () {
    final date = DateTime.utc(2026, 10, 5);
    final r = PlaceReview.fromMap({
      ...review().toMap(),
      'createdAt': Timestamp.fromDate(date),
      'updatedAt': date,
      'userDisplayName': 'person@example.com',
    });
    expect(r.createdAt, date);
    expect(r.userDisplayName, 'Traveler');
    expect(PlaceReview.fromMap(r.toMap()).updatedAt, date);
    expect(r.id, r.userId);
  });
  test('Review validates rating range empty comments and maximum length', () {
    for (final rating in [null, 0, 6]) {
      expect(PlaceReview.validate(rating, 'Good'), isNotNull);
    }
    for (final rating in [1, 2, 3, 4, 5]) {
      expect(PlaceReview.validate(rating, 'Good'), null);
    }
    expect(PlaceReview.validate(3, ' \n '), isNotNull);
    expect(PlaceReview.validate(3, 'x' * 1001), isNotNull);
    expect(PlaceReview.validate(3, 'x' * 1000), null);
    expect(
      PlaceReview.fromMap({...review().toMap(), 'rating': 2.5}).isValid,
      false,
    );
  });
  test('Create one review per user/place with trimmed comment', () async {
    final services = await app();
    await services.reviews.save('place-0', 5, ' Great place ', create: true);
    await Future<void>.delayed(Duration.zero);
    expect(services.reviews.feed('place-0').reviewCount, 1);
    expect(services.reviews.own('place-0')!.comment, 'Great place');
    await expectLater(
      services.reviews.save('place-0', 3, 'Duplicate', create: true),
      throwsA(isA<BackendFailure>()),
    );
    await services.reviews.save('place-1', 3, 'Other place', create: true);
    await Future<void>.delayed(Duration.zero);
    expect(services.reviews.feed('place-1').reviewCount, 1);
  });
  test('Read aggregate updates after own edit and delete with immutable creation audit', () async {
    final repo = InMemoryReviewRepository();
    await repo.create(review(uid: 'other', rating: 2), 'other');
    final services = await app(reviews: repo);
    await services.reviews.save('place-0', 4, 'Original', create: true);
    await Future<void>.delayed(Duration.zero);
    final created = services.reviews.own('place-0')!.createdAt;
    expect(services.reviews.feed('place-0').averageRating, 3);
    expect(services.reviews.feed('place-0').reviewCount, 2);
    await services.reviews.save('place-0', 5, 'Edited', create: false);
    await Future<void>.delayed(Duration.zero);
    expect(services.reviews.feed('place-0').averageRating, 3.5);
    expect(services.reviews.own('place-0')!.createdAt, created);
    await services.reviews.delete(services.reviews.own('place-0')!);
    await Future<void>.delayed(Duration.zero);
    expect(services.reviews.feed('place-0').averageRating, 2);
    expect(services.reviews.feed('place-0').reviewCount, 1);
  });
  test(
    'Other user cannot edit or delete review and normal user cannot moderate',
    () async {
      final r = review(uid: 'other');
      final repo = InMemoryReviewRepository([r]);
      final services = await app(reviews: repo);
      await expectLater(
        repo.update(r, 'uid-1'),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        services.reviews.delete(r),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        services.reviews.delete(r, moderate: true),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test('Trusted admin may moderate but does not edit another review', () async {
    final repo = InMemoryReviewRepository([review(uid: 'other')]);
    final services = await app(reviews: repo, admin: true);
    expect(services.reviews.adminReviews, hasLength(1));
    await expectLater(
      repo.update(review(uid: 'other'), 'uid-1'),
      throwsA(isA<BackendFailure>()),
    );
    await services.reviews.delete(review(uid: 'other'), moderate: true);
    await Future<void>.delayed(Duration.zero);
    expect(services.reviews.adminReviews, isEmpty);
  });
  test(
    'Duplicate review submission is blocked while save is pending',
    () async {
      final repo = ControlledReviews()..gate = Completer<void>();
      final services = await app(reviews: repo);
      final pending = services.reviews.save('place-0', 4, 'Good', create: true);
      expect(services.reviews.busy, true);
      await expectLater(
        services.reviews.save('place-0', 2, 'Again', create: true),
        throwsA(isA<BackendFailure>()),
      );
      expect(repo.creates, 1);
      repo.gate!.complete();
      await pending;
      expect(services.reviews.busy, false);
    },
  );
  test('Logout clears review feeds and denies writes', () async {
    final services = await app(reviews: InMemoryReviewRepository([review()]));
    await services.profile.signOut();
    expect(services.reviews.feed('place-0').reviews, isEmpty);
    await expectLater(
      services.reviews.save('place-0', 4, 'Good', create: true),
      throwsA(isA<BackendFailure>()),
    );
  });
  test(
    'Deleted place disallows create/edit and still allows own review deletion',
    () async {
      final places = InMemoryPlaceRepository(catalog),
          services = await app(
            places: places,
            reviews: InMemoryReviewRepository([review()]),
          );
      await places.delete('place-0');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        services.reviews.save('place-0', 3, 'Edited', create: false),
        throwsA(isA<BackendFailure>()),
      );
      await services.reviews.delete(review());
    },
  );
  test(
    'Admin role revocation removes moderation and hides admin reviews',
    () async {
      final roles = FakeLiveRoles('admin'),
          services = await app(
            roles: roles,
            reviews: InMemoryReviewRepository([review(uid: 'other')]),
          );
      addTearDown(roles.changes.close);
      roles.set('user');
      await Future<void>.delayed(Duration.zero);
      expect(services.reviews.adminReviews, isEmpty);
      await expectLater(
        services.reviews.delete(review(uid: 'other'), moderate: true),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  testWidgets('Details no-review state replaces all demo ratings', (
    tester,
  ) async {
    await details(tester, await app());
    expect(
      find.text('No reviews yet. Be the first to share your experience.'),
      findsOneWidget,
    );
    expect(find.textContaining('demo reviews'), findsNothing);
    expect(find.text('Write a Review'), findsOneWidget);
  });
  testWidgets('Reviews loading state', (tester) async {
    final services = await app(reviews: ControlledReviews()..hold = true);
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.home),
    );
    await tester.pump();
    final context = tester.element(find.byType(HomeScreen));
    Navigator.pushNamed(
      context,
      AppRoutes.placeDetails,
      arguments: catalog.first,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
  testWidgets('Reviews error state retries successfully', (tester) async {
    final repo = ControlledReviews()..fail = true;
    await details(tester, await app(reviews: repo));
    expect(find.text('Reviews unavailable.'), findsOneWidget);
    repo.fail = false;
    await press(tester, 'Reload reviews');
    expect(
      find.text('No reviews yet. Be the first to share your experience.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Home and Explore show same real review mean and count ignoring legacy rating',
    (tester) async {
      final services = await app(
        reviews: InMemoryReviewRepository([
          review(rating: 5),
          review(uid: 'other', rating: 2),
        ]),
      );
      await mount(tester, services, AppRoutes.home);
      expect(find.text('? 3.5 (2)'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
      await press(tester, 'Explore All Places');
      expect(find.text('? 3.5 (2)'), findsOneWidget);
    },
  );
  testWidgets('Review form creates edits and confirms deletion', (
    tester,
  ) async {
    final services = await app();
    await details(tester, services);
    await press(tester, 'Write a Review');
    await press(tester, 'Save Review');
    expect(find.text('Write a comment.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 stars').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your experience'),
      'A real test experience',
    );
    await press(tester, 'Save Review');
    expect(find.text('A real test experience'), findsOneWidget);
    await press(tester, 'Edit Review');
    expect(
      find.widgetWithText(TextFormField, 'A real test experience'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your experience'),
      'Updated experience',
    );
    await press(tester, 'Save Review');
    expect(find.text('Updated experience'), findsOneWidget);
    await press(tester, 'Delete Review');
    await press(tester, 'Cancel');
    expect(find.text('Updated experience'), findsOneWidget);
    await press(tester, 'Delete Review');
    await press(tester, 'Delete');
    expect(services.reviews.feed('place-0').reviewCount, 0);
  });
  testWidgets('Normal user is denied review moderation route', (tester) async {
    await mount(tester, await app(), AppRoutes.adminReviews);
    expect(find.text('Admin access required'), findsOneWidget);
  });
  testWidgets(
    'Admin moderation searches and deletes a review of a missing place',
    (tester) async {
      final services = await app(
        admin: true,
        reviews: InMemoryReviewRepository([
          review(uid: 'other', placeId: 'deleted'),
        ]),
      );
      await mount(tester, services, AppRoutes.adminReviews);
      expect(find.text('Unavailable place'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search reviews'),
        'not matching',
      );
      await tester.pumpAndSettle();
      expect(find.text('No reviews match this view.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search reviews'),
        '',
      );
      await tester.pumpAndSettle();
      await press(tester, 'Delete Review');
      await press(tester, 'Delete');
      expect(services.reviews.adminReviews, isEmpty);
    },
  );
  testWidgets(
    'Moderation resets a removed place filter after deleting its last review',
    (tester) async {
      final services = await app(
        admin: true,
        reviews: InMemoryReviewRepository([
          review(uid: 'other'),
          review(uid: 'another', placeId: 'place-1'),
        ]),
      );
      await mount(tester, services, AppRoutes.adminReviews);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(catalog.first.name).last);
      await tester.pumpAndSettle();
      expect(find.text('Delete Review'), findsOneWidget);
      await press(tester, 'Delete Review');
      await press(tester, 'Delete');
      expect(find.text('All places'), findsOneWidget);
      expect(find.text(catalog[1].name), findsWidgets);
      expect(find.text('Delete Review'), findsOneWidget);
      await services.reviews.repository.create(
        review(uid: 'returning'),
        'returning',
      );
      await tester.pumpAndSettle();
      expect(find.text('All places'), findsOneWidget);
      expect(find.text('Delete Review'), findsNWidgets(2));
      expect(tester.takeException(), null);
    },
  );
  for (final route in [AppRoutes.home, AppRoutes.explore]) {
    testWidgets('$route compact large-text layout has no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, await app(), route);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    });
  }
}
