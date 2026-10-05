import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/auth_profile/services/profile_service.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/services/group_tour_service.dart';
import 'package:heritage_walk/features/group_support/screens/group_tour_screen.dart';
import 'package:heritage_walk/features/group_support/screens/group_details_screen.dart';
import 'package:heritage_walk/features/group_support/screens/group_tracking_screen.dart';
import 'package:heritage_walk/features/group_support/widgets/group_map_placeholder.dart';
import 'package:heritage_walk/features/navigation_guide/screens/place_details_screen.dart';
import 'package:heritage_walk/features/navigation_guide/screens/navigation_screen.dart';

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
Future<void> launch(WidgetTester tester, String route) async {
  await tester.pumpWidget(HeritageWalkApp(initialRoute: route));
  await tester.pumpAndSettle();
}

Future<TourGroup> seed(WidgetTester tester, String route) async {
  await launch(tester, AppRoutes.groupTours);
  final context = tester.element(find.byType(GroupTourScreen));
  final group = GroupTourScope.of(context).createGroup(
    'Heritage Friends',
    DiscoveryScope.of(context).discovery.places.first,
  );
  Navigator.pushNamed(context, route, arguments: group.id);
  await tester.pumpAndSettle();
  return group;
}

void main() {
  testWidgets('Group Tours renders the empty state and create/join actions', (
    tester,
  ) async {
    await launch(tester, AppRoutes.groupTours);
    expect(find.text('Explore Sri Lanka together'), findsOneWidget);
    expect(find.text('No group tours yet'), findsOneWidget);
    expect(find.text('Create Your First Group'), findsOneWidget);
    expect(find.text('Join with Code'), findsOneWidget);
  });
  testWidgets('Home and Profile both open Group Tours', (tester) async {
    await launch(tester, AppRoutes.home);
    await tapText(tester, 'Group Tours');
    expect(find.byType(GroupTourScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await launch(tester, AppRoutes.profile);
    await tapText(tester, 'Group Tours');
    expect(find.byType(GroupTourScreen), findsOneWidget);
  });
  testWidgets(
    'Create validates and stores the current profile as leader with invite code',
    (tester) async {
      await launch(tester, AppRoutes.groupTours);
      await tapText(tester, '+ Create Group');
      await tapText(tester, 'Create Group');
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Select a destination'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Kandy Friends');
      await press(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, 'Temple of the Sacred Tooth Relic');
      await tapText(tester, 'Create Group');
      expect(find.byType(GroupDetailsScreen), findsOneWidget);
      final context = tester.element(find.byType(GroupDetailsScreen));
      final group = GroupTourScope.of(context).getGroups().single;
      expect(group.leaderName, ProfileScope.of(context).profile.fullName);
      expect(group.members.single.id, ProfileScope.of(context).profile.id);
      expect(group.members.single.isLeader, isTrue);
      expect(group.inviteCode, matches(r'^HW-\d{4}$'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Kandy Friends'), findsOneWidget);
    },
  );
  testWidgets(
    'Invite dialog validates, joins an existing local group and avoids duplicate membership',
    (tester) async {
      await launch(tester, AppRoutes.groupTours);
      final context = tester.element(find.byType(GroupTourScreen));
      final service = GroupTourScope.of(context);
      final group = service.createGroup(
        'Local Invite Demo',
        DiscoveryScope.of(context).discovery.places.first,
        leader: const UserProfile(
          id: 'other',
          fullName: 'Demo Leader',
          email: 'demo@example.com',
        ),
      );
      await tapText(tester, 'Join with Code');
      await tapText(tester, 'Join');
      expect(find.text('Enter an invite code'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'HW-9999');
      await tapText(tester, 'Join');
      expect(
        find.text('Group not found. Check the invite code.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField),
        group.inviteCode.toLowerCase(),
      );
      await tapText(tester, 'Join');
      expect(find.byType(GroupDetailsScreen), findsOneWidget);
      expect(service.getGroupById(group.id)!.members.length, 2);
      expect(find.text('Rename Group'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Join with Code');
      await tester.enterText(find.byType(TextFormField), group.inviteCode);
      await tapText(tester, 'Join');
      expect(service.getGroupById(group.id)!.members.length, 2);
    },
  );
  testWidgets(
    'Rename and destination changes update shared group state and tracking',
    (tester) async {
      final group = await seed(tester, AppRoutes.groupDetails);
      final service = GroupTourScope.of(
        tester.element(find.byType(GroupDetailsScreen)),
      );
      await tapText(tester, 'Rename Group');
      await tester.enterText(find.byType(TextFormField), '');
      await tapText(tester, 'Save');
      expect(find.text('Enter a name'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Galle Friends');
      await tapText(tester, 'Save');
      expect(find.text('Galle Friends'), findsOneWidget);
      await tapText(tester, 'Change Destination');
      await press(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, 'Galle Fort');
      await tapText(tester, 'Save');
      expect(service.getGroupById(group.id)!.destinationPlaceId, 'galle-fort');
      await tapText(tester, 'Open Group Tracking');
      expect(find.text('Galle Friends'), findsOneWidget);
      expect(find.text('Destination: Galle Fort'), findsOneWidget);
    },
  );
  testWidgets(
    'Demo members can be added and removed but leader has no remove action',
    (tester) async {
      final group = await seed(tester, AppRoutes.groupDetails);
      final service = GroupTourScope.of(
        tester.element(find.byType(GroupDetailsScreen)),
      );
      await tapText(tester, 'Add Demo Member');
      await tester.enterText(find.byType(TextFormField), 'Amal');
      await tapText(tester, 'Save');
      expect(find.text('Amal'), findsOneWidget);
      expect(service.getGroupById(group.id)!.members.length, 2);
      expect(find.byTooltip('Remove ${group.leaderName}'), findsNothing);
      await press(tester, find.byTooltip('Remove Amal'));
      await tapText(tester, 'Cancel');
      expect(find.text('Amal'), findsOneWidget);
      await press(tester, find.byTooltip('Remove Amal'));
      await tapText(tester, 'Remove');
      expect(find.text('Amal'), findsNothing);
      expect(service.getGroupById(group.id)!.members.length, 1);
    },
  );
  testWidgets('Copy invite uses the Flutter clipboard API', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final group = await seed(tester, AppRoutes.groupDetails);
    await tapText(tester, 'Copy');
    expect(copied, group.inviteCode);
    expect(find.text('Invite code copied'), findsOneWidget);
  });
  testWidgets(
    'Tracking sharing switches state and Refresh moves only sharing demo markers',
    (tester) async {
      final group = await seed(tester, AppRoutes.groupTracking);
      final service = GroupTourScope.of(
        tester.element(find.byType(GroupTrackingScreen)),
      );
      expect(find.text('Demo group tracking'), findsOneWidget);
      expect(
        tester
            .widget<GroupMapPlaceholder>(find.byType(GroupMapPlaceholder))
            .group
            .members
            .single
            .isSharingLocation,
        isFalse,
      );
      await press(tester, find.byType(SwitchListTile));
      expect(find.text('Demo location sharing enabled'), findsOneWidget);
      final before = service.getGroupById(group.id)!.members.single;
      await press(tester, find.byTooltip('Refresh'));
      final after = service.getGroupById(group.id)!.members.single;
      expect(after.relativeX, isNot(before.relativeX));
      expect(after.lastUpdated!.isBefore(before.lastUpdated!), isFalse);
      await press(tester, find.byType(SwitchListTile));
      expect(
        service.getGroupById(group.id)!.members.single.isSharingLocation,
        isFalse,
      );
      expect(find.text('Location sharing disabled'), findsOneWidget);
    },
  );
  testWidgets(
    'Tracking links to real Place Details and existing demo Navigation',
    (tester) async {
      await seed(tester, AppRoutes.groupTracking);
      await tapText(tester, 'View Destination');
      expect(find.byType(PlaceDetailsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Navigate');
      expect(find.byType(NavigationScreen), findsOneWidget);
      expect(find.text('Demo route preview'), findsOneWidget);
    },
  );
  testWidgets(
    'Delete confirmation removes the group and returns to the empty group list',
    (tester) async {
      await seed(tester, AppRoutes.groupDetails);
      await tapText(tester, 'Delete Group');
      await tapText(tester, 'Cancel');
      expect(find.text('Heritage Friends'), findsOneWidget);
      await tapText(tester, 'Delete Group');
      await tapText(tester, 'Delete');
      expect(find.byType(GroupTourScreen), findsOneWidget);
      expect(find.text('Heritage Friends'), findsNothing);
      expect(find.text('No group tours yet'), findsOneWidget);
      expect(find.text('Group deleted'), findsOneWidget);
    },
  );
  testWidgets('Invalid group routes show a safe unavailable state', (
    tester,
  ) async {
    await launch(tester, AppRoutes.groupTracking);
    expect(find.text('Group unavailable'), findsOneWidget);
    await tapText(tester, 'Go to Group Tours');
    expect(find.byType(GroupTourScreen), findsOneWidget);
  });
  testWidgets(
    'Group forms, management and tracking fit small screens with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final route in [AppRoutes.groupTours, AppRoutes.createGroup]) {
        await tester.pumpWidget(const SizedBox());
        await launch(tester, route);
        expect(tester.takeException(), isNull);
      }
      for (final route in [AppRoutes.groupDetails, AppRoutes.groupTracking]) {
        await tester.pumpWidget(const SizedBox());
        await seed(tester, route);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await seed(tester, AppRoutes.groupDetails);
      await tapText(tester, 'Rename Group');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Logout clears local groups and invite codes', (tester) async {
    final group = await seed(tester, AppRoutes.groupDetails);
    final context = tester.element(find.byType(GroupDetailsScreen));
    final service = GroupTourScope.of(context);
    Navigator.pushNamed(context, AppRoutes.profile);
    await tester.pumpAndSettle();
    await tapText(tester, 'Logout');
    await tapText(tester, 'Sign Out');
    expect(service.getGroups(), isEmpty);
    expect(service.joinGroupByCode(group.inviteCode), isNull);
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
