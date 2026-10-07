import 'support/part9_fakes.dart';
import 'support/part91_fakes.dart';

import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/features/navigation_guide/screens/place_details_screen.dart';
import 'package:heritage_walk/features/navigation_guide/screens/digital_guide_screen.dart';
import 'package:heritage_walk/features/navigation_guide/screens/navigation_screen.dart';
import 'package:heritage_walk/features/navigation_guide/services/navigation_guide_scope.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/facility_card.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/emergency_contact_card.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

Future<void> press(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    press(tester, find.text(text).last);
Future<HeritagePlace> launchPlace(
  WidgetTester tester,
  String route, {
  int placeIndex = 0,
  AppServices? services,
}) async {
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: AppRoutes.home),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(HomeScreen));
  final place = DiscoveryScope.of(context).discovery.places[placeIndex];
  Navigator.pushNamed(context, route, arguments: place);
  await tester.pumpAndSettle();
  return place;
}

void main() {
  testWidgets(
    'Details render selected place, honest image and unverified quick information',
    (tester) async {
      final place = await launchPlace(tester, AppRoutes.placeDetails);
      expect(find.text(place.name), findsOneWidget);
      expect(find.text('Placeholder image'), findsOneWidget);
      expect(find.text('Not verified'), findsNWidgets(2));
      expect(find.text('Opening Hours'), findsOneWidget);
      expect(find.text('Visitor Tips'), findsOneWidget);
    },
  );
  testWidgets('Details favorites use the same Home and Favorites service', (
    tester,
  ) async {
    final place = await launchPlace(tester, AppRoutes.placeDetails);
    final state = DiscoveryScope.of(
      tester.element(find.byType(PlaceDetailsScreen)),
    );
    await press(tester, find.byTooltip('Add Favorite'));
    expect(state.favorites.isFavorite(place.id), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Remove Sigiriya Rock Fortress from favorites'),
      findsOneWidget,
    );
    await press(tester, find.byTooltip('My Favorites'));
    expect(find.text(place.name), findsOneWidget);
  });
  testWidgets(
    'Home featured card opens details and existing navigation and guide',
    (tester) async {
      await tester.pumpWidget(
        const HeritageWalkApp(initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Sigiriya Rock Fortress');
      expect(find.byType(PlaceDetailsScreen), findsOneWidget);
      await tapText(tester, 'Start Navigation');
      expect(find.byType(NavigationScreen), findsOneWidget);
      expect(find.text('Route Guidance'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Digital Guide');
      expect(find.byType(DigitalGuideScreen), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    },
  );
  testWidgets(
    'Map landing selects a destination and mode loads routed estimates',
    (tester) async {
      await tester.pumpWidget(
        HeritageWalkApp(
          services: navigationHarness(),
          initialRoute: AppRoutes.map,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a destination'), findsOneWidget);
      expect(find.text('Route Guidance'), findsOneWidget);
      await press(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, 'Galle Fort');
      expect(find.text('Estimated time: 10 min'), findsOneWidget);
      await press(tester, find.widgetWithText(ChoiceChip, 'Walking'));
      expect(find.text('Estimated time: 58 min'), findsOneWidget);
      await tapText(tester, 'Start Route Guidance');
      expect(find.text('Route guidance active'), findsOneWidget);
      expect(
        find.text(
          'Route preview with live GPS. No voice or turn-by-turn instructions.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'End Navigation');
      expect(find.text('Route guidance active'), findsNothing);
      expect(find.text('Start Route Guidance'), findsOneWidget);
    },
  );
  testWidgets('Missing and wrong place arguments use safe choosers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HeritageWalkApp(initialRoute: AppRoutes.digitalGuide),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a destination'), findsOneWidget);
    await tapText(tester, 'Galle Fort');
    expect(find.byType(DigitalGuideScreen), findsOneWidget);
    final context = tester.element(find.byType(DigitalGuideScreen));
    Navigator.pushNamed(context, AppRoutes.placeDetails, arguments: 'invalid');
    await tester.pumpAndSettle();
    expect(find.text('Choose a destination'), findsOneWidget);
    await tapText(tester, 'Sigiriya Rock Fortress');
    expect(find.byType(PlaceDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Guide notes validate, create, read, edit and delete with confirmation',
    (tester) async {
      await launchPlace(tester, AppRoutes.digitalGuide);
      await tapText(tester, 'Add Note');
      await tapText(tester, 'Save');
      expect(find.text('Enter a note'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Visit the gardens');
      await tapText(tester, 'Save');
      expect(find.text('Visit the gardens'), findsOneWidget);
      await tapText(tester, 'Edit Note');
      expect(
        tester
            .widget<HeritageTextField>(find.byType(HeritageTextField))
            .controller!
            .text,
        'Visit the gardens',
      );
      await tester.enterText(find.byType(TextFormField), 'Read the site signs');
      await tapText(tester, 'Save');
      expect(find.text('Read the site signs'), findsOneWidget);
      expect(find.text('Visit the gardens'), findsNothing);
      await tapText(tester, 'Delete Note');
      await tapText(tester, 'Cancel');
      expect(find.text('Read the site signs'), findsOneWidget);
      await tapText(tester, 'Delete Note');
      await tapText(tester, 'Delete');
      expect(find.text('Read the site signs'), findsNothing);
      expect(
        find.text('No notes yet. Capture a thought from your journey.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Guide notes survive revisiting a place and are isolated from another place',
    (tester) async {
      await launchPlace(tester, AppRoutes.digitalGuide);
      await tapText(tester, 'Add Note');
      await tester.enterText(find.byType(TextFormField), 'Sigiriya note');
      await tapText(tester, 'Save');
      await tester.pageBack();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(HomeScreen));
      final places = DiscoveryScope.of(context).discovery.places;
      Navigator.pushNamed(
        context,
        AppRoutes.digitalGuide,
        arguments: places[1],
      );
      await tester.pumpAndSettle();
      expect(find.text('Sigiriya note'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      Navigator.pushNamed(
        tester.element(find.byType(HomeScreen)),
        AppRoutes.digitalGuide,
        arguments: places[0],
      );
      await tester.pumpAndSettle();
      expect(find.text('Sigiriya note'), findsOneWidget);
    },
  );
  testWidgets(
    'Demo audio play/pause advances local progress and disposes its timer',
    (tester) async {
      await launchPlace(tester, AppRoutes.digitalGuide);
      await tapText(tester, 'Play demo');
      expect(find.text('Pause demo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('audio-progress'))).data,
        isNot('00:00 / 01:00'),
      );
      await tapText(tester, 'Pause demo');
      final pausedProgress = tester
          .widget<Text>(find.byKey(const ValueKey('audio-progress')))
          .data;
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('audio-progress'))).data,
        pausedProgress,
      );
      await tapText(tester, 'Play demo');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Guide actions reach facilities, navigation and emergency support',
    (tester) async {
      await launchPlace(tester, AppRoutes.digitalGuide);
      await tapText(tester, 'Nearby Facilities');
      expect(find.text('Nearby Facilities'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Navigate to Place');
      expect(find.text('Route Guidance'), findsOneWidget);
      await press(tester, find.byTooltip('Emergency Support'));
      expect(find.text('Get help when you need it'), findsOneWidget);
    },
  );
  testWidgets(
    'Facilities filter/search and navigation use isolated real-format OSM results',
    (tester) async {
      final services = AppServices(
        location: FakeGps(),
        routing: FakeRouting(),
        facilities: FakeNearbyFacilityService(),
      );
      await launchPlace(tester, AppRoutes.facilities, services: services);
      expect(find.byType(FacilityCard), findsNWidgets(3));
      await press(tester, find.widgetWithText(ChoiceChip, 'Restaurant / Food'));
      expect(find.byType(FacilityCard), findsNWidgets(3));
      await tester.enterText(
        find.widgetWithText(HeritageTextField, 'Search facilities'),
        'cafe',
      );
      await tester.pumpAndSettle();
      expect(find.byType(FacilityCard), findsOneWidget);
      expect(find.text('Test Cafe'), findsWidgets);
      await tapText(tester, 'Navigate');
      expect(find.byType(NavigationScreen), findsOneWidget);
      expect(services.navigation.navigation.destination!.id, 'osm/node/8');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(HeritageTextField, 'Search facilities'),
        'missing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No facilities found'), findsOneWidget);
    },
  );
  testWidgets(
    'Emergency has placeholder contacts and deferred call/share actions',
    (tester) async {
      await tester.pumpWidget(
        const HeritageWalkApp(initialRoute: AppRoutes.emergency),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmergencyContactCard), findsNWidgets(4));
      expect(
        find.text('Number will be provided through verified service data'),
        findsNWidgets(4),
      );
      await press(tester, find.text('Call (not connected)').first);
      expect(
        find.text(
          'Calling functionality will be connected during device integration.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapText(tester, 'Share My Location');
      expect(
        find.text(
          'To share location, open a group and start sharing in Group Tracking.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Part 4 layouts and notes dialog fit small phones with larger text and keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final route in [
        AppRoutes.placeDetails,
        AppRoutes.navigation,
        AppRoutes.digitalGuide,
        AppRoutes.facilities,
        AppRoutes.emergency,
      ]) {
        await tester.pumpWidget(const SizedBox());
        await launchPlace(tester, route);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await launchPlace(tester, AppRoutes.digitalGuide);
      await tapText(tester, 'Add Note');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Small-screen note');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Logout clears notes and demo navigation without changing other module behavior',
    (tester) async {
      final place = await launchPlace(tester, AppRoutes.digitalGuide);
      final state = NavigationGuideScope.of(
        tester.element(find.byType(DigitalGuideScreen)),
      );
      state.notes.add(place.id, 'Session note');
      state.navigation.selectDestination(place);
      state.navigation.start();
      final context = tester.element(find.byType(DigitalGuideScreen));
      Navigator.pushNamed(context, AppRoutes.profile);
      await tester.pumpAndSettle();
      await tapText(tester, 'Logout');
      await tapText(tester, 'Sign Out');
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(state.notes.forPlace(place.id), isEmpty);
      expect(state.navigation.destination, isNull);
      expect(state.navigation.isActive, isFalse);
    },
  );
}

AppServices navigationHarness() {
  final gps = FakeGps();
  final services = AppServices(location: gps, routing: FakeRouting());
  services.discovery.discovery.replaceCatalog(
    services.discovery.discovery.places.map(coordinatePlace).toList(),
  );
  return services;
}
