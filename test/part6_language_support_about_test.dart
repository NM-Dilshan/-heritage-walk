import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/core/constants/app_assets.dart';
import 'package:heritage_walk/features/group_support/screens/language_selection_screen.dart';
import 'package:heritage_walk/features/group_support/screens/help_support_screen.dart';
import 'package:heritage_walk/features/group_support/screens/about_screen.dart';
import 'package:heritage_walk/features/group_support/screens/group_tour_screen.dart';
import 'package:heritage_walk/features/group_support/services/language_service.dart';
import 'package:heritage_walk/features/group_support/services/support_service.dart';
import 'package:heritage_walk/features/group_support/models/support_request.dart';
import 'package:heritage_walk/features/group_support/widgets/language_option_card.dart';
import 'package:heritage_walk/features/group_support/widgets/faq_tile.dart';
import 'package:heritage_walk/features/group_support/widgets/support_request_card.dart';
import 'package:heritage_walk/features/navigation_guide/screens/emergency_support_screen.dart';
import 'package:heritage_walk/features/discovery_planning/screens/home_screen.dart';

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
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    press(tester, find.text(text).last);
Finder field(String label) => find.widgetWithText(TextFormField, label);
SupportService support(WidgetTester tester) =>
    SupportScope.of(tester.element(find.byType(HelpSupportScreen)));
Future<void> seed(WidgetTester tester) async {
  await launch(tester, AppRoutes.helpSupport);
  support(tester).createSupportRequest(
    subject: 'My question',
    message: 'Please explain tour planning',
    category: SupportCategory.tourPlanning,
  );
  await tester.pumpAndSettle();
}

Future<void> chooseCategory(WidgetTester tester, String label) async {
  await press(tester, find.byType(DropdownButtonFormField<SupportCategory>));
  await tapText(tester, label);
}

