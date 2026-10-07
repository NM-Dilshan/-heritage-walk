import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:heritage_walk/core/firebase/account_repository.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/firebase/social_auth.dart';
import 'package:heritage_walk/core/localization/app_localizations.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/auth_profile/screens/login_screen.dart';
import 'package:heritage_walk/features/auth_profile/services/profile_service.dart';
import 'package:heritage_walk/features/auth_profile/widgets/password_reset_dialog.dart';
import 'package:heritage_walk/features/auth_profile/widgets/profile_avatar.dart';
import 'package:heritage_walk/features/auth_profile/widgets/social_auth_buttons.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';
import 'package:heritage_walk/main.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCredential extends Mock implements UserCredential {}

class MockGoogle extends Mock implements GoogleSignIn {}

class MockGoogleAccount extends Mock implements GoogleSignInAccount {}

class MockFacebook extends Mock implements FacebookAuth {}

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockUserInfo extends Mock implements UserInfo {}

class Credentials implements SocialCredentialSource {
  int requests = 0, logouts = 0;
  bool cancelled = false;
  Object? failure;
  Object? logoutFailure;
  Set<SocialProvider> clearedProviders = {};
  Completer<void>? gate;
  @override
  Future<AuthCredential?> credential(SocialProvider provider) async {
    requests++;
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    if (cancelled) return null;
    return provider == SocialProvider.google
        ? GoogleAuthProvider.credential(idToken: 'isolated-google-token')
        : FacebookAuthProvider.credential('isolated-facebook-token');
  }

  @override
  Future<void> signOut({Set<SocialProvider> providers = const {}}) async {
    logouts++;
    clearedProviders = providers;
    if (logoutFailure != null) throw logoutFailure!;
  }
}

