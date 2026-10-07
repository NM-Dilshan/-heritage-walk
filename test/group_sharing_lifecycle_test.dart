import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/screens/group_tracking_screen.dart';
import 'package:heritage_walk/features/group_support/services/group_location_service.dart';
import 'package:heritage_walk/features/group_support/services/group_tour_service.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/main.dart';
import 'package:latlong2/latlong.dart';

import 'group_tracking_regression_test.dart' as fixtures;
import 'support/part7_fakes.dart';
import 'support/part9_fakes.dart';

class Harness {
  Harness(
    this.tester,
    this.services,
    this.account,
    this.gps,
    this.repo,
    this.ownsRepo,
  );
  final WidgetTester tester;
  final AppServices services;
  final FakeAccount account;
  final FakeGps gps;
  final MemoryGroupLocationRepository repo;
  final bool ownsRepo;
  bool rootOwnsServices = false;
  static Future<Harness> create(
    WidgetTester tester, {
    String uid = 'alice-uid',
    MemoryGroupLocationRepository? repo,
    FakeGps? gps,
    Duration Function()? additionalElapsed,
  }) async {
    final account = FakeAccount();
    account.current = uid;
    account.profiles[uid] = UserProfile(
      id: uid,
      fullName: uid,
      email: '$uid@test.com',
    );
    final ownsRepo = repo == null;
    repo ??= MemoryGroupLocationRepository();
    gps ??= FakeGps();
    final origin = tester.binding.clock.now();
    final services = AppServices(
      account: account,
      location: gps,
      routing: FakeRouting(),
      groupLocations: repo,
      groupSharingNow: () => tester.binding.clock.now().toUtc(),
      groupSharingElapsed: () =>
          tester.binding.clock.now().difference(origin) +
          (additionalElapsed?.call() ?? Duration.zero),
    );
    await services.profile.ready;
    services.groups.restore([fixtures.trackingGroup()]);
    return Harness(tester, services, account, gps, repo, ownsRepo);
  }

  GroupLocationSharingController get sharing => services.groups.sharing;
  Future<void> tracking() => fixtures.pumpTracking(tester, services);
  Future<void> close() async {
    if (!rootOwnsServices) services.dispose();
    await tester.pumpWidget(const SizedBox());
    await flushGps();
    await tester.pump();
    if (ownsRepo) repo.dispose();
    unawaited(gps.dispose());
    unawaited(account.events.close());
    await tester.pump();
  }
}

class OwnershipCheckingLocations extends MemoryGroupLocationRepository {
  String? Function()? authenticatedUid;
  final removedWhileAuthenticated = <String>[];
  @override
  Future<void> remove(String groupId, String uid) async {
    if (authenticatedUid?.call() != uid) {
      throw StateError('Own authenticated UID required');
    }
    removedWhileAuthenticated.add(uid);
    await super.remove(groupId, uid);
  }
}

