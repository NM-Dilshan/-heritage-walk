import 'package:heritage_walk/features/discovery_planning/screens/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/features/discovery_planning/widgets/place_card.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

Future<void> launch(WidgetTester tester, String route) async {
  await tester.pumpWidget(HeritageWalkApp(initialRoute: route));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> textTap(WidgetTester tester, String label) =>
    press(tester, find.text(label).last);
Future<void> makePlan(WidgetTester tester) async {
  await press(tester, find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await textTap(tester, 'Sigiriya');
  await tester.pumpAndSettle();
  await textTap(tester, 'Select Date');
  await tester.pumpAndSettle();
  await textTap(tester, 'OK');
  await tester.pumpAndSettle();
  await textTap(tester, '1 Day');
  await textTap(tester, 'History');
  await textTap(tester, 'Generate My Itinerary');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Explore renders the eight places and explicitly labels placeholders',
    (tester) async {
      await launch(tester, AppRoutes.explore);
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byType(PlaceCard), findsNWidgets(8));
      expect(find.text('Placeholder image'), findsNWidgets(8));
    },
  );

  testWidgets(
    'Search filters across location fields and displays empty state',
    (tester) async {
      await launch(tester, AppRoutes.explore);
      final search = find.widgetWithText(
        HeritageTextField,
        'Search heritage places...',
      );
      await tester.enterText(search, 'matale');
      await tester.pumpAndSettle();
      expect(find.byType(PlaceCard), findsNWidgets(2));
      expect(find.text('Galle Fort'), findsNothing);
      await tester.enterText(search, 'missing destination');
      await tester.pumpAndSettle();
      expect(find.text('No places found'), findsOneWidget);
    },
  );

  testWidgets('Category selection filters places and All restores them', (
    tester,
  ) async {
    await launch(tester, AppRoutes.explore);
    await press(tester, find.widgetWithText(ChoiceChip, 'Temples'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('Temple of the Sacred Tooth Relic'), findsOneWidget);
    await press(tester, find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(8));
  });

  testWidgets(
    'Favorite changes synchronize Home and Favorites, including Undo',
    (tester) async {
      await launch(tester, AppRoutes.home);
      await press(
        tester,
        find.byTooltip('Save Sigiriya Rock Fortress to favorites'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Remove Sigiriya Rock Fortress from favorites'),
        findsOneWidget,
      );
      await press(tester, find.byTooltip('My Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Sigiriya Rock Fortress'), findsOneWidget);
      await press(
        tester,
        find.byTooltip('Remove Sigiriya Rock Fortress from favorites'),
      );
      await tester.pumpAndSettle();
      expect(find.text('No favorites yet'), findsOneWidget);
      await textTap(tester, 'Undo');
      await tester.pumpAndSettle();
      expect(find.text('Sigiriya Rock Fortress'), findsOneWidget);
      await press(
        tester,
        find.byTooltip('Remove Sigiriya Rock Fortress from favorites'),
      );
      await tester.pumpAndSettle();
      await textTap(tester, 'Explore Places');
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Save Sigiriya Rock Fortress to favorites'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Featured place opens details and shares favorite state', (
    tester,
  ) async {
    await launch(tester, AppRoutes.home);
    await textTap(tester, 'Sigiriya Rock Fortress');
    await tester.pumpAndSettle();
    await press(tester, find.byTooltip('Add Favorite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Favorite'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Place Details'), findsOneWidget);
    expect(find.byTooltip('Remove Favorite'), findsOneWidget);
  });

  testWidgets(
    'Plan validation requires destination, date, duration and interests',
    (tester) async {
      await launch(tester, AppRoutes.planTour);
      await textTap(tester, 'Generate My Itinerary');
      await tester.pumpAndSettle();
      for (final message in [
        'Select a destination',
        'Select a date',
        'Select a duration',
        'Select at least one interest',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
    },
  );

  testWidgets('Generate, save, view, rename and delete an itinerary work', (
    tester,
  ) async {
    await launch(tester, AppRoutes.planTour);
    await makePlan(tester);
    expect(find.text('Your Itinerary'), findsOneWidget);
    expect(find.text('Sigiriya Rock Fortress'), findsOneWidget);
    await textTap(tester, 'Save Itinerary');
    await tester.pumpAndSettle();
    expect(find.text('Itinerary Saved'), findsOneWidget);
    expect(find.text('Itinerary saved successfully'), findsOneWidget);
    await textTap(tester, 'My Itineraries');
    await tester.pumpAndSettle();
    expect(find.text('Sigiriya Heritage Journey'), findsOneWidget);
    await textTap(tester, 'View');
    await tester.pumpAndSettle();
    expect(find.text('Itinerary Saved'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await textTap(tester, 'Rename');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '');
    await textTap(tester, 'Save');
    await tester.pumpAndSettle();
    expect(find.text('Enter an itinerary title'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'My Cultural Journey');
    await textTap(tester, 'Save');
    await tester.pumpAndSettle();
    expect(find.text('My Cultural Journey'), findsOneWidget);
    await textTap(tester, 'Delete');
    await tester.pumpAndSettle();
    expect(find.text('Delete this itinerary?'), findsOneWidget);
    await textTap(tester, 'Cancel');
    await tester.pumpAndSettle();
    expect(find.text('My Cultural Journey'), findsOneWidget);
    await textTap(tester, 'Delete');
    await tester.pumpAndSettle();
    await textTap(tester, 'Delete');
    await tester.pumpAndSettle();
    expect(find.text('No saved itineraries yet'), findsOneWidget);
    expect(find.text('Itinerary deleted'), findsOneWidget);
  });

  testWidgets(
    'Regenerate changes order, retains saved original, Edit Plan preserves selections',
    (tester) async {
      await launch(tester, AppRoutes.planTour);
      await makePlan(tester);
      final state = DiscoveryScope.of(
        tester.element(find.text('Your Itinerary')),
      );
      final firstId =
          (ModalRoute.of(tester.element(find.text('Your Itinerary')))!
                  .settings
                  .arguments
              as String);
      final first = state.itineraries.find(firstId)!;
      await textTap(tester, 'Save Itinerary');
      await tester.pumpAndSettle();
      await textTap(tester, 'Regenerate');
      await tester.pumpAndSettle();
      final secondId =
          ModalRoute.of(tester.element(find.text('Your Itinerary')))!
                  .settings
                  .arguments
              as String;
      expect(
        state.itineraries.find(secondId)!.places.first.id,
        isNot(first.places.first.id),
      );
      expect(state.itineraries.savedItineraries.length, 1);
      await textTap(tester, 'Edit Plan');
      await tester.pumpAndSettle();
      expect(find.text('Sigiriya'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1 Day'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'History'))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('Profile menus open Favorites and My Itineraries', (
    tester,
  ) async {
    await launch(tester, AppRoutes.profile);
    await textTap(tester, 'My Favorites');
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await textTap(tester, 'My Trips');
    await tester.pumpAndSettle();
    expect(find.text('No saved itineraries yet'), findsOneWidget);
  });

  testWidgets(
    'Main navigation reuses discovery, opens Map and avoids duplicate stacks',
    (tester) async {
      await launch(tester, AppRoutes.home);
      await textTap(tester, 'Map');
      await tester.pumpAndSettle();
      expect(find.text('Choose a destination'), findsOneWidget);
      await textTap(tester, 'Explore');
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      await textTap(tester, 'Itinerary');
      await tester.pumpAndSettle();
      expect(find.text('My Itineraries'), findsOneWidget);
      await textTap(tester, 'Profile');
      await tester.pumpAndSettle();
      expect(find.text('My Profile'), findsOneWidget);
      await textTap(tester, 'Home');
      await tester.pumpAndSettle();
      expect(
        Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('New screens fit small phones and larger text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final route in [
      AppRoutes.home,
      AppRoutes.favorites,
      AppRoutes.planTour,
      AppRoutes.itineraries,
    ]) {
      await tester.pumpWidget(const SizedBox());
      await launch(tester, route);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await launch(tester, AppRoutes.planTour);
    await makePlan(tester);
    expect(tester.takeException(), isNull);
    await textTap(tester, 'Save Itinerary');
    await tester.pumpAndSettle();
    await textTap(tester, 'My Itineraries');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