void main() {
  testWidgets('Language renders native names and one selected option', (
    tester,
  ) async {
    await launch(tester, AppRoutes.language);
    expect(find.text('Choose your preferred language'), findsOneWidget);
    expect(find.text('Sinhala'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('தமிழ்'), findsOneWidget);
    expect(
      tester
          .widgetList<LanguageOptionCard>(find.byType(LanguageOptionCard))
          .where((card) => card.selected)
          .single
          .language
          .code,
      'en',
    );
    expect(find.text('Explore Sri Lanka'), findsOneWidget);
  });
  testWidgets('Language changes service and translated preview', (
    tester,
  ) async {
    await launch(tester, AppRoutes.language);
    await tapText(tester, 'Sinhala');
    expect(find.text('ශ්‍රී ලංකාව ගවේෂණය කරන්න'), findsOneWidget);
    expect(find.text('Language preference updated'), findsOneWidget);
    await tapText(tester, 'Tamil');
    expect(find.text('இலங்கையை ஆராயுங்கள்'), findsOneWidget);
    final service = LanguageScope.of(
      tester.element(find.byType(LanguageSelectionScreen)),
    );
    expect(service.selectedLanguageCode, 'ta');
  });
  testWidgets(
    'Profile language selection persists after leaving and returning',
    (tester) async {
      await launch(tester, AppRoutes.profile);
      await tapText(tester, 'Language');
      await tapText(tester, 'Tamil');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Language');
      expect(
        tester
            .widgetList<LanguageOptionCard>(find.byType(LanguageOptionCard))
            .where((card) => card.selected)
            .single
            .language
            .code,
        'ta',
      );
    },
  );
  testWidgets('Help renders sections and accurate expandable FAQ', (
    tester,
  ) async {
    await launch(tester, AppRoutes.helpSupport);
    expect(find.text('How can we help you?'), findsOneWidget);
    expect(find.byType(FaqTile), findsNWidgets(9));
    await tapText(tester, 'How does navigation work?');
    expect(
      find.textContaining('Navigation currently shows demo route'),
      findsOneWidget,
    );
    expect(find.text('My Support Requests'), findsOneWidget);
  });
  testWidgets(
    'FAQ search finds answers case insensitively and shows no matches',
    (tester) async {
      await launch(tester, AppRoutes.helpSupport);
      await tester.enterText(find.byType(TextField).first, 'GPS');
      await tester.pumpAndSettle();
      expect(find.byType(FaqTile), findsOneWidget);
      expect(find.text('How does navigation work?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'no-matching-topic');
      await tester.pumpAndSettle();
      expect(find.text('No help topics found'), findsOneWidget);
    },
  );
  testWidgets('FAQ categories combine with search and All restores topics', (
    tester,
  ) async {
    await launch(tester, AppRoutes.helpSupport);
    await press(tester, find.widgetWithText(FilterChip, 'Group Tours'));
    expect(find.byType(FaqTile), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'join');
    await tester.pumpAndSettle();
    expect(find.byType(FaqTile), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await press(tester, find.widgetWithText(FilterChip, 'All'));
    expect(find.byType(FaqTile), findsNWidgets(9));
  });
  testWidgets(
    'Support form validates then creates and displays actual request',
    (tester) async {
      await launch(tester, AppRoutes.helpSupport);
      await tapText(tester, 'Contact Support');
      await tapText(tester, 'Submit Request');
      expect(find.text('Category is required'), findsOneWidget);
      expect(find.text('Subject is required'), findsOneWidget);
      expect(find.text('Message is required'), findsOneWidget);
      await chooseCategory(tester, 'Technical');
      await tester.enterText(field('Subject'), 'New request');
      await tester.enterText(field('Message'), 'My local message');
      await tapText(tester, 'Submit Request');
      expect(find.text('Support request submitted'), findsOneWidget);
      expect(find.text('New request'), findsOneWidget);
      expect(find.text('My local message'), findsOneWidget);
      expect(
        support(tester).getSupportRequests().single.category,
        SupportCategory.technical,
      );
    },
  );
  testWidgets('Support editing prefills and updates all fields', (
    tester,
  ) async {
    await seed(tester);
    await tapText(tester, 'Edit');
    expect(
      tester.widget<TextFormField>(field('Subject')).controller!.text,
      'My question',
    );
    expect(
      tester.widget<TextFormField>(field('Message')).controller!.text,
      'Please explain tour planning',
    );
    await chooseCategory(tester, 'Account');
    await tester.enterText(field('Subject'), 'Changed question');
    await tester.enterText(field('Message'), 'Changed message');
    await tapText(tester, 'Save Changes');
    final request = support(tester).getSupportRequests().single;
    expect(request.subject, 'Changed question');
    expect(request.message, 'Changed message');
    expect(request.category, SupportCategory.account);
    expect(find.text('Changed question'), findsOneWidget);
  });
  testWidgets('Support status resolves and reopens in service', (tester) async {
    await seed(tester);
    await tapText(tester, 'Mark Resolved');
    expect(
      support(tester).getSupportRequests().single.status,
      SupportStatus.resolved,
    );
    expect(find.text('Resolved'), findsOneWidget);
    await tapText(tester, 'Reopen');
    expect(
      support(tester).getSupportRequests().single.status,
      SupportStatus.open,
    );
    expect(find.text('Open'), findsOneWidget);
  });
  testWidgets(
    'Support delete cancellation preserves record and confirmation removes it',
    (tester) async {
      await seed(tester);
      await tapText(tester, 'Delete');
      expect(find.text('Delete Support Request?'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(support(tester).getSupportRequests(), hasLength(1));
      await tapText(tester, 'Delete');
      await press(tester, find.widgetWithText(TextButton, 'Delete').last);
      expect(support(tester).getSupportRequests(), isEmpty);
      expect(find.byType(SupportRequestCard), findsNothing);
    },
  );
  testWidgets(
    'Requests persist across navigation and help reuses emergency route',
    (tester) async {
      await launch(tester, AppRoutes.profile);
      await tapText(tester, 'Help & Support');
      support(tester).createSupportRequest(
        subject: 'Session question',
        message: 'Message',
        category: SupportCategory.general,
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Help & Support');
      expect(find.text('Session question'), findsOneWidget);
      await tapText(tester, 'Open Emergency Support');
      expect(find.byType(EmergencySupportScreen), findsOneWidget);
    },
  );
  testWidgets(
    'About contains official logo and accurate project and data content',
    (tester) async {
      await launch(tester, AppRoutes.about);
      expect(find.text('About HeritageWalk'), findsOneWidget);
      expect(find.text('HeritageWalk Sri Lanka'), findsOneWidget);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        images.any(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName == AppAssets.logo,
        ),
        isTrue,
      );
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.text('Academic Project'), findsOneWidget);
      expect(find.text('Data Notice'), findsOneWidget);
    },
  );
  for (final entry in {
    'Help & Support': AppRoutes.helpSupport,
    'Language': AppRoutes.language,
  }.entries) {
    testWidgets('About opens ${entry.key}', (tester) async {
      await launch(tester, AppRoutes.about);
      await tapText(tester, entry.key);
      expect(
        find.byType(
          entry.value == AppRoutes.language
              ? LanguageSelectionScreen
              : HelpSupportScreen,
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('About Back to Home opens existing Home', (tester) async {
    await launch(tester, AppRoutes.about);
    await tapText(tester, 'Back to Home');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets('Profile opens About and retains Group Tours navigation', (
    tester,
  ) async {
    await launch(tester, AppRoutes.profile);
    await tapText(tester, 'About');
    expect(find.byType(AboutScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Group Tours');
    expect(find.byType(GroupTourScreen), findsOneWidget);
  });
  testWidgets('Logout clears support requests and keeps session language', (
    tester,
  ) async {
    await launch(tester, AppRoutes.profile);
    final context = tester.element(find.text('My Profile'));
    final requests = SupportScope.of(context);
    final languages = LanguageScope.of(context)..setLanguage('ta');
    requests.createSupportRequest(
      subject: 'Clear on logout',
      message: 'Message',
      category: SupportCategory.general,
    );
    await tapText(tester, 'Logout');
    await tapText(tester, 'Sign Out');
    expect(requests.getSupportRequests(), isEmpty);
    expect(languages.selectedLanguageCode, 'ta');
  });
  testWidgets(
    'Part 6 layouts and keyboard form fit narrow phones with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await launch(tester, AppRoutes.language);
      await tapText(tester, 'Tamil');
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(LanguageSelectionScreen));
      Navigator.pushNamed(context, AppRoutes.about);
      await tester.pumpAndSettle();
      await tapText(tester, 'Help & Support');
      await tapText(tester, 'Contact Support');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.enterText(field('Subject'), 'Compact request');
      await tapText(tester, 'Submit Request');
      expect(find.text('Message is required'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    },
  );
}