Future<void> press(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> perform(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var completed = false;
  Object? failure;
  unawaited(
    action().then(
      (_) => completed = true,
      onError: (Object error) {
        failure = error;
      },
    ),
  );
  for (var i = 0; i < 3 && !completed && failure == null; i++) {
    await tester.pumpAndSettle();
    // StreamSubscription.cancel may return a root-zone future. Let that
    // microtask complete without moving the simulated five-minute clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
  expect(failure, isNull);
  expect(
    completed,
    isTrue,
    reason: 'Service operation must complete after flushing microtasks',
  );
}

void main() {
  testWidgets('screen disposal leaves active foreground sharing alive', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    try {
      await h.tracking();
      await press(tester, 'Start Sharing Location');
      expect(h.gps.watches, 1);
      expect(h.sharing.isSharing, isTrue);
      expect(h.sharing.activeGroupId, 'shared-group');
      expect(
        h.sharing.sharingExpiresAt!.difference(h.sharing.sharingStartedAt!),
        const Duration(minutes: 5),
      );
      await tester.pumpWidget(const MaterialApp(home: Text('Home')));
      await tester.pumpAndSettle();
      expect(h.gps.cancellations, 0);
      expect(h.repo.values['shared-group']!.keys, ['alice-uid']);
      await tester.pump(const Duration(seconds: 11));
      h.gps.updates.add(const LatLng(6.05, 80.22));
      await tester.pump();
      await flushGps();
      expect(
        h.repo.values['shared-group']!['alice-uid']!.position,
        const LatLng(6.05, 80.22),
      );
      await h.tracking();
      expect(find.text('Sharing ON'), findsOneWidget);
      expect(find.text('Stop Sharing Location'), findsOneWidget);
      expect(h.gps.watches, 1);
    } finally {
      await h.close();
    }
  });

  testWidgets(
    'Home and Explore navigation keep A live on B without creating another stream',
    (tester) async {
      final repo = MemoryGroupLocationRepository();
      final a = await Harness.create(tester, repo: repo);
      final b = await Harness.create(tester, uid: 'bob-uid', repo: repo);
      try {
        final peer = b.sharing.acquire('shared-group');
        await perform(tester, () => b.sharing.start('shared-group'));
        a.rootOwnsServices = true;
        await tester.pumpWidget(
          HeritageWalkApp(services: a.services, initialRoute: AppRoutes.home),
        );
        await tester.pumpAndSettle();
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.pushNamed(
            AppRoutes.groupTracking,
            arguments: 'shared-group',
          ),
        );
        await tester.pumpAndSettle();
        await press(tester, 'Start Sharing Location');
        final expires = a.sharing.sharingExpiresAt;
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(GroupTrackingScreen), findsNothing);
        expect(a.sharing.isSharing, isTrue);
        unawaited(navigator.pushNamed(AppRoutes.explore));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 11));
        a.gps.updates.add(const LatLng(6.06, 80.23));
        await tester.pump();
        await flushGps();
        expect(
          peer.freshLocations
              .singleWhere((l) => l.userId == 'alice-uid')
              .position,
          const LatLng(6.06, 80.23),
        );
        unawaited(
          navigator.pushNamed(
            AppRoutes.groupTracking,
            arguments: 'shared-group',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sharing ON'), findsOneWidget);
        expect(a.gps.watches, 1);
        expect(a.sharing.sharingExpiresAt, expires);
        await perform(tester, () => a.sharing.start('shared-group'));
        expect(a.sharing.sharingExpiresAt, expires);
        expect(a.gps.watches, 1);
        b.sharing.release('shared-group');
      } finally {
        await a.close();
        await b.close();
        repo.dispose();
      }
    },
  );

  testWidgets(
    'manual Stop is immediately OFF, deletes only A and cancels the old expiry',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        await h.tracking();
        await press(tester, 'Start Sharing Location');
        await h.repo.write(
          'shared-group',
          SharedLocation(
            'bob-uid',
            'Bob',
            const LatLng(8, 81),
            tester.binding.clock.now(),
          ),
        );
        await perform(tester, () {
          final stop = h.sharing.stop();
          expect(h.sharing.isSharing, isFalse);
          return stop;
        });
        expect(find.text('Sharing OFF'), findsOneWidget);
        expect(h.repo.values['shared-group']!.keys, ['bob-uid']);
        expect(h.gps.cancellations, 1);
        await tester.pumpWidget(const MaterialApp(home: Text('Home')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 4));
        await h.tracking();
        await press(tester, 'Start Sharing Location');
        await tester.pumpWidget(const MaterialApp(home: Text('Home')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 1, seconds: 1));
        expect(h.sharing.isSharing, isTrue);
        expect(h.gps.watches, 2);
      } finally {
        await h.close();
      }
    },
  );

  testWidgets(
    'five-minute expiry removes only A, never restarts, and returning shows OFF',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        await h.tracking();
        await press(tester, 'Start Sharing Location');
        await h.repo.write(
          'shared-group',
          SharedLocation(
            'bob-uid',
            'Bob',
            const LatLng(8, 81),
            tester.binding.clock.now(),
          ),
        );
        await tester.pumpWidget(const MaterialApp(home: Text('Home')));
        await tester.pump(const Duration(minutes: 4, seconds: 59));
        expect(h.sharing.isSharing, isTrue);
        await tester.pump(const Duration(seconds: 1));
        await flushGps();
        expect(h.sharing.isSharing, isFalse);
        expect(h.sharing.activeGroupId, isNull);
        expect(h.repo.values['shared-group']!.keys, ['bob-uid']);
        expect(h.gps.cancellations, 1);
        final calls = h.gps.currentCalls;
        await tester.pump(const Duration(minutes: 6));
        expect(h.gps.currentCalls, calls);
        await h.tracking();
        expect(find.text('Sharing OFF'), findsOneWidget);
        expect(h.gps.watches, 1);
        await press(tester, 'Start Sharing Location');
        expect(h.sharing.isSharing, isTrue);
        expect(h.gps.watches, 2);
      } finally {
        await h.close();
      }
    },
  );

  testWidgets(
    'opening another group preserves X until explicit Start safely switches to Y',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        final other = TourGroup.fromMap({
          ...fixtures.trackingGroup().toMap(),
          'id': 'other-group',
          'inviteCode': 'OTHER1',
        });
        h.services.groups.restore([fixtures.trackingGroup(), other]);
        await h.tracking();
        await press(tester, 'Start Sharing Location');
        final y = h.sharing.acquire('other-group');
        expect(y.sharing, isFalse);
        expect(h.sharing.activeGroupId, 'shared-group');
        expect(h.gps.watches, 1);
        await perform(tester, () => h.sharing.start('other-group'));
        await flushGps();
        expect(h.sharing.activeGroupId, 'other-group');
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.repo.values['other-group']!.keys, ['alice-uid']);
        expect(h.gps.cancellations, 1);
        await tester.pump(const Duration(seconds: 11));
        h.gps.updates.add(const LatLng(7.1, 81.1));
        await tester.pump();
        await flushGps();
        expect(h.repo.values['shared-group'], isEmpty);
        expect(
          h.repo.values['other-group']!['alice-uid']!.position,
          const LatLng(7.1, 81.1),
        );
        h.sharing.release('other-group');
      } finally {
        await h.close();
      }
    },
  );

  for (final deletion in [false, true]) {
    testWidgets(
      '${deletion ? 'Group deletion' : 'Group departure'} stops the off-screen owner and deletes own document',
      (tester) async {
        final h = await Harness.create(tester);
        try {
          await perform(tester, () => h.sharing.start('shared-group'));
          if (deletion) {
            h.services.groups.deleteGroup('shared-group');
          } else {
            h.services.groups.restore([
              fixtures.trackingGroup().copyWith(
                members: fixtures
                    .trackingGroup()
                    .members
                    .where((m) => m.id != 'alice-uid')
                    .toList(),
              ),
            ]);
          }
          await flushGps();
          expect(h.sharing.isSharing, isFalse);
          expect(h.repo.values['shared-group'], isEmpty);
          expect(h.gps.cancellations, 1);
        } finally {
          await h.close();
        }
      },
    );
  }

  testWidgets(
    'logout deletes the snapshot while the original Firebase UID is still authenticated',
    (tester) async {
      final repo = OwnershipCheckingLocations();
      final h = await Harness.create(tester, repo: repo);
      repo.authenticatedUid = () => h.account.current;
      try {
        await perform(tester, () => h.sharing.start('shared-group'));
        await perform(tester, h.services.profile.signOut);
        await flushGps();
        expect(repo.removedWhileAuthenticated, ['alice-uid']);
        expect(repo.values['shared-group'], isEmpty);
        expect(h.account.current, isNull);
        expect(h.sharing.isSharing, isFalse);
        expect(h.gps.cancellations, 1);
      } finally {
        await h.close();
        repo.dispose();
      }
    },
  );

  testWidgets(
    'an external authenticated UID switch cannot inherit sharing or receive late writes',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        await perform(tester, () => h.sharing.start('shared-group'));
        h.account.profiles['bob-uid'] = const UserProfile(
          id: 'bob-uid',
          fullName: 'Bob',
          email: 'bob@test.com',
        );
        h.account.current = 'bob-uid';
        h.account.events.add('bob-uid');
        await h.services.profile.ready;
        await flushGps();
        expect(h.services.profile.profile.id, 'bob-uid');
        expect(h.sharing.isSharing, isFalse);
        expect(h.repo.values['shared-group'], isEmpty);
        h.gps.updates.add(const LatLng(8, 81));
        await tester.pump();
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.gps.watches, 1);
      } finally {
        await h.close();
      }
    },
  );

  testWidgets(
    'app-level background observer stops sharing on Home and resume never restarts it',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        h.rootOwnsServices = true;
        await tester.pumpWidget(
          HeritageWalkApp(services: h.services, initialRoute: AppRoutes.home),
        );
        await tester.pumpAndSettle();
        await perform(tester, () => h.sharing.start('shared-group'));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await flushGps();
        expect(h.sharing.isSharing, isFalse);
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.gps.cancellations, 1);
        await perform(tester, () => h.sharing.start('shared-group'));
        expect(h.sharing.isSharing, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(h.gps.watches, 1);
        expect(h.sharing.isSharing, isFalse);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await h.close();
      }
    },
  );

  testWidgets(
    'late permission/GPS result after backgrounding cannot start sharing',
    (tester) async {
      final gps = FakeGps()..pending = Completer<LatLng>();
      final h = await Harness.create(tester, gps: gps);
      try {
        final start = h.sharing.start('shared-group');
        await flushGps();
        h.sharing.handleLifecycle(AppLifecycleState.paused);
        gps.pending!.complete(gps.fix);
        await start;
        await flushGps();
        expect(h.sharing.isSharing, isFalse);
        expect(h.repo.values, isEmpty);
        expect(gps.watches, 0);
        h.sharing.handleLifecycle(AppLifecycleState.resumed);
      } finally {
        await h.close();
      }
    },
  );

  testWidgets(
    'stale and outsider positions remain hidden during the app-level session',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        final view = h.sharing.acquire('shared-group');
        await h.repo.write(
          'shared-group',
          SharedLocation(
            'bob-uid',
            'Bob',
            const LatLng(8, 81),
            tester.binding.clock.now().subtract(const Duration(minutes: 3)),
          ),
        );
        await h.repo.write(
          'shared-group',
          SharedLocation(
            'outsider',
            'Other',
            const LatLng(8, 81),
            tester.binding.clock.now(),
          ),
        );
        await perform(tester, () => h.sharing.start('shared-group'));
        await flushGps();
        expect(view.freshLocations.map((l) => l.userId), ['alice-uid']);
        h.sharing.release('shared-group');
      } finally {
        await h.close();
      }
    },
  );

  test(
    'foreground-only change adds no background/service location permissions',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(manifest, isNot(contains('FOREGROUND_SERVICE_LOCATION')));
      expect(
        manifest,
        isNot(contains('android:foregroundServiceType="location"')),
      );
    },
  );

  testWidgets(
    'resume reconciles a passed monotonic deadline even when the timer was delayed',
    (tester) async {
      var extra = Duration.zero;
      final h = await Harness.create(tester, additionalElapsed: () => extra);
      try {
        await perform(tester, () => h.sharing.start('shared-group'));
        extra = const Duration(minutes: 6);
        h.sharing.handleLifecycle(AppLifecycleState.resumed);
        await tester.pump();
        await flushGps();
        expect(h.sharing.isSharing, isFalse);
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.gps.cancellations, 1);
        h.gps.updates.add(const LatLng(8, 81));
        await tester.pump();
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.gps.watches, 1);
        await h.tracking();
        expect(find.text('Sharing OFF'), findsOneWidget);
      } finally {
        await h.close();
      }
    },
  );

  testWidgets(
    'reusing the tracking widget with another group reads Y without reassigning X sharing',
    (tester) async {
      final h = await Harness.create(tester);
      try {
        final other = TourGroup.fromMap({
          ...fixtures.trackingGroup().toMap(),
          'id': 'other-group',
          'inviteCode': 'OTHER1',
        });
        h.services.groups.restore([fixtures.trackingGroup(), other]);
        await h.tracking();
        await press(tester, 'Start Sharing Location');
        await tester.pumpWidget(
          MaterialApp(
            home: GroupTourScope(
              service: h.services.groups,
              child: DiscoveryScope(
                state: h.services.discovery,
                child: const GroupTrackingScreen(groupId: 'other-group'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sharing OFF'), findsOneWidget);
        expect(h.sharing.activeGroupId, 'shared-group');
        expect(h.gps.watches, 1);
        await press(tester, 'Start Sharing Location');
        expect(h.sharing.activeGroupId, 'other-group');
        expect(h.repo.values['shared-group'], isEmpty);
        expect(h.repo.values['other-group']!.keys, ['alice-uid']);
        expect(h.gps.cancellations, 1);
      } finally {
        await h.close();
      }
    },
  );
}