/// Exercise the production Firebase repository, with SDK/network replacements.
class Fixture {
  Fixture({
    String? email = 'visitor@test.com',
    String? name = 'Visitor',
    String? photo = 'https://example.invalid/avatar.png',
  }) {
    when(() => user.uid).thenReturn('social-uid');
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(name);
    when(() => user.photoURL).thenReturn(photo);
    when(() => user.providerData).thenReturn([]);
    when(() => result.user).thenReturn(user);
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => auth.authStateChanges())
        .thenAnswer((_) => Stream.value(current));
    when(() => auth.signInWithCredential(any())).thenAnswer((invocation) async {
      credentialCalls++;
      received = invocation.positionalArguments.first as AuthCredential;
      if (credentialFailure != null) throw credentialFailure!;
      current = user;
      return result;
    });
    when(() => auth.signOut()).thenAnswer((_) async {
      firebaseLogouts++;
      current = null;
    });
    when(() => auth.sendPasswordResetEmail(email: any(named: 'email')))
        .thenAnswer((invocation) async {
          resetCalls++;
          resetEmail = invocation.namedArguments[#email] as String;
          if (resetGate != null) await resetGate!.future;
          if (resetFailure != null) throw resetFailure!;
        });
    repository = FirebaseAccountRepository(auth, db, social: source);
  }
  final auth = MockAuth(), user = MockUser(), result = MockCredential();
  final db = FakeFirebaseFirestore();
  final source = Credentials();
  late final FirebaseAccountRepository repository;
  User? current;
  AuthCredential? received;
  Object? credentialFailure, resetFailure;
  Completer<void>? resetGate;
  String? resetEmail;
  int credentialCalls = 0, firebaseLogouts = 0, resetCalls = 0;
  ProfileService service() =>
      ProfileService(repository: repository)..initialize();
  Future<Map<String, dynamic>?> document() async =>
      (await db.collection('users').doc('social-uid').get()).data();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> launch(
  WidgetTester tester,
  Fixture fixture, {
  String route = AppRoutes.login,
  String locale = 'en',
}) async {
  final services = AppServices(account: fixture.repository);
  await tester.pump();
  await services.profile.ready;
  services.language.setLanguage(locale);
  await tester.pumpWidget(
    HeritageWalkApp(services: services, initialRoute: route),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fake')),
  );
  setUpAll(
    () => registerFallbackValue(
      (Transaction tx) async =>
          const UserProfile(id: '', fullName: '', email: ''),
    ),
  );

  group('Forgot password', () {
    for (final entry in {
      '': 'Email is required',
      'bad': 'Enter a valid email address.',
      'a@': 'Enter a valid email address.',
    }.entries) {
      test(
        'rejects ${entry.key.isEmpty ? 'empty' : entry.key} before Firebase',
        () async {
          final f = Fixture();
          final actual = ProfileService(repository: f.repository);
          await expectLater(
            actual.sendPasswordReset(entry.key),
            throwsA(isA<BackendFailure>()),
          );
          expect(f.resetCalls, 0);
          actual.dispose();
        },
      );
    }
    test('trims valid email and uses Firebase reset API', () async {
      final f = Fixture();
      final actual = ProfileService(repository: f.repository);
      await actual.sendPasswordReset('  visitor@test.com  ');
      expect(f.resetEmail, 'visitor@test.com');
      expect(f.resetCalls, 1);
      expect(await f.document(), isNull);
      expect(f.current, isNull);
      actual.dispose();
    });
    test(
      'legacy user-not-found response does not enumerate an email',
      () async {
        final f = Fixture()
          ..resetFailure = FirebaseAuthException(code: 'user-not-found');
        await f.repository.resetPassword('absent@test.com');
        expect(f.resetCalls, 1);
      },
    );
    for (final code in [
      'network-request-failed',
      'too-many-requests',
      'invalid-email',
      'internal-error',
    ]) {
      test('propagates $code without success', () async {
        final f = Fixture()
          ..resetFailure = FirebaseAuthException(
            code: code,
            message: 'private raw detail',
          );
        await expectLater(
          f.repository.resetPassword('a@test.com'),
          throwsA(isA<FirebaseAuthException>()),
        );
        expect(
          backendMessage(f.resetFailure!),
          isNot(contains('private raw detail')),
        );
      });
    }
    test('unexpected failures are safe', () {
      expect(
        backendMessage(StateError('token=private')),
        'Unable to complete the request. Please try again.',
      );
    });
    test('concurrent service reset is rejected and retry recovers', () async {
      final f = Fixture()..resetGate = Completer<void>();
      final service = f.service();
      await service.ready;
      final pending = service.sendPasswordReset('a@test.com');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        service.sendPasswordReset('b@test.com'),
        throwsA(isA<BackendFailure>()),
      );
      expect(f.resetCalls, 1);
      f.resetGate!.complete();
      await pending;
      f.resetGate = null;
      await service.sendPasswordReset('b@test.com');
      expect(f.resetCalls, 2);
      service.dispose();
    });
    testWidgets('dialog validates both empty and malformed email', (
      tester,
    ) async {
      final f = Fixture();
      await launch(tester, f);
      await tapText(tester, 'Forgot Password?');
      await tapText(tester, 'Send Reset Link');
      expect(find.text('Email is required'), findsOneWidget);
      final input = find.descendant(
        of: find.byType(PasswordResetDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(input, 'bad');
      await tapText(tester, 'Send Reset Link');
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(f.resetCalls, 0);
    });
    testWidgets(
      'successful reset gives neutral inbox/spam notice and returns Login',
      (tester) async {
        final f = Fixture();
        await launch(tester, f);
        await tapText(tester, 'Forgot Password?');
        await tester.enterText(
          find.byType(TextFormField).last,
          'visitor@test.com',
        );
        await tapText(tester, 'Send Reset Link');
        expect(find.byType(PasswordResetDialog), findsNothing);
        expect(
          find.textContaining('Check your inbox and spam folder.'),
          findsOneWidget,
        );
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(f.current, isNull);
      },
    );
    testWidgets('dialog disables repeat submit and back while sending', (
      tester,
    ) async {
      final f = Fixture()..resetGate = Completer<void>();
      await launch(tester, f);
      await tapText(tester, 'Forgot Password?');
      await tester.enterText(
        find.byType(TextFormField).last,
        'visitor@test.com',
      );
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(f.resetCalls, 1);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Back to Login'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).last).enabled,
        isFalse,
      );
      f.resetGate!.complete();
      await tester.pumpAndSettle();
      expect(f.resetCalls, 1);
    });
    for (final code in [
      'network-request-failed',
      'too-many-requests',
      'internal-error',
    ]) {
      testWidgets('dialog shows friendly $code and permits retry', (
        tester,
      ) async {
        final f = Fixture()
          ..resetFailure = FirebaseAuthException(
            code: code,
            message: 'raw-private',
          );
        await launch(tester, f);
        await tapText(tester, 'Forgot Password?');
        await tester.enterText(
          find.byType(TextFormField).last,
          'visitor@test.com',
        );
        await tapText(tester, 'Send Reset Link');
        expect(find.byType(PasswordResetDialog), findsOneWidget);
        expect(find.text(backendMessage(f.resetFailure!)), findsOneWidget);
        expect(find.textContaining('raw-private'), findsNothing);
        f.resetFailure = null;
        await tapText(tester, 'Send Reset Link');
        expect(find.byType(PasswordResetDialog), findsNothing);
        expect(f.resetCalls, 2);
      });
    }
    testWidgets('back dismisses without sending', (tester) async {
      final f = Fixture();
      await launch(tester, f);
      await tapText(tester, 'Forgot Password?');
      await tapText(tester, 'Back to Login');
      expect(f.resetCalls, 0);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  for (final provider in SocialProvider.values) {
    final title = provider == SocialProvider.google ? 'Google' : 'Facebook';
    group(title, () {
      test(
        'Firestore failure clears partial Firebase session and blocks Home',
        () async {
          final f = Fixture(), db = MockFirestore();
          when(() => db.collection('users'))
              .thenReturn(f.db.collection('users'));
          when(() => db.runTransaction<UserProfile>(any())).thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );
          final repository = FirebaseAccountRepository(
            f.auth,
            db,
            social: f.source,
          );
          final service = ProfileService(repository: repository)..initialize();
          await service.ready;
          await expectLater(
            service.signInSocial(provider),
            throwsA(isA<FirebaseException>()),
          );
          expect(f.current, isNull);
          expect(service.isAuthenticated, isFalse);
          expect(await f.document(), isNull);
          service.dispose();
        },
      );
      test(
        'first login creates existing schema, role user and provider photo',
        () async {
          final f = Fixture();
          expect(
            await f.repository.signInSocial(provider),
            SocialResult.authenticated,
          );
          final doc = (await f.document())!;
          expect(doc['uid'], 'social-uid');
          expect(doc['id'], 'social-uid');
          expect(doc['role'], 'user');
          expect(doc['fullName'], 'Visitor');
          expect(doc['photoPath'], 'https://example.invalid/avatar.png');
          expect(doc['createdAt'], isA<Timestamp>());
          expect(doc['updatedAt'], isA<Timestamp>());
          expect(f.received!.providerId, '${provider.name}.com');
        },
      );
      test(
        'existing admin and every profile/private field remain untouched',
        () async {
          final f = Fixture();
          final ref = f.db.collection('users').doc('social-uid');
          final original = {
            ...const UserProfile(
              id: 'social-uid',
              fullName: 'Custom',
              email: 'contact@test.com',
              role: 'admin',
              phone: '123',
              bio: 'Keep',
              photoPath: 'assets/custom.png',
            ).toMap(),
            'uid': 'social-uid',
            'createdAt': Timestamp(12, 0),
            'updatedAt': Timestamp(13, 0),
            'extra': 'preserve',
          };
          await ref.set(original);
          for (final collection in [
            'favorites',
            'itineraries',
            'guideNotes',
            'supportRequests',
            'preferences',
          ]) {
            await ref.collection(collection).doc('saved').set({
              'private': collection,
            });
          }
          await f.repository.signInSocial(provider);
          expect(await f.document(), original);
          for (final collection in [
            'favorites',
            'itineraries',
            'guideNotes',
            'supportRequests',
            'preferences',
          ]) {
            expect(
              (await ref.collection(collection).doc('saved').get()).data(),
              {'private': collection},
            );
          }
          expect((await f.repository.restore())!.isAdmin, isTrue);
        },
      );
      test('existing user cannot gain role from provider identity', () async {
        final f = Fixture(name: 'Administrator', email: 'admin@google.com');
        await f.repository.signInSocial(provider);
        expect((await f.document())!['role'], 'user');
        await f.repository.signInSocial(provider);
        expect((await f.document())!['role'], 'user');
        expect((await f.db.collection('users').get()).docs.length, 1);
      });
      for (final missing in ['email', 'photo', 'name']) {
        test('missing $missing is optional', () async {
          final f = Fixture(
            email: missing == 'email' ? null : 'a@test.com',
            photo: missing == 'photo' ? null : 'https://example.invalid/photo',
            name: missing == 'name' ? null : 'Visitor',
          );
          await f.repository.signInSocial(provider);
          final profile = (await f.repository.restore())!;
          if (missing == 'email') expect(profile.email, '');
          if (missing == 'photo') expect(profile.photoPath, isNull);
          if (missing == 'name') expect(profile.fullName, '');
          expect(profile.role, 'user');
        });
      }
      test('cancellation does not authenticate or write', () async {
        final f = Fixture();
        f.source.cancelled = true;
        final service = f.service();
        await service.ready;
        expect(await service.signInSocial(provider), SocialResult.cancelled);
        expect(service.isAuthenticated, isFalse);
        expect(f.credentialCalls, 0);
        expect(await f.document(), isNull);
        service.dispose();
      });
      test(
        'provider failure never reaches Firebase credential exchange',
        () async {
          final f = Fixture();
          f.source.failure = const BackendFailure(
            'Unable to complete the request. Please try again.',
          );
          final service = f.service();
          await service.ready;
          await expectLater(
            service.signInSocial(provider),
            throwsA(isA<BackendFailure>()),
          );
          expect(service.isAuthenticated, isFalse);
          expect(f.credentialCalls, 0);
          expect(await f.document(), isNull);
          service.dispose();
        },
      );
      test('Firebase credential rejection does not create profile', () async {
        final f = Fixture()
          ..credentialFailure = FirebaseAuthException(
            code: 'invalid-credential',
          );
        final service = f.service();
        await service.ready;
        await expectLater(
          service.signInSocial(provider),
          throwsA(
            isA<BackendFailure>().having(
              (error) => error.message,
              'provider error',
              'Unable to sign in with $title. Please try again.',
            ),
          ),
        );
        expect(service.isAuthenticated, isFalse);
        expect(await f.document(), isNull);
        service.dispose();
      });
      test(
        'provider collision preserves data and gives verification guidance',
        () async {
          final f = Fixture()
            ..credentialFailure = FirebaseAuthException(
              code: 'account-exists-with-different-credential',
            );
          await f.db.collection('users').doc('original-uid').set({
            'role': 'admin',
            'private': 'keep',
          });
          await expectLater(
            f.repository.signInSocial(provider),
            throwsA(isA<FirebaseAuthException>()),
          );
          expect(await f.document(), isNull);
          expect(
            (await f.db.collection('users').doc('original-uid').get()).data(),
            {'role': 'admin', 'private': 'keep'},
          );
          expect(
            backendMessage(f.credentialFailure!),
            contains('existing account method'),
          );
        },
      );
      test('session restores Firebase identity on a fresh service', () async {
        final f = Fixture();
        final first = f.service();
        await first.ready;
        await first.signInSocial(provider);
        first.dispose();
        final next = f.service();
        await next.ready;
        expect(next.isAuthenticated, isTrue);
        expect(next.profile.id, 'social-uid');
        next.dispose();
      });
      test(
        'logout clears Firebase and provider, login again keeps profile',
        () async {
          final f = Fixture();
          final info = MockUserInfo();
          when(() => info.providerId).thenReturn('${provider.name}.com');
          when(() => f.user.providerData).thenReturn([info]);
          final service = f.service();
          await service.ready;
          await service.signInSocial(provider);
          final before = await f.document();
          await service.signOut();
          expect(f.current, isNull);
          expect(f.source.logouts, 1);
          expect(f.source.clearedProviders, contains(provider));
          expect(service.isAuthenticated, isFalse);
          await service.signInSocial(provider);
          expect(await f.document(), before);
          service.dispose();
        },
      );
      test(
        'service rejects competing social, email and reset requests',
        () async {
          final f = Fixture();
          f.source.gate = Completer<void>();
          final service = f.service();
          await service.ready;
          final pending = service.signInSocial(provider);
          await Future<void>.delayed(Duration.zero);
          await expectLater(
            service.signInSocial(provider),
            throwsA(isA<BackendFailure>()),
          );
          await expectLater(
            service.signIn('a@test.com', password: 'Secure123'),
            throwsA(isA<BackendFailure>()),
          );
          await expectLater(
            service.sendPasswordReset('a@test.com'),
            throwsA(isA<BackendFailure>()),
          );
          expect(f.source.requests, 1);
          f.source.gate!.complete();
          await pending;
          service.dispose();
        },
      );
      for (final route in [AppRoutes.login, AppRoutes.register]) {
        testWidgets(
          '$route has both providers, no Apple, successful login Home',
          (tester) async {
            final f = Fixture();
            await launch(tester, f, route: route);
            expect(find.text('Continue with Google'), findsOneWidget);
            expect(find.text('Continue with Facebook'), findsOneWidget);
            expect(find.textContaining('Apple'), findsNothing);
            for (final p in SocialProvider.values) {
              final button = find.byKey(ValueKey('social-${p.name}'));
              final icon = find.descendant(
                of: button,
                matching: find.byKey(ValueKey('social-${p.name}-icon')),
              );
              final image = tester.widget<Image>(icon);
              expect(
                (image.image as AssetImage).assetName,
                'assets/branding/${p.name}_sign_in.png',
              );
              expect(image.width, 24);
              expect(image.height, 24);
              expect(image.color, isNull);
              final group = find.descendant(
                of: button,
                matching: find.byType(Row),
              );
              expect(
                tester.getCenter(group).dx,
                closeTo(tester.getCenter(button).dx, 1),
              );
            }
            expect(
              tester.getSize(find.byKey(const ValueKey('social-google'))),
              tester.getSize(find.byKey(const ValueKey('social-facebook'))),
            );
            await tapText(tester, 'Continue with $title');
            expect(find.byType(HomeScreen), findsOneWidget);
          },
        );
      }
      testWidgets(
        'loading disables both providers and email, cancel resets UI',
        (tester) async {
          final f = Fixture();
          f.source.gate = Completer<void>();
          f.source.cancelled = true;
          await launch(tester, f);
          await tester.ensureVisible(find.text('Continue with $title'));
          await tester.tap(find.text('Continue with $title'));
          await tester.pump();
          expect(find.text('Signing in with $title…'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            find.byKey(ValueKey('social-${provider.name}-icon')),
            findsNothing,
          );
          for (final p in SocialProvider.values) {
            expect(
              tester
                  .widget<OutlinedButton>(
                    find.byKey(ValueKey('social-${p.name}')),
                  )
                  .onPressed,
              isNull,
            );
          }
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .enabled,
            isFalse,
          );
          expect(f.source.requests, 1);
          f.source.gate!.complete();
          await tester.pumpAndSettle();
          expect(find.text('Continue with $title'), findsOneWidget);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(await f.document(), isNull);
          expect(find.byType(SnackBar), findsNothing);
        },
      );
      testWidgets(
        'failure stays Login, restores buttons and displays safe error',
        (tester) async {
          final f = Fixture()
            ..credentialFailure = FirebaseAuthException(
              code: 'network-request-failed',
              message: 'raw token',
            );
          await launch(tester, f);
          await tapText(tester, 'Continue with $title');
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(
            find.text(backendMessage(f.credentialFailure!)),
            findsOneWidget,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(ValueKey('social-${provider.name}')),
                )
                .onPressed,
            isNotNull,
          );
          expect(find.textContaining('raw token'), findsNothing);
        },
      );
    });
  }

  group('Native provider adapters (mock SDKs)', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);
    test('restored Google logout initializes SDK and clears local state without chooser', () async {
      final google = MockGoogle();
      when(() => google.initialize()).thenAnswer((_) async {});
      when(() => google.signOut()).thenAnswer((_) async {});
      await DeviceSocialCredentialSource(
        google: google,
        facebookConfigured: () async => false,
      ).signOut(providers: {SocialProvider.google});
      verify(() => google.initialize()).called(1);
      verify(() => google.signOut()).called(1);
      verifyNever(() => google.authenticate());
      verifyNever(() => google.disconnect());
    });
    test(
      'Google 7 initialize once, authenticate ID token and ordinary signOut',
      () async {
        final google = MockGoogle(), account = MockGoogleAccount();
        when(() => google.initialize()).thenAnswer((_) async {});
        when(() => google.authenticate()).thenAnswer((_) async => account);
        when(() => account.authentication)
            .thenReturn(const GoogleSignInAuthentication(idToken: 'id-token'));
        when(() => google.signOut()).thenAnswer((_) async {});
        final source = DeviceSocialCredentialSource(
          google: google,
          facebookConfigured: () async => false,
        );
        for (var i = 0; i < 2; i++) {
          expect(
            (await source.credential(SocialProvider.google))!.providerId,
            'google.com',
          );
        }
        await source.signOut();
        verify(() => google.initialize()).called(1);
        verify(() => google.authenticate()).called(2);
        verify(() => google.signOut()).called(1);
        verifyNever(() => google.disconnect());
      },
    );
    for (final code in [
      GoogleSignInExceptionCode.canceled,
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.unknownError,
    ]) {
      test('Google handles $code without technical details', () async {
        final google = MockGoogle();
        when(() => google.initialize()).thenAnswer((_) async {});
        when(() => google.authenticate()).thenThrow(
          GoogleSignInException(
            code: code,
            description: 'private native detail',
          ),
        );
        final source = DeviceSocialCredentialSource(google: google);
        if (code == GoogleSignInExceptionCode.canceled) {
          expect(await source.credential(SocialProvider.google), isNull);
        } else {
          await expectLater(
            source.credential(SocialProvider.google),
            throwsA(isA<BackendFailure>()),
          );
        }
      });
    }
    test('Google missing ID token is failure', () async {
      final google = MockGoogle(), account = MockGoogleAccount();
      when(() => google.initialize()).thenAnswer((_) async {});
      when(() => google.authenticate()).thenAnswer((_) async => account);
      when(() => account.authentication)
          .thenReturn(const GoogleSignInAuthentication(idToken: null));
      await expectLater(
        DeviceSocialCredentialSource(google: google)
            .credential(SocialProvider.google),
        throwsA(isA<BackendFailure>()),
      );
    });
    for (final status in LoginStatus.values) {
      test('Facebook maps $status with installed tokenString API', () async {
        final facebook = MockFacebook();
        when(() => facebook.login(permissions: ['email', 'public_profile']))
            .thenAnswer(
              (_) async => LoginResult(
                status: status,
                message: 'private provider text',
                accessToken: status == LoginStatus.success
                    ? ClassicToken(
                        tokenString: 'fb-token',
                        expires: DateTime(2030),
                        userId: 'test-user',
                        applicationId: 'test-only',
                        declinedPermissions: [],
                        grantedPermissions: ['email'],
                      )
                    : null,
              ),
            );
        final source = DeviceSocialCredentialSource(
          facebook: facebook,
          facebookConfigured: () async => true,
        );
        if (status == LoginStatus.success) {
          expect(
            (await source.credential(SocialProvider.facebook))!.accessToken,
            'fb-token',
          );
        } else if (status == LoginStatus.cancelled) {
          expect(await source.credential(SocialProvider.facebook), isNull);
        } else {
          await expectLater(
            source.credential(SocialProvider.facebook),
            throwsA(isA<BackendFailure>()),
          );
        }
      });
    }
    test('Facebook missing configuration never opens provider', () async {
      final facebook = MockFacebook();
      final source = DeviceSocialCredentialSource(
        facebook: facebook,
        facebookConfigured: () async => false,
      );
      await expectLater(
        source.credential(SocialProvider.facebook),
        throwsA(isA<BackendFailure>()),
      );
      verifyNever(() => facebook.login(permissions: any(named: 'permissions')));
    });
    test('Facebook success without token is rejected', () async {
      final facebook = MockFacebook();
      when(() => facebook.login(permissions: ['email', 'public_profile']))
          .thenAnswer((_) async => LoginResult(status: LoginStatus.success));
      await expectLater(
        DeviceSocialCredentialSource(
          facebook: facebook,
          facebookConfigured: () async => true,
        ).credential(SocialProvider.facebook),
        throwsA(isA<BackendFailure>()),
      );
    });
    test(
      'Facebook native failure is safe and local logout uses logOut',
      () async {
        final facebook = MockFacebook();
        when(() => facebook.login(permissions: ['email', 'public_profile']))
            .thenThrow(PlatformException(code: 'FAILED', message: 'raw'));
        when(() => facebook.logOut()).thenAnswer((_) async {});
        final source = DeviceSocialCredentialSource(
          facebook: facebook,
          facebookConfigured: () async => true,
        );
        await expectLater(
          source.credential(SocialProvider.facebook),
          throwsA(isA<BackendFailure>()),
        );
        await source.signOut();
        verify(() => facebook.logOut()).called(1);
      },
    );
    test(
      'Firebase logout still clears session if optional provider logout fails',
      () async {
        final f = Fixture();
        f.current = f.user;
        f.source.logoutFailure = StateError('local cleanup failure');
        await f.repository.signOut();
        expect(f.current, isNull);
        expect(f.firebaseLogouts, 1);
      },
    );
  });

  testWidgets(
    'network avatar falls back after failed image without exception',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileAvatar(
            profile: UserProfile(
              id: 'u',
              fullName: 'Test Visitor',
              email: '',
              photoPath: 'https://example.invalid/avatar.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'social icons remain balanced on compact $brightness screen with large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = ProfileService();
        addTearDown(service.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ProfileScope(
                service: service,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SocialAuthButtons(busy: false, onBusyChanged: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final google = find.byKey(const ValueKey('social-google'));
        final facebook = find.byKey(const ValueKey('social-facebook'));
        expect(tester.getSize(google), tester.getSize(facebook));
        expect(
          tester.getTopLeft(facebook).dy - tester.getBottomLeft(google).dy,
          12,
        );
        for (final p in SocialProvider.values) {
          final icon = find.byKey(ValueKey('social-${p.name}-icon'));
          expect(tester.getSize(icon), const Size(24, 24));
          expect(tester.widget<Image>(icon).color, isNull);
        }
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue with Facebook'), findsOneWidget);
        expect(find.textContaining('Apple'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing photo and name display existing fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileAvatar(
          profile: UserProfile(id: 'u', fullName: '', email: ''),
        ),
      ),
    );
    expect(find.text('?'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
  test('all new resources have complete English Sinhala Tamil parity', () {
    final maps = {
      for (final code in ['en', 'si', 'ta'])
        code: jsonDecode(
          File('assets/l10n/$code.json').readAsStringSync(),
        ) as Map<String, dynamic>,
    };
    final keys = File('tool/part92_translations.tsv')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty)
        .map((line) => line.split('|').first);
    expect(maps['si']!.keys.toSet(), maps['en']!.keys.toSet());
    expect(maps['ta']!.keys.toSet(), maps['en']!.keys.toSet());
    for (final key in keys) {
      for (final code in ['si', 'ta']) {
        expect(maps[code]![key], isNotEmpty);
        expect(maps[code]![key], isNot(key));
      }
    }
  });
  for (final code in ['si', 'ta']) {
    testWidgets(
      '$code compact Login/Register and reset retain localized provider UI',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = Fixture();
        await launch(tester, f, locale: code);
        final l10n = AppLocalizations.maybeOf(
          tester.element(find.byType(LoginScreen)),
        )!;
        expect(find.text(l10n.get('Continue with Facebook')), findsOneWidget);
        expect(find.text('Continue with Apple'), findsNothing);
        await tapText(tester, l10n.get('Forgot Password?'));
        expect(find.text(l10n.get('Send Reset Link')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapText(tester, l10n.get('Back to Login'));
        await tapText(tester, l10n.get('Sign Up'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
