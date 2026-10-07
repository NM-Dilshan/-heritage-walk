import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/shared/widgets/heritage_button.dart';
import 'package:heritage_walk/shared/widgets/heritage_text_field.dart';

Finder field(String label) => find.widgetWithText(HeritageTextField, label);
Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
}

Future<void> tap(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = text == 'View Profile'
      ? find.byTooltip(text)
      : find.text(text).last;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

Future<void> launch(WidgetTester tester, String route) async {
  await tester.pumpWidget(HeritageWalkApp(initialRoute: route));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash renders and is replaced by Login after two seconds', (
    tester,
  ) async {
    await tester.pumpWidget(const HeritageWalkApp());
    expect(find.text('Sri Lanka'), findsOneWidget);
    expect(
      find.text('Explore \u2022 Discover \u2022 Preserve'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Welcome Back'))).canPop(),
      isFalse,
    );
  });

  testWidgets('Login validates required and malformed credentials', (
    tester,
  ) async {
    await launch(tester, AppRoutes.login);
    await tap(tester, 'Sign In');
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    await enter(tester, 'Email', 'bad-email');
    await enter(tester, 'Password', '123');
    await tap(tester, 'Sign In');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
  });

  testWidgets('Login opens Register, validates and creates a profile', (
    tester,
  ) async {
    await launch(tester, AppRoutes.login);
    await tap(tester, 'Sign Up');
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    await tap(tester, 'Sign Up');
    await tester.pumpAndSettle();
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);
    await enter(tester, 'Full Name', 'A');
    await enter(tester, 'Email', 'asha@example.com');
    await enter(tester, 'Password', 'secret1');
    await enter(tester, 'Confirm Password', 'wrong1');
    await tap(tester, 'Sign Up');
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 2 characters'), findsOneWidget);
    expect(find.text('Passwords must match'), findsOneWidget);
    await enter(tester, 'Full Name', 'Asha Silva');
    await enter(tester, 'Confirm Password', 'secret1');
    await tap(tester, 'Sign Up');
    expect(
      tester
          .widget<HeritageButton>(find.byType(HeritageButton).first)
          .isLoading,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to HeritageWalk'), findsOneWidget);
    await tap(tester, 'View Profile');
    await tester.pumpAndSettle();
    expect(find.text('Asha Silva'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
  });

  testWidgets(
    'Profile edits load and immediately update displayed information',
    (tester) async {
      await launch(tester, AppRoutes.profile);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Nuwan Perera'), findsOneWidget);
      await tap(tester, 'Edit Profile');
      await tester.pumpAndSettle();
      expect(
        tester.widget<HeritageTextField>(field('Full Name')).controller!.text,
        'Nuwan Perera',
      );
      expect(
        tester.widget<HeritageTextField>(field('Phone')).controller!.text,
        '+94 77 123 4567',
      );
      await enter(tester, 'Full Name', 'Nuwan Silva');
      await enter(tester, 'Email', 'silva@example.com');
      await enter(tester, 'Phone', '+94 (77) 987-6543');
      await enter(tester, 'Bio', 'Exploring Sri Lanka.');
      await tap(tester, 'Save Changes');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Nuwan Silva'), findsOneWidget);
      expect(find.text('silva@example.com'), findsOneWidget);
      expect(find.text('Profile updated successfully'), findsOneWidget);
      await tap(tester, 'Edit Profile');
      await tester.pumpAndSettle();
      expect(
        tester.widget<HeritageTextField>(field('Bio')).controller!.text,
        'Exploring Sri Lanka.',
      );
      expect(
        tester.widget<HeritageTextField>(field('Phone')).controller!.text,
        '+94 (77) 987-6543',
      );
    },
  );

  testWidgets('Valid login and confirmed logout clear navigation history', (
    tester,
  ) async {
    await launch(tester, AppRoutes.login);
    await enter(tester, 'Email', 'nuwan@example.com');
    await enter(tester, 'Password', 'secret1');
    await tap(tester, 'Sign In');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to HeritageWalk'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Welcome to HeritageWalk')))
          .canPop(),
      isFalse,
    );
    await tap(tester, 'View Profile');
    await tester.pumpAndSettle();
    await tap(tester, 'Logout');
    await tester.pumpAndSettle();
    await tap(tester, 'Cancel');
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    await tap(tester, 'Logout');
    await tester.pumpAndSettle();
    await tap(tester, 'Sign Out');
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Welcome Back'))).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'Reset validates email and isolated preview cannot start live social sign-in',
    (tester) async {
      await launch(tester, AppRoutes.login);
      await tap(tester, 'Continue with Google');
      await tester.pumpAndSettle();
      expect(
        find.text('Social sign-in is unavailable in this preview.'),
        findsOneWidget,
      );
      await tap(tester, 'Forgot Password?');
      await tester.pumpAndSettle();
      await tap(tester, 'Send Reset Link');
      await tester.pumpAndSettle();
      expect(find.text('Email is required'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'nuwan@example.com',
      );
      await tap(tester, 'Send Reset Link');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.text('Preview only: no reset email was sent.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Forms fit a small phone with keyboard and larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final route in [
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.profile,
      AppRoutes.editProfile,
    ]) {
      await tester.pumpWidget(const SizedBox());
      await launch(tester, route);
      expect(tester.takeException(), isNull);
      if (route == AppRoutes.register) {
        await tester.ensureVisible(find.text('Sign Up'));
      }
      if (route == AppRoutes.editProfile) {
        await tester.ensureVisible(find.text('Save Changes'));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
