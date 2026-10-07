import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/features/auth_profile/screens/login_screen.dart';

import 'support/part7_fakes.dart';

Future<void> tap(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash waits for auth restoration before routing', (
    tester,
  ) async {
    final account = FakeAccount();
    await account.register('Alice', 'a@test.com', 'Secure123');
    account.restoreGate = Completer<void>();
    final services = AppServices(account: account, data: FakeData());
    await tester.pumpWidget(HeritageWalkApp(services: services));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Sri Lanka'), findsOneWidget);
    account.restoreGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets(
    'External account change clears old private state and routes restored session',
    (tester) async {
      final account = FakeAccount(), data = FakeData();
      await account.register('Alice', 'a@test.com', 'Secure123');
      final services = AppServices(account: account, data: data);
      await services.profile.ready;
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();
      services.discovery.favorites.addFavorite(
        services.discovery.discovery.places.first,
      );
      await services.sync!.flush();
      await account.register('Bob', 'b@test.com', 'Secure123');
      await services.profile.ready;
      await tester.pumpAndSettle();
      expect(services.profile.profile.fullName, 'Bob');
      expect(services.discovery.favorites.getFavorites(), isEmpty);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(data.private['uid-1']!['favorites'], isNotEmpty);
    },
  );
  testWidgets('Restored auth preserves Splash and routes to Home', (
    tester,
  ) async {
    final account = FakeAccount();
    await account.register('Alice', 'a@test.com', 'Secure123');
    final services = AppServices(account: account, data: FakeData());
    await services.profile.ready;
    await tester.pumpWidget(HeritageWalkApp(services: services));
    expect(find.text('Sri Lanka'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
  testWidgets('Unauthenticated cloud deep links show Login', (tester) async {
    final services = AppServices(account: FakeAccount(), data: FakeData());
    await services.profile.ready;
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.groupTours),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('Real login abstraction receives password and routes Home', (
    tester,
  ) async {
    final account = FakeAccount();
    await account.register('Alice', 'a@test.com', 'Secure123');
    await account.signOut();
    final services = AppServices(account: account, data: FakeData());
    await services.profile.ready;
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.login),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secure123');
    await tap(tester, 'Sign In');
    expect(account.receivedPassword, 'Secure123');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets(
    'Registration keeps name and sends password through abstraction',
    (tester) async {
      final account = FakeAccount(), data = FakeData();
      final services = AppServices(account: account, data: data);
      await services.profile.ready;
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: AppRoutes.register),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        'Alice',
        'a@test.com',
        'Secure123',
        'Secure123',
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      await tap(tester, 'Sign Up');
      expect(services.profile.profile.fullName, 'Alice');
      expect(services.profile.profile.id, 'uid-1');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(data.writes, 0);
    },
  );
  testWidgets('Auth errors display safe message and retain login', (
    tester,
  ) async {
    final account = FakeAccount()..failureCode = 'invalid-credential';
    final services = AppServices(account: account, data: FakeData());
    await services.profile.ready;
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.login),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secure123');
    await tap(tester, 'Sign In');
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('Auth loading prevents duplicate submissions', (tester) async {
    final account = FakeAccount();
    await account.register('Alice', 'a@test.com', 'Secure123');
    await account.signOut();
    final services = AppServices(account: account, data: FakeData());
    await services.profile.ready;
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.login),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secure123');
    account.gate = Completer<void>();
    final before = account.calls;
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
    expect(account.calls, before + 1);
    account.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets(
    'Cloud write loading and failure are visible and reload recovers',
    (tester) async {
      final account = FakeAccount(), data = FakeData();
      await account.register('Alice', 'a@test.com', 'Secure123');
      final services = AppServices(account: account, data: data);
      await services.profile.ready;
      await tester.pumpWidget(
        HeritageWalkApp(services: services, initialRoute: AppRoutes.language),
      );
      await tester.pumpAndSettle();
      data.gate = Completer<void>();
      data.failWrites = true;
      await tester.tap(find.text('Tamil'));
      await tester.pump();
      expect(find.text('மாற்றங்கள் சேமிக்கப்படுகின்றன…'), findsOneWidget);
      data.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        services.language.selectedLanguageCode,
        'en',
      ); // Failed preference save rolls back.
      expect(
        find.textContaining('Cloud save was not confirmed'),
        findsOneWidget,
      );
      data.failWrites = false;
      data.gate = null;
      await tap(
        tester,
        find.text('சேமித்த தரவை மீளேற்றுங்கள்').evaluate().isNotEmpty
            ? 'சேமித்த தரவை மீளேற்றுங்கள்'
            : 'Reload Saved Data',
      );
      expect(services.sync!.error, isNull);
    },
  );
  testWidgets('Expired auth routes Login and clears user-specific caches', (
    tester,
  ) async {
    final account = FakeAccount(), data = FakeData();
    await account.register('Alice', 'a@test.com', 'Secure123');
    final services = AppServices(account: account, data: data);
    await services.profile.ready;
    await tester.pumpWidget(
      HeritageWalkApp(services: services, initialRoute: AppRoutes.home),
    );
    await tester.pumpAndSettle();
    services.discovery.favorites.addFavorite(
      services.discovery.discovery.places.first,
    );
    await services.sync!.flush();
    await account.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(services.discovery.favorites.getFavorites(), isEmpty);
    expect(data.private['uid-1']!['favorites'], isNotEmpty);
  });
}
