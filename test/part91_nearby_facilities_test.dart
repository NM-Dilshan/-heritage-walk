import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/core/localization/app_localizations.dart';
import 'package:heritage_walk/features/navigation_guide/models/facility.dart';
import 'package:heritage_walk/features/navigation_guide/services/facility_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/location_service.dart';
import 'package:heritage_walk/features/navigation_guide/services/nearby_facility_controller.dart';
import 'package:heritage_walk/features/navigation_guide/screens/navigation_screen.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/facility_card.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/heritage_map.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

import 'support/part9_fakes.dart';
import 'support/part91_fakes.dart';

String body(List<Map<String, Object?>> elements) =>
    jsonEncode({'elements': elements});
NearbyFacility parsed({String? name = 'Test Hospital'}) =>
    NearbyFacility.fromOsm(
      osmFacility('hospital', name: name),
      facilityOrigin,
      FacilityCategory.hospital,
    )!;
Future<void> pressFacility(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<AppServices> launchFacilities(
  WidgetTester tester, {
  FakeGps? gps,
  FakeNearbyFacilityService? nearby,
  String locale = 'en',
}) async {
  final services = AppServices(
    location: gps ?? FakeGps(),
    routing: FakeRouting(),
    facilities: nearby ?? FakeNearbyFacilityService(),
  );
  services.language.setLanguage(locale);
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: AppRoutes.facilities),
  );
  await tester.pumpAndSettle();
  return services;
}

