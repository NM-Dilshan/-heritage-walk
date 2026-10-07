import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/core/localization/app_localizations.dart';
import 'package:heritage_walk/features/navigation_guide/services/navigation_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/location_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/routing_service.dart';
import 'package:heritage_walk/features/navigation_guide/screens/navigation_screen.dart';
import 'package:heritage_walk/features/navigation_guide/screens/place_details_screen.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/heritage_map.dart';
import 'package:heritage_walk/features/navigation_guide/models/route_info.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/group_support/services/group_location_service.dart';
import 'package:heritage_walk/features/group_support/screens/language_selection_screen.dart';
import 'package:heritage_walk/features/group_support/widgets/language_option_card.dart';
import 'package:heritage_walk/features/reviews/models/place_review.dart';
import 'package:heritage_walk/features/reviews/services/review_repository.dart';

import 'support/part9_fakes.dart';
import 'support/part7_fakes.dart';

HeritagePlace destination() => coordinatePlace(DiscoveryService().places.first);
const responseBody =
    '{"code":"Ok","routes":[{"distance":3800,"duration":600,"geometry":{"type":"LineString","coordinates":[[80.218,6.032],[80.219,6.03],[80.217,6.026]]}}]}';
Future<AppServices> signedServices({
  FakeGps? gps,
  GroupLocationRepository? locations,
}) async {
  final account = FakeAccount();
  await account.register('Alice', 'alice@test.com', 'Secure123');
  final services = AppServices(
    account: account,
    location: gps ?? FakeGps(),
    routing: FakeRouting(),
    groupLocations: locations,
  );
  await services.profile.ready;
  return services;
}