void main() {
  group('OSM model parsing', () {
    for (final category in FacilityCategory.values) {
      for (final amenity in category.amenities) {
        test('${category.name} parses amenity=$amenity', () {
          final f = NearbyFacility.fromOsm(
            osmFacility(amenity),
            facilityOrigin,
            category,
          )!;
          expect(f.category, category);
          expect(f.latitude, 6.033);
          expect(f.longitude, 80.218);
          expect(f.osmId, 'node/1');
        });
      }
    }
    test('real metadata is preserved without inventing unavailable fields', () {
      final f = NearbyFacility.fromOsm(
        osmFacility(
          'hospital',
          tags: {
            'addr:housenumber': '12',
            'addr:street': 'Test Street',
            'addr:city': 'Test City',
            'contact:phone': '+94123456789',
            'contact:website': 'https://example.org',
            'opening_hours': 'Mo-Fr 09:00-17:00',
          },
        ),
        facilityOrigin,
        FacilityCategory.hospital,
      )!;
      expect(f.address, '12 Test Street, Test City');
      expect(f.phone, '+94123456789');
      expect(f.website, 'https://example.org');
      expect(f.openingHours, 'Mo-Fr 09:00-17:00');
    });
    test('unnamed and missing metadata stay absent in the model', () {
      final f = parsed(name: null);
      expect(f.name, isNull);
      expect(f.address, isNull);
      expect(f.phone, isNull);
      expect(f.website, isNull);
      expect(f.openingHours, isNull);
      expect(f.destination.hasName, isFalse);
      expect(f.destination.name, 'Unnamed facility');
    });
    for (final type in ['way', 'relation']) {
      test('$type uses the actual Overpass center', () {
        final f = NearbyFacility.fromOsm(
          osmFacility('pharmacy', type: type, id: 20),
          facilityOrigin,
          FacilityCategory.pharmacy,
        )!;
        expect(f.osmId, '$type/20');
        expect(f.position, const LatLng(6.033, 80.218));
      });
    }
    for (final invalid in <Map<String, Object?>>[
      {
        'type': 'node',
        'id': 1,
        'tags': {'amenity': 'hospital'},
      },
      {
        'type': 'node',
        'id': 1,
        'lat': 91,
        'lon': 80,
        'tags': {'amenity': 'hospital'},
      },
      {
        'type': 'node',
        'id': 1,
        'lat': 6,
        'lon': 181,
        'tags': {'amenity': 'hospital'},
      },
      {
        'type': 'way',
        'id': 1,
        'tags': {'amenity': 'hospital'},
      },
      {
        'type': 'node',
        'id': -1,
        'lat': 6,
        'lon': 80,
        'tags': {'amenity': 'hospital'},
      },
      {
        'type': 'node',
        'id': 1,
        'lat': '6',
        'lon': 80,
        'tags': {'amenity': 'hospital'},
      },
    ]) {
      test('invalid OSM element ${jsonEncode(invalid)} is skipped', () {
        expect(
          NearbyFacility.fromOsm(
            invalid,
            facilityOrigin,
            FacilityCategory.hospital,
          ),
          isNull,
        );
      });
    }
    test('direct geographic distance is measured in metres', () {
      final f = NearbyFacility.fromOsm(
        osmFacility('hospital', lat: 6.042),
        facilityOrigin,
        FacilityCategory.hospital,
      )!;
      expect(f.distanceMeters, closeTo(1106, 10));
    });
    test(
      'category filtering, nearest order, radius and deduplication are applied',
      () {
        final elements = [
          osmFacility('hospital', id: 1, lat: 6.04),
          osmFacility('hospital', id: 2, lat: 6.033),
          osmFacility('pharmacy', id: 3),
          osmFacility('hospital', id: 4, lat: 6.2),
          osmFacility('hospital', id: 2, lat: 6.033),
        ];
        final found = OverpassNearbyFacilityService.decode(
          body(elements),
          facilityOrigin,
          FacilityCategory.hospital,
          1000,
        );
        expect(found.map((f) => f.osmId), ['node/2', 'node/1']);
      },
    );
  });
  group('Overpass HTTP', () {
    test('POST query uses real GPS, bounded radius, all OSM types and an identifying header', () async {
      late http.Request request;
      final service = OverpassNearbyFacilityService(
        client: MockClient((r) async {
          request = r;
          return http.Response(body([osmFacility('clinic')]), 200);
        }),
      );
      addTearDown(service.dispose);
      final found = await service.search(
        origin: facilityOrigin,
        category: FacilityCategory.hospital,
        radiusMeters: 2000,
      );
      expect(found, hasLength(1));
      expect(request.method, 'POST');
      expect(request.url.host, 'overpass-api.de');
      final query = Uri.splitQueryString(request.body)['data']!;
      expect(query, contains('around:2000,6.032,80.218'));
      expect(query, contains('nwr('));
      expect(query, contains('hospital|clinic|doctors'));
      expect(query, contains('out body center'));
      expect(request.headers['User-Agent'], contains('HeritageWalk'));
      expect(query, contains('[timeout:20]'));
    });
    test('empty results are a successful empty list', () async {
      final service = OverpassNearbyFacilityService(
        client: MockClient((_) async => http.Response(body([]), 200)),
      );
      addTearDown(service.dispose);
      expect(
        await service.search(
          origin: facilityOrigin,
          category: FacilityCategory.pharmacy,
        ),
        isEmpty,
      );
    });
    for (final sample in <(int, String, FacilityFailure)>[
      (500, 'server error', FacilityFailure.server),
      (429, 'busy', FacilityFailure.rateLimited),
      (504, 'gateway timeout', FacilityFailure.timeout),
      (200, 'not json', FacilityFailure.malformed),
      (200, '{"elements":{}}', FacilityFailure.malformed),
      (
        200,
        '{"elements":[],"remark":"runtime error: timeout"}',
        FacilityFailure.malformed,
      ),
    ]) {
      test('HTTP ${sample.$1} / ${sample.$2} exposes ${sample.$3}', () async {
        final service = OverpassNearbyFacilityService(
          client: MockClient((_) async => http.Response(sample.$2, sample.$1)),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.search(
            origin: facilityOrigin,
            category: FacilityCategory.hospital,
          ),
          throwsA(
            isA<FacilityException>().having(
              (e) => e.reason,
              'reason',
              sample.$3,
            ),
          ),
        );
      });
    }
    for (final sample in [
      (TimeoutException('test'), FacilityFailure.timeout),
      (const SocketException('test'), FacilityFailure.offline),
    ]) {
      test('transport ${sample.$2} is handled', () async {
        final service = OverpassNearbyFacilityService(
          client: MockClient((_) async => throw sample.$1),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.search(
            origin: facilityOrigin,
            category: FacilityCategory.hospital,
          ),
          throwsA(
            isA<FacilityException>().having(
              (e) => e.reason,
              'reason',
              sample.$2,
            ),
          ),
        );
      });
    }
    test(
      'cache and concurrent deduplication reuse one bounded request',
      () async {
        var calls = 0;
        final gate = Completer<http.Response>();
        final service = OverpassNearbyFacilityService(
          client: MockClient((_) {
            calls++;
            return gate.future;
          }),
        );
        addTearDown(service.dispose);
        final first = service.search(
          origin: facilityOrigin,
          category: FacilityCategory.hospital,
        );
        final second = service.search(
          origin: facilityOrigin,
          category: FacilityCategory.hospital,
        );
        await flushGps();
        gate.complete(http.Response(body([osmFacility('hospital')]), 200));
        await first;
        await second;
        await service.search(
          origin: facilityOrigin,
          category: FacilityCategory.hospital,
        );
        expect(calls, 1);
      },
    );
    test('explicit refresh bypasses the cache', () async {
      var calls = 0;
      final service = OverpassNearbyFacilityService(
        client: MockClient((_) async {
          calls++;
          return http.Response(body([]), 200);
        }),
      );
      addTearDown(service.dispose);
      await service.search(
        origin: facilityOrigin,
        category: FacilityCategory.hospital,
      );
      await service.search(
        origin: facilityOrigin,
        category: FacilityCategory.hospital,
        refresh: true,
      );
      expect(calls, 2);
    });
    test('429 cooldown prevents immediate repeated public requests', () async {
      var calls = 0;
      final service = OverpassNearbyFacilityService(
        client: MockClient((_) async {
          calls++;
          return http.Response('busy', 429);
        }),
      );
      addTearDown(service.dispose);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.search(
            origin: facilityOrigin,
            category: FacilityCategory.hospital,
          ),
          throwsA(isA<FacilityException>()),
        );
      }
      expect(calls, 1);
    });
    test('unbounded radius is rejected before HTTP', () async {
      var calls = 0;
      final service = OverpassNearbyFacilityService(
        client: MockClient((_) async {
          calls++;
          return http.Response(body([]), 200);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.search(
          origin: facilityOrigin,
          category: FacilityCategory.hospital,
          radiusMeters: 100000,
        ),
        throwsA(
          isA<FacilityException>().having(
            (e) => e.reason,
            'reason',
            FacilityFailure.invalidQuery,
          ),
        ),
      );
      expect(calls, 0);
    });
  });
  group('one-shot GPS discovery controller', () {
    late FakeGps gps;
    late FakeNearbyFacilityService nearby;
    late NearbyFacilityController controller;
    setUp(() {
      gps = FakeGps();
      nearby = FakeNearbyFacilityService();
      controller = NearbyFacilityController(gps, nearby);
    });
    tearDown(() async {
      controller.dispose();
      await gps.dispose();
    });
    for (final state in [
      LocationState.denied,
      LocationState.deniedForever,
      LocationState.servicesOff,
      LocationState.unavailable,
      LocationState.timeout,
    ]) {
      test('$state never uses fake GPS or queries Overpass', () async {
        gps.failure = state;
        await controller.locate();
        expect(controller.position, isNull);
        expect(nearby.requests, isEmpty);
        expect(controller.locationState, state);
      });
    }
    test('GPS success defaults to a 5km hospital search without continuous tracking', () async {
      await controller.locate();
      expect(nearby.requests.single.origin, gps.fix);
      expect(nearby.requests.single.radius, 5000);
      expect(controller.results, hasLength(3));
      expect(gps.watches, 0);
    });
    test('category and radius changes use the acquired GPS fix', () async {
      await controller.locate();
      await controller.selectCategory(FacilityCategory.pharmacy);
      await controller.selectRadius(1000);
      expect(nearby.requests.last.category, FacilityCategory.pharmacy);
      expect(nearby.requests.last.radius, 1000);
      expect(gps.currentCalls, 1);
    });
    test(
      'text filtering and selecting never issue another public request',
      () async {
        await controller.locate();
        expect(controller.filtered('CLINIC').single.name, 'Test Clinic');
        controller.select(controller.results.first);
        expect(controller.selected, isNotNull);
        expect(nearby.requests, hasLength(1));
      },
    );
    test('refresh acquires a fresh fix and bypasses discovery cache', () async {
      await controller.locate();
      gps.fix = const LatLng(6.033, 80.218);
      await controller.locate(refresh: true);
      expect(nearby.requests.last.origin, gps.fix);
      expect(nearby.requests.last.refresh, isTrue);
      expect(gps.currentCalls, 2);
    });
    test(
      'late results cannot overwrite a different selected category',
      () async {
        await controller.locate();
        nearby.pending = Completer();
        final old = controller.search();
        await flushGps();
        final gate = nearby.pending!;
        nearby.pending = null;
        await controller.selectCategory(FacilityCategory.pharmacy);
        gate.complete([parsed()]);
        await old;
        expect(controller.results.single.category, FacilityCategory.pharmacy);
      },
    );
    test('backgrounding invalidates a pending GPS fix', () async {
      gps.pending = Completer();
      final waiting = controller.locate();
      await flushGps();
      controller.suspend();
      gps.pending!.complete(gps.fix);
      await waiting;
      expect(controller.position, isNull);
      expect(nearby.requests, isEmpty);
    });
    test(
      'a suspended pending query is not reported as a successful empty search',
      () async {
        await controller.locate();
        nearby.pending = Completer();
        final pending = controller.search();
        await flushGps();
        controller.suspend();
        nearby.pending!.complete([]);
        await pending;
        expect(controller.hasSearched, isFalse);
        expect(controller.loading, isFalse);
      },
    );
    test(
      'empty and failed results never preserve misleading old markers',
      () async {
        await controller.locate();
        nearby.failure = FacilityFailure.offline;
        await controller.search();
        expect(controller.results, isEmpty);
        expect(controller.error, FacilityFailure.offline);
        nearby.failure = null;
        nearby.elements = [];
        await controller.search();
        expect(controller.results, isEmpty);
        expect(controller.error, isNull);
      },
    );
  });
  testWidgets(
    'Home exposes nearby GPS discovery without choosing a heritage place',
    (tester) async {
      final services = AppServices(
        location: FakeGps(),
        routing: FakeRouting(),
        facilities: FakeNearbyFacilityService(),
      );
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();
      await pressFacility(tester, find.text('Nearby Facilities'));
      expect(find.byType(FacilityCard), findsNWidgets(3));
      expect(find.text('Test Hospital'), findsWidgets);
    },
  );
  testWidgets('map panning and rebuilds do not repeat nearby HTTP discovery', (
    tester,
  ) async {
    final nearby = FakeNearbyFacilityService();
    await launchFacilities(tester, nearby: nearby);
    await tester.ensureVisible(find.byType(HeritageMap));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(HeritageMap), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(nearby.requests, hasLength(1));
  });
  testWidgets(
    'screen exposes current and real facility markers with selection',
    (tester) async {
      await launchFacilities(tester);
      final map = tester.widget<HeritageMap>(find.byType(HeritageMap));
      expect(map.markers.first.id, 'current');
      expect(map.markers, hasLength(4));
      await tester.ensureVisible(find.byType(HeritageMap));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marker-node/3')));
      await tester.pumpAndSettle();
      expect(find.text('Selected facility'), findsOneWidget);
      expect(
        tester.widget<HeritageMap>(find.byType(HeritageMap)).focus,
        isNotNull,
      );
    },
  );
  testWidgets('View on Map focuses the selected facility', (tester) async {
    await launchFacilities(tester);
    await pressFacility(tester, find.text('View on Map').first);
    expect(
      tester.widget<HeritageMap>(find.byType(HeritageMap)).focus,
      const LatLng(6.033, 80.218),
    );
  });
  testWidgets(
    'facility navigates through existing OSRM abstraction without catalog records',
    (tester) async {
      final services = await launchFacilities(tester);
      final before = services.discovery.discovery.places.length;
      await pressFacility(tester, find.text('Navigate').first);
      expect(find.byType(NavigationScreen), findsOneWidget);
      final nav = services.navigation.navigation;
      expect(nav.destination, isA<FacilityDestination>());
      expect(nav.destination!.id, 'osm/node/1');
      expect(nav.destinationPosition, const LatLng(6.033, 80.218));
      expect(nav.path, isNotNull);
      expect(find.text('Distance: 3.8 km'), findsOneWidget);
      expect(find.text('Estimated time: 10 min'), findsOneWidget);
      expect(services.discovery.discovery.places.length, before);
      expect(
        (nav.routing as FakeRouting).destination,
        const LatLng(6.033, 80.218),
      );
    },
  );
  testWidgets(
    'permission errors show action and never fabricate result markers',
    (tester) async {
      await launchFacilities(
        tester,
        gps: FakeGps(failure: LocationState.deniedForever),
      );
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.byType(FacilityCard), findsNothing);
      expect(
        tester.widget<HeritageMap>(find.byType(HeritageMap)).markers,
        isEmpty,
      );
    },
  );
  testWidgets('nearby server failure is visible and retry recovers', (
    tester,
  ) async {
    final nearby = FakeNearbyFacilityService()
      ..failure = FacilityFailure.server;
    await launchFacilities(tester, nearby: nearby);
    expect(
      find.text('Nearby search server unavailable. Try again later.'),
      findsOneWidget,
    );
    nearby.failure = null;
    await pressFacility(tester, find.text('Try again'));
    expect(find.byType(FacilityCard), findsNWidgets(3));
  });
  testWidgets('empty discovery has a useful honest empty state', (
    tester,
  ) async {
    await launchFacilities(
      tester,
      nearby: FakeNearbyFacilityService()..elements = [],
    );
    expect(find.text('No facilities found'), findsOneWidget);
    expect(find.byType(FacilityCard), findsNothing);
  });
  testWidgets(
    'category controls and radius selector change queries; filtering does not',
    (tester) async {
      final nearby = FakeNearbyFacilityService();
      await launchFacilities(tester, nearby: nearby);
      await pressFacility(
        tester,
        find.byKey(const ValueKey('facility-category-pharmacy')),
      );
      expect(find.byType(FacilityCard), findsOneWidget);
      expect(nearby.requests.last.category, FacilityCategory.pharmacy);
      await pressFacility(tester, find.byType(DropdownButtonFormField<int>));
      await pressFacility(tester, find.text('1 km').last);
      expect(nearby.requests.last.radius, 1000);
      final calls = nearby.requests.length;
      await tester.enterText(find.byType(HeritageTextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No facilities found'), findsOneWidget);
      expect(nearby.requests.length, calls);
    },
  );
  for (final code in ['en', 'si', 'ta']) {
    testWidgets(
      '$code facilities translate at compact width and large text, preserving OSM names',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 760);
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final nearby = FakeNearbyFacilityService()
          ..elements = [osmFacility('hospital', name: 'Home')];
        await launchFacilities(tester, nearby: nearby, locale: code);
        final l = await AppLocalizations.delegate.load(Locale(code));
        expect(find.text(l.get('Nearby Facilities')), findsOneWidget);
        expect(find.text(l.get('Search radius')), findsWidgets);
        await tester.ensureVisible(find.byType(FacilityCard));
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsWidgets);
        expect(find.text(l.get('Address unavailable')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('all new locale resources retain placeholder parity', () {
    final en =
        jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map;
    for (final code in ['si', 'ta']) {
      final translated =
          jsonDecode(File('assets/l10n/$code.json').readAsStringSync()) as Map;
      expect(translated.keys.toSet(), en.keys.toSet());
      for (final key in [
        'OSM opening hours: {0}',
        'Approx. {0} km away (direct)',
        '{0} facilities found',
      ]) {
        expect(translated[key], contains('{0}'));
        expect(translated[key], isNot(en[key]));
      }
    }
  });
}