Future<void> pumpNavigation(
  WidgetTester tester,
  AppServices services, {
  HeritagePlace? place,
}) async {
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: AppRoutes.map),
  );
  await tester.pump();
  if (place != null) {
    services.navigation.navigation.selectDestination(place);
  }
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a freshly restored cloud preference sets the actual app locale',
    (tester) async {
      final account = FakeAccount(), data = FakeData();
      await account.register('Alice', 'alice@test.com', 'Secure123');
      final first = AppServices(account: account, data: data);
      await first.profile.ready;
      first.language.setLanguage('ta');
      await first.sync!.flush();
      first.dispose();
      final restored = AppServices(account: account, data: data);
      await restored.profile.ready;
      expect(restored.language.selectedLanguageCode, 'ta');
      await tester.pumpWidget(
        HeritageWalkApp(services: restored, initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('ta'));
      expect(find.text(l.get('Home')), findsWidgets);
      expect(find.text(l.get('Explore Sri Lanka')), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('ta'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'returning from permission settings retries the real location flow',
    (tester) async {
      final gps = FakeGps(failure: LocationState.deniedForever);
      final services = AppServices(location: gps, routing: FakeRouting());
      await pumpNavigation(tester, services, place: destination());
      await press(tester, find.text('Open Settings'));
      expect(gps.settingsCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gps.failure = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(services.navigation.navigation.currentPosition, gps.fix);
      expect(services.navigation.navigation.path, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.paused]) {
    testWidgets('pending initial GPS handles $state without a fabricated fix', (
      tester,
    ) async {
      final gps = FakeGps()..pending = Completer();
      final services = AppServices(location: gps, routing: FakeRouting());
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: AppRoutes.map),
      );
      await tester.pump();
      services.navigation.navigation.selectDestination(destination());
      expect(
        services.navigation.navigation.locationState,
        LocationState.loading,
      );
      tester.binding.handleAppLifecycleStateChanged(state);
      gps.pending!.complete(gps.fix);
      await tester.pumpAndSettle();
      final navigation = services.navigation.navigation;
      if (state == AppLifecycleState.inactive) {
        expect(navigation.currentPosition, gps.fix);
        expect(navigation.path, isNotNull);
      } else {
        expect(navigation.currentPosition, isNull);
        expect(navigation.path, isNull);
        expect(navigation.locationState, LocationState.unavailable);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    });
  }
  group('GPS and route state', () {
    late FakeGps gps;
    late FakeRouting routing;
    late NavigationService navigation;
    setUp(() {
      gps = FakeGps();
      routing = FakeRouting();
      navigation = NavigationService(location: gps, routing: routing);
    });
    tearDown(() async {
      navigation.dispose();
      await gps.dispose();
    });
    test('starts with no invented current position or route', () {
      expect(navigation.locationState, LocationState.notRequested);
      expect(navigation.currentPosition, isNull);
      expect(navigation.path, isNull);
      expect(navigation.start(), isFalse);
    });
    test('loading is explicit until the fix arrives', () async {
      gps.pending = Completer();
      final request = navigation.locate();
      expect(navigation.locationState, LocationState.loading);
      gps.pending!.complete(gps.fix);
      await request;
      expect(navigation.locationState, LocationState.granted);
    });
    for (final state in [
      LocationState.denied,
      LocationState.deniedForever,
      LocationState.servicesOff,
      LocationState.unavailable,
      LocationState.timeout,
      LocationState.error,
    ]) {
      test('GPS $state never fabricates coordinates', () async {
        gps.failure = state;
        navigation.selectDestination(destination());
        await navigation.locate();
        expect(navigation.locationState, state);
        expect(navigation.currentPosition, isNull);
        expect(routing.calls, 0);
      });
    }
    test('successful fix is exactly the device coordinate', () async {
      await navigation.locate();
      expect(navigation.currentPosition, gps.fix);
    });
    test('selected destination coordinates are sent to routing', () async {
      final place = destination();
      navigation.selectDestination(place);
      await navigation.locate();
      expect(routing.start, gps.fix);
      expect(routing.destination, LatLng(place.latitude!, place.longitude!));
      expect(navigation.destination!.id, place.id);
    });
    for (final coords in [
      (null, 80.0),
      (6.0, null),
      (91.0, 80.0),
      (6.0, 181.0),
      (double.nan, 80.0),
      (6.0, double.infinity),
    ]) {
      test('invalid destination $coords disables routing', () async {
        navigation.selectDestination(
          coordinatePlace(
            destination(),
            latitude: coords.$1,
            longitude: coords.$2,
          ),
        );
        await navigation.locate();
        expect(navigation.validDestination, isFalse);
        expect(routing.calls, 0);
        expect(navigation.route, isNull);
      });
    }
    test(
      'geometry distance and duration come from the route response',
      () async {
        navigation.selectDestination(destination());
        await navigation.locate();
        expect(navigation.path!.points.length, 3);
        expect(navigation.route!.distanceKm, 3.8);
        expect(navigation.route!.minutes, 10);
      },
    );
    for (final failure in RouteFailure.values) {
      test('routing $failure leaves no fake result', () async {
        routing.failure = failure;
        navigation.selectDestination(destination());
        await navigation.locate();
        expect(navigation.routeFailure, failure);
        expect(navigation.route, isNull);
        expect(navigation.loadingRoute, isFalse);
      });
    }
    test('retry recovers from route failure', () async {
      routing.failure = RouteFailure.server;
      navigation.selectDestination(destination());
      await navigation.locate();
      routing.failure = null;
      await navigation.calculateRoute();
      expect(navigation.route, isNotNull);
      expect(navigation.routeFailure, isNull);
    });
    test('start guidance watches GPS without rerouting every fix', () async {
      navigation.selectDestination(destination());
      await navigation.locate();
      expect(navigation.start(), isTrue);
      gps.updates.add(const LatLng(6.034, 80.22));
      await flushGps();
      expect(navigation.currentPosition, const LatLng(6.034, 80.22));
      expect(routing.calls, 1);
    });
    test('end cancels the GPS subscription', () async {
      navigation.selectDestination(destination());
      await navigation.locate();
      navigation.start();
      navigation.end();
      await flushGps();
      expect(gps.cancellations, 1);
      expect(navigation.isActive, isFalse);
    });
    test('suspending the screen cancels updates', () async {
      navigation.selectDestination(destination());
      await navigation.locate();
      navigation.start();
      navigation.suspend();
      await flushGps();
      expect(gps.cancellations, 1);
    });
    test(
      'changing destination during GPS acquisition preserves eventual fix',
      () async {
        gps.pending = Completer();
        final work = navigation.locate();
        navigation.selectDestination(destination());
        gps.pending!.complete(gps.fix);
        await work;
        expect(navigation.path, isNotNull);
      },
    );
    test('stale route response cannot overwrite a new destination', () async {
      routing.pending = Completer();
      navigation.selectDestination(destination());
      final work = navigation.locate();
      await flushGps();
      navigation.clear();
      routing.pending!.complete(RoutedPath([gps.fix, gps.fix], 1, 1));
      await work;
      expect(navigation.path, isNull);
      expect(navigation.destination, isNull);
    });
    test('walking selects the actual walking routing profile', () async {
      navigation.selectDestination(destination());
      await navigation.locate();
      navigation.selectMode(TravelMode.walking);
      await flushGps();
      expect(routing.mode, TravelMode.walking);
      expect(navigation.route!.minutes, 58);
    });
  });
  group('routing parser and transport', () {
    test('GeoJSON longitude latitude ordering is decoded correctly', () {
      final route = RoutedPath.decode(responseBody);
      expect(route.points.first, const LatLng(6.032, 80.218));
      expect(route.distanceMeters, 3800);
      expect(route.durationSeconds, 600);
    });
    for (final body in [
      '{}',
      'not JSON',
      '{"code":"Ok","routes":[]}',
      '{"code":"Ok","routes":[{"distance":-1,"duration":2,"geometry":{}}]}',
    ]) {
      test('reject malformed or empty route $body', () {
        expect(() => RoutedPath.decode(body), throwsA(isA<RoutingException>()));
      });
    }
    test('NoRoute is distinct from malformed data', () {
      expect(
        () => RoutedPath.decode('{"code":"NoRoute"}'),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.reason,
            'reason',
            RouteFailure.noRoute,
          ),
        ),
      );
    });
    test(
      'HTTP service uses car endpoint user agent and actual metrics',
      () async {
        final service = FossgisRoutingService(
          client: MockClient((request) async {
            expect(request.url.path, contains('/routed-car/'));
            expect(request.url.queryParameters['geometries'], 'geojson');
            expect(request.headers['User-Agent'], contains('HeritageWalk'));
            return http.Response(responseBody, 200);
          }),
        );
        addTearDown(service.dispose);
        final result = await service.route(
          const LatLng(6, 80),
          const LatLng(7, 81),
          TravelMode.driving,
        );
        expect(result.distanceMeters, 3800);
      },
    );
    test('HTTP walking endpoint is independent from car profile', () async {
      final service = FossgisRoutingService(
        client: MockClient((r) async {
          expect(r.url.path, contains('/routed-foot/'));
          return http.Response(responseBody, 200);
        }),
      );
      addTearDown(service.dispose);
      await service.route(
        const LatLng(6, 80),
        const LatLng(7, 81),
        TravelMode.walking,
      );
    });
    test('route cache prevents repeated identical requests', () async {
      var calls = 0;
      final service = FossgisRoutingService(
        client: MockClient((r) async {
          calls++;
          return http.Response(responseBody, 200);
        }),
      );
      addTearDown(service.dispose);
      for (var i = 0; i < 3; i++) {
        await service.route(
          const LatLng(6, 80),
          const LatLng(7, 81),
          TravelMode.driving,
        );
      }
      expect(calls, 1);
    });
    test('server status is exposed as a server failure', () async {
      final service = FossgisRoutingService(
        client: MockClient((r) async => http.Response('Unavailable', 503)),
      );
      addTearDown(service.dispose);
      expect(
        service.route(
          const LatLng(6, 80),
          const LatLng(7, 81),
          TravelMode.driving,
        ),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.reason,
            'reason',
            RouteFailure.server,
          ),
        ),
      );
    });
    test('transport timeout is exposed accurately', () async {
      final service = FossgisRoutingService(
        client: MockClient((r) async => throw TimeoutException('test')),
      );
      addTearDown(service.dispose);
      expect(
        service.route(
          const LatLng(6, 80),
          const LatLng(7, 81),
          TravelMode.driving,
        ),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.reason,
            'reason',
            RouteFailure.timeout,
          ),
        ),
      );
    });
  });
  group('group consent sessions', () {
    late AppServices services;
    late FakeGps gps;
    late MemoryGroupLocationRepository repo;
    late GroupLocationSession session;
    setUp(() async {
      gps = FakeGps();
      repo = MemoryGroupLocationRepository();
      services = await signedServices(gps: gps, locations: repo);
      final group = services.groups.createGroup('Friends', destination());
      session = GroupLocationSession(services.groups, repo, gps, group.id);
    });
    tearDown(() async {
      session.dispose();
      await flushGps();
      services.dispose();
      repo.dispose();
      await gps.dispose();
    });
    test('login and opening tracking never start GPS or writes', () {
      expect(session.sharing, isFalse);
      expect(gps.currentCalls, 0);
      expect(repo.values, isEmpty);
    });
    test(
      'explicit start publishes only the current authenticated UID',
      () async {
        await session.start();
        expect(session.sharing, isTrue);
        expect(repo.values[session.groupId]!.keys, [
          services.groups.currentUserId,
        ]);
        expect(gps.watches, 1);
      },
    );
    test('stop removes the snapshot and cancels GPS', () async {
      await session.start();
      await session.stop();
      expect(repo.values[session.groupId], isEmpty);
      expect(gps.cancellations, 1);
      expect(session.sharing, isFalse);
    });
    test('queued late fix cannot publish after stop', () async {
      gps.pending = Completer();
      final start = session.start();
      await flushGps();
      await session.stop();
      gps.pending!.complete(gps.fix);
      await start;
      expect(repo.values, isEmpty);
      expect(gps.watches, 0);
    });
    test('denied permission does not publish', () async {
      gps.failure = LocationState.denied;
      await session.start();
      expect(repo.values, isEmpty);
      expect(session.locationState, LocationState.denied);
    });
    test('leaving or deleting a group stops sharing', () async {
      await session.start();
      services.groups.deleteGroup(session.groupId);
      await flushGps();
      expect(session.sharing, isFalse);
      expect(repo.values[session.groupId], isEmpty);
    });
    test('signout cancels the sharing session', () async {
      await session.start();
      await services.profile.signOut();
      await flushGps();
      expect(session.sharing, isFalse);
      expect(gps.cancellations, 1);
    });
    test('stale and missing snapshots never become live markers', () async {
      repo.values[session.groupId] = {
        'uid-1': SharedLocation(
          'uid-1',
          'Alice',
          gps.fix,
          DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      };
      repo.changes.add(session.groupId);
      await flushGps();
      expect(session.freshLocations, isEmpty);
    });
    test('current member snapshot appears on the live feed', () async {
      await session.start();
      await flushGps();
      expect(
        session.freshLocations.single.userId,
        services.groups.currentUserId,
      );
    });
    test('snapshots of removed members are filtered', () async {
      repo.values[session.groupId] = {
        'stranger': SharedLocation(
          'stranger',
          'Stranger',
          gps.fix,
          DateTime.now(),
        ),
      };
      repo.changes.add(session.groupId);
      await flushGps();
      expect(session.freshLocations, isEmpty);
    });
    test('email-like display names are replaced by a safe label', () async {
      final account = services.profile.repository as FakeAccount;
      account.profiles[account.current!] = account.profiles[account.current!]!
          .copyWith(fullName: 'private@example.com');
      await services.profile.update(account.profiles[account.current!]!);
      await session.start();
      expect(
        repo.values[session.groupId]!.values.single.displayName,
        'Traveler',
      );
    });
    test('rapid GPS updates are rate limited', () async {
      await session.start();
      final original = repo.values[session.groupId]!.values.single.position;
      gps.updates.add(const LatLng(6.04, 80.23));
      await flushGps();
      expect(repo.values[session.groupId]!.values.single.position, original);
    });
  });
  group('localized resources', () {
    for (final code in ['en', 'si', 'ta']) {
      test('$code delegate and complete resources', () async {
        final messages = await AppLocalizations.delegate.load(Locale(code));
        expect(messages.locale.languageCode, code);
        expect(messages.messages.length, greaterThan(500));
        expect(
          messages.get('Home'),
          code == 'en'
              ? 'Home'
              : code == 'si'
              ? 'මුල් පිටුව'
              : 'முகப்பு',
        );
      });
      test('$code JSON keys match English and translations are nonempty', () {
        final english =
            jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map;
        final target = jsonDecode(
          File('assets/l10n/$code.json').readAsStringSync(),
        ) as Map;
        expect(target.keys.toSet(), english.keys.toSet());
        expect(
          target.values.every((v) => v is String && v.trim().isNotEmpty),
          isTrue,
        );
      });
    }
    test('placeholder user content stays in the original language', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ta'));
      expect(
        l.format('Destination: {0}', ['Galle Fort']),
        'சேருமிடம்: Galle Fort',
      );
    });
    test('Cloud validation errors use the selected locale', () async {
      final l = await AppLocalizations.delegate.load(const Locale('si'));
      expect(l.get('Email is required'), 'විද්‍යුත් තැපෑල අවශ්‍යයි');
    });
  });
  testWidgets(
    'navigation shows both actual markers route polyline and routed metrics',
    (tester) async {
      final s = AppServices(location: FakeGps(), routing: FakeRouting());
      await pumpNavigation(tester, s, place: destination());
      final map = tester.widget<HeritageMap>(find.byType(HeritageMap));
      expect(map.markers.map((m) => m.id), ['current', 'destination']);
      expect(map.current, const LatLng(6.032, 80.218));
      expect(map.route.length, 3);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text('Distance: 3.8 km'), findsOneWidget);
      expect(find.text('Estimated time: 10 min'), findsOneWidget);
    },
  );
  testWidgets('screen displays permission action for denied GPS', (
    tester,
  ) async {
    await pumpNavigation(
      tester,
      AppServices(
        location: FakeGps(failure: LocationState.denied),
        routing: FakeRouting(),
      ),
      place: destination(),
    );
    expect(find.text('Allow Location'), findsOneWidget);
    expect(find.byKey(const ValueKey('marker-current')), findsNothing);
  });
  testWidgets('screen opens app settings for permanently denied GPS', (
    tester,
  ) async {
    final gps = FakeGps(failure: LocationState.deniedForever);
    await pumpNavigation(
      tester,
      AppServices(location: gps, routing: FakeRouting()),
    );
    await press(tester, find.text('Open Settings'));
    expect(gps.settingsCalls, 1);
  });
  testWidgets('screen offers device location settings when GPS is off', (
    tester,
  ) async {
    await pumpNavigation(
      tester,
      AppServices(
        location: FakeGps(failure: LocationState.servicesOff),
        routing: FakeRouting(),
      ),
    );
    expect(find.text('Enable Location'), findsOneWidget);
  });
  testWidgets('invalid place coordinates have an honest disabled route state', (
    tester,
  ) async {
    await pumpNavigation(
      tester,
      AppServices(location: FakeGps(), routing: FakeRouting()),
      place: coordinatePlace(destination(), latitude: null),
    );
    expect(
      find.text('Location information is unavailable for this destination.'),
      findsOneWidget,
    );
    expect(find.text('Start Route Guidance'), findsNothing);
  });
  testWidgets('starting route guidance keeps the map and starts live GPS', (
    tester,
  ) async {
    final gps = FakeGps();
    await pumpNavigation(
      tester,
      AppServices(location: gps, routing: FakeRouting()),
      place: destination(),
    );
    await press(tester, find.text('Start Route Guidance'));
    expect(find.text('Route guidance active'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(gps.cancellations, 1);
  });
  for (final route in [AppRoutes.home, AppRoutes.explore]) {
    testWidgets('$route to details to navigation preserves exact destination', (
      tester,
    ) async {
      final s = AppServices(location: FakeGps(), routing: FakeRouting());
      final place = destination();
      s.discovery.discovery.replaceCatalog([place]);
      await tester.pumpWidget(
        HeritageWalkApp(services: s, initialRoute: route),
      );
      await tester.pumpAndSettle();
      await press(tester, find.text(place.name));
      expect(find.byType(PlaceDetailsScreen), findsOneWidget);
      await press(tester, find.text('Start Navigation'));
      expect(find.byType(NavigationScreen), findsOneWidget);
      expect(s.navigation.navigation.destination!.id, place.id);
      expect(s.navigation.navigation.path, isNotNull);
    });
  }
  testWidgets('language selection changes the actual app navigation', (
    tester,
  ) async {
    final s = AppServices();
    await tester.pumpWidget(
      HeritageWalkApp(services: s, initialRoute: AppRoutes.language),
    );
    await tester.pumpAndSettle();
    await press(
      tester,
      find.byWidgetPredicate(
        (w) => w is LanguageOptionCard && w.language.code == 'si',
      ),
    );
    expect(find.text('ඔබ කැමති භාෂාව තෝරන්න'), findsOneWidget);
    final context = tester.element(find.byType(LanguageSelectionScreen));
    Navigator.pushNamed(context, AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('මුල් පිටුව'), findsOneWidget);
    expect(find.text('ශ්‍රී ලංකාව ගවේෂණය කරන්න'), findsOneWidget);
  });
  for (final code in ['si', 'ta']) {
    for (final route in [
      AppRoutes.home,
      AppRoutes.explore,
      AppRoutes.map,
      AppRoutes.emergency,
      AppRoutes.helpSupport,
      AppRoutes.about,
    ]) {
      testWidgets('$code $route translates at compact width and large text', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 760);
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final s = AppServices(location: FakeGps(), routing: FakeRouting());
        s.language.setLanguage(code);
        await tester.pumpWidget(
          HeritageWalkApp(services: s, initialRoute: route),
        );
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(Locale(code));
        final key = switch (route) {
          AppRoutes.home => 'Explore Sri Lanka',
          AppRoutes.explore => 'Explore Sri Lanka',
          AppRoutes.map => 'Route Guidance',
          AppRoutes.emergency => 'Emergency Support',
          AppRoutes.helpSupport => 'How can we help you?',
          _ => 'Our Purpose',
        };
        expect(find.text(l.get(key)), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'review labels translate while stored names and comments remain untouched',
    (tester) async {
      final account = FakeAccount();
      await account.register('Alice', 'alice@test.com', 'Secure123');
      final placeId = DiscoveryService().places.first.id;
      final repo = InMemoryReviewRepository([
        PlaceReview(
          id: 'reviewer',
          placeId: placeId,
          userId: 'reviewer',
          userDisplayName: 'Language',
          rating: 4,
          comment: 'Home',
        ),
      ]);
      final s = AppServices(account: account, reviews: repo);
      await s.profile.ready;
      addTearDown(repo.dispose);
      s.language.setLanguage('ta');
      await tester.pumpWidget(
        HeritageWalkApp(services: s, initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();
      final place = s.discovery.discovery.places.first;
      final context = tester.element(find.text(place.name));
      Navigator.pushNamed(context, AppRoutes.placeDetails, arguments: place);
      await tester.pumpAndSettle();
      expect(find.text('கருத்துகளும் மதிப்பீடுகளும்'), findsOneWidget);
      expect(find.text(place.name), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    },
  );
}
