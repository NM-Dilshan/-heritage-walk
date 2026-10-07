import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/core/constants/app_assets.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/backend_error.dart';
import 'package:heritage_walk/core/routes/app_routes.dart';
import 'package:heritage_walk/features/admin/services/place_image_catalog.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/admin/services/place_validation.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/discovery_planning/widgets/place_card.dart';
import 'package:heritage_walk/features/navigation_guide/models/emergency_contact.dart';
import 'package:heritage_walk/features/navigation_guide/services/emergency_repository.dart';
import 'package:heritage_walk/features/navigation_guide/services/phone_launcher.dart';
import 'package:heritage_walk/main.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';

import 'support/part7_fakes.dart';
import 'support/part81_fakes.dart';

final place = DiscoveryService.localPlaces.first;
Future<AppServices> services({
  bool admin = true,
  EmergencyRepository? contacts,
  PlaceRepository? places,
  FakePhone? phone,
  FakeLiveRoles? roles,
}) async {
  final account = FakeAccount();
  await account.register('Test User', 'test@example.com', 'Secure123');
  final current = account.profiles[account.current]!;
  account.profiles[current.id] = UserProfile.fromMap({
    ...current.toMap(),
    'role': admin ? 'admin' : 'user',
  });
  final app = AppServices(
    account: account,
    places: places ?? InMemoryPlaceRepository([place]),
    roles: roles,
    emergencyContacts: contacts ?? InMemoryEmergencyRepository(),
    phone: phone ?? FakePhone(),
  );
  await app.profile.ready;
  await Future<void>.value();
  await Future<void>.value();
  return app;
}

Future<void> mount(WidgetTester tester, AppServices app, String route) async {
  await tester.pumpWidget(HeritageWalkApp(services: app, initialRoute: route));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

EmergencyContact contactWith(Map<String, Object?> fields) =>
    EmergencyContact.fromMap({...testContact.toMap(), ...fields});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  packagedImageTests();
  test('EmergencyContact round trips schema with Timestamp DateTime and ISO audit values', () {
    final date = DateTime.utc(2026, 10, 5);
    for (final value in [
      date,
      Timestamp.fromDate(date),
      date.toIso8601String(),
    ]) {
      final contact = contactWith({
        'createdAt': value,
        'updatedAt': value,
        'createdBy': 'a',
        'updatedBy': 'b',
      });
      expect(contact.createdAt, date);
      expect(contact.updatedAt, date);
      expect(
        EmergencyContact.fromMap(contact.toMap()).toMap(),
        contact.toMap(),
      );
    }
  });
  test('Malformed contact flags never imply active or verified', () {
    final contact = EmergencyContact.fromMap({
      'isActive': 'true',
      'isVerified': 1,
      'phoneNumber': {},
      'priority': double.nan,
      'createdAt': [],
    });
    expect(contact.isActive, false);
    expect(contact.isVerified, false);
    expect(contact.phoneNumber, null);
    expect(contact.priority, 100);
    expect(contact.createdAt, null);
    expect(EmergencyContact.fromMap({'priority': 1.5}).priority, 100);
  });
  test('Phone normalizes display punctuation and short codes without URI injection', () {
    expect(
      EmergencyValidation.normalizedPhone('+1 (202) 555-0123'),
      '+12025550123',
    );
    expect(EmergencyValidation.normalizedPhone('123'), '123');
    for (final value in [
      '',
      '1',
      '+',
      'tel:123',
      '123;456',
      '123#',
      '123*',
      'abc',
      '1234567890123456',
    ]) {
      expect(EmergencyValidation.phone(value), isNotNull);
    }
  });
  test('Contact required values and priority validate boundaries', () {
    expect(EmergencyValidation.requiredText(' '), isNotNull);
    for (final value in ['0', '999', '100']) {
      expect(EmergencyValidation.priority(value), null);
    }
    for (final value in ['-1', '1000', '1.5', 'NaN', '']) {
      expect(EmergencyValidation.priority(value), isNotNull);
    }
  });
  test('Emergency repository create is duplicate safe and audited', () async {
    final repo = InMemoryEmergencyRepository();
    addTearDown(repo.dispose);
    expect(await repo.create(testContact, 'admin'), true);
    expect(await repo.create(testContact, 'admin'), false);
    final contact = (await repo.list()).single;
    expect(contact.createdBy, 'admin');
    expect(contact.createdAt, isNotNull);
  });
  test(
    'Emergency repository edit preserves creator and creation time',
    () async {
      final repo = InMemoryEmergencyRepository();
      addTearDown(repo.dispose);
      await repo.create(testContact, 'first');
      final before = (await repo.list()).single;
      await repo.update(contactWith({'name': 'Updated'}), 'second');
      final after = (await repo.list()).single;
      expect(after.name, 'Updated');
      expect(after.createdAt, before.createdAt);
      expect(after.createdBy, 'first');
      expect(after.updatedBy, 'second');
    },
  );
  test(
    'Emergency repository deletes and rejects missing edits/deletes',
    () async {
      final repo = InMemoryEmergencyRepository([testContact]);
      addTearDown(repo.dispose);
      await repo.delete(testContact.id);
      expect(await repo.list(publicOnly: false), isEmpty);
      await expectLater(
        repo.delete(testContact.id),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        repo.update(testContact, 'admin'),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test('Public contacts require both active and verified; admin retains all records', () async {
    final repo = InMemoryEmergencyRepository([
      testContact,
      contactWith({'id': 'inactive', 'isActive': false}),
      contactWith({'id': 'unverified', 'isVerified': false}),
    ]);
    addTearDown(repo.dispose);
    expect((await repo.list()).map((c) => c.id), [testContact.id]);
    expect((await repo.list(publicOnly: false)).length, 3);
  });
  test('Contacts sort by priority then name', () async {
    final repo = InMemoryEmergencyRepository([
      contactWith({'id': 'b', 'name': 'B', 'priority': 1}),
      contactWith({'id': 'a', 'name': 'A', 'priority': 1}),
      contactWith({'id': 'c', 'priority': 0}),
    ]);
    addTearDown(repo.dispose);
    expect((await repo.list()).map((c) => c.id), ['c', 'a', 'b']);
  });
  test(
    'Contact watch receives edits and hides unverification immediately',
    () async {
      final repo = InMemoryEmergencyRepository([testContact]);
      addTearDown(repo.dispose);
      final iterator = StreamIterator(repo.watch());
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      expect(iterator.current.length, 1);
      await repo.update(contactWith({'isVerified': false}), 'admin');
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
    },
  );
  test(
    'Normal account cannot create update or delete emergency contacts',
    () async {
      final app = await services(admin: false);
      addTearDown(app.dispose);
      await expectLater(
        app.emergency.save(testContact, create: true),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        app.emergency.save(testContact, create: false),
        throwsA(isA<BackendFailure>()),
      );
      await expectLater(
        app.emergency.delete(testContact.id),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test(
    'Admin contact validation blocks invalid numbers and normalizes valid ones',
    () async {
      final app = await services();
      addTearDown(app.dispose);
      await expectLater(
        app.emergency.save(
          contactWith({'phoneNumber': 'tel:123'}),
          create: true,
        ),
        throwsA(isA<BackendFailure>()),
      );
      await app.emergency.save(
        contactWith({'phoneNumber': '+1 (202) 555-0123'}),
        create: true,
      );
      expect(
        (await app.emergency.repository!.list()).single.phoneNumber,
        '+12025550123',
      );
    },
  );
  test('Admin contact search combines category text and number', () async {
    final app = await services(
      contacts: InMemoryEmergencyRepository([
        testContact,
        contactWith({
          'id': 'medical',
          'name': 'Synthetic Medical',
          'category': 'medical',
        }),
      ]),
    );
    addTearDown(app.dispose);
    expect(
      app.emergency.search(query: 'synthetic', category: 'medical').single.id,
      'medical',
    );
    expect(app.emergency.search(query: '555').length, 2);
    expect(app.emergency.search(category: 'fire'), isEmpty);
  });
  test(
    'Role revocation clears emergency admin data and denies writes',
    () async {
      final roles = FakeLiveRoles('admin');
      addTearDown(roles.changes.close);
      final app = await services(
        roles: roles,
        contacts: InMemoryEmergencyRepository([testContact]),
      );
      addTearDown(app.dispose);
      expect(app.emergency.adminContacts, isNotEmpty);
      roles.set('user');
      await Future<void>.value();
      expect(app.emergency.adminContacts, isEmpty);
      await expectLater(
        app.emergency.delete(testContact.id),
        throwsA(isA<BackendFailure>()),
      );
    },
  );
  test('Contact duplicate submissions are blocked while saving', () async {
    final repo = ControlledEmergency([])..gate = Completer<void>();
    final app = await services(contacts: repo);
    addTearDown(app.dispose);
    addTearDown(repo.dispose);
    final save = app.emergency.save(testContact, create: true);
    await expectLater(
      app.emergency.save(testContact, create: true),
      throwsA(isA<BackendFailure>()),
    );
    expect(repo.createCalls, 1);
    repo.gate!.complete();
    await save;
    expect(app.emergency.busy, false);
  });
  test(
    'Contact failed write clears pending state and leaves catalog unchanged',
    () async {
      final repo = ControlledEmergency([])..failWrite = true;
      final app = await services(contacts: repo);
      addTearDown(app.dispose);
      addTearDown(repo.dispose);
      await expectLater(
        app.emergency.save(testContact, create: true),
        throwsA(isA<BackendFailure>()),
      );
      expect(app.emergency.busy, false);
      expect(await repo.list(), isEmpty);
    },
  );
  test(
    'Dialer receives only sanitized tel URI and never automatically calls',
    () async {
      final phone = FakePhone();
      await dialContact(
        contactWith({'phoneNumber': '+1 (202) 555-0123'}),
        phone,
      );
      expect(phone.uris.single.scheme, 'tel');
      expect(phone.uris.single.path, '+12025550123');
    },
  );
  test('Invalid unverified or inactive contacts never reach dialer', () async {
    final phone = FakePhone();
    for (final contact in [
      contactWith({'isActive': false}),
      contactWith({'isVerified': false}),
      contactWith({'phoneNumber': '123#'}),
    ]) {
      await expectLater(
        dialContact(contact, phone),
        throwsA(isA<BackendFailure>()),
      );
    }
    expect(phone.uris, isEmpty);
  });
  test('No dialer and native failure have friendly messages', () async {
    final phone = FakePhone()..result = false;
    await expectLater(
      dialContact(testContact, phone),
      throwsA(
        isA<BackendFailure>().having(
          (e) => e.message,
          'message',
          contains('No phone dialer'),
        ),
      ),
    );
    phone.throwsError = true;
    await expectLater(
      dialContact(testContact, phone),
      throwsA(
        isA<BackendFailure>().having(
          (e) => e.message,
          'message',
          contains('Unable to open'),
        ),
      ),
    );
  });
  test('Image references distinguish asset HTTPS and invalid URLs', () {
    expect(PlaceImageReferences.isAsset(AppAssets.placePlaceholder), true);
    expect(PlaceImageReferences.isAsset('assets/../secret'), false);
    expect(
      PlaceImageReferences.isRemote(
        'https://firebasestorage.googleapis.com/image',
      ),
      true,
    );
    for (final value in [
      'http://example.com/x',
      'file:///x',
      'https:',
      'https://user:pass@example.com/x',
    ]) {
      expect(PlaceImageReferences.isRemote(value), false);
    }
    expect(PlaceValidation.image('https://example.com/image.jpg'), null);
  });
  for (final route in [
    AppRoutes.adminEmergency,
    AppRoutes.adminEmergencyAdd,
    AppRoutes.adminEmergencyEdit,
  ]) {
    testWidgets('Normal account denied emergency route $route', (tester) async {
      await mount(tester, await services(admin: false), route);
      expect(find.text('Admin access required'), findsOneWidget);
      expect(find.text('Save Contact'), findsNothing);
    });
  }
  testWidgets(
    'Production emergency empty state contains no demo call controls',
    (tester) async {
      await mount(tester, await services(admin: false), AppRoutes.emergency);
      expect(
        find.text('No active verified contacts are available.'),
        findsOneWidget,
      );
      expect(find.text('Call (not connected)'), findsNothing);
    },
  );
  testWidgets('Emergency loading state is visible', (tester) async {
    final repo = ControlledEmergency([])..hold = true;
    await tester.pumpWidget(
      HeritageWalkApp(
        services: await services(admin: false, contacts: repo),
        initialRoute: AppRoutes.emergency,
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('Emergency backend error recovers with reload', (tester) async {
    final repo = ControlledEmergency([])..fail = true;
    await mount(
      tester,
      await services(admin: false, contacts: repo),
      AppRoutes.emergency,
    );
    expect(find.text('Contacts could not be loaded.'), findsOneWidget);
    repo.fail = false;
    await press(tester, 'Reload contacts');
    expect(
      find.text('No active verified contacts are available.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'User emergency list calls injected dialer and reports missing app',
    (tester) async {
      final phone = FakePhone()..result = false;
      await mount(
        tester,
        await services(
          admin: false,
          contacts: InMemoryEmergencyRepository([testContact]),
          phone: phone,
        ),
        AppRoutes.emergency,
      );
      await press(tester, 'Call');
      expect(phone.uris.single.path, testContact.phoneNumber);
      expect(
        find.text('No phone dialer is available on this device.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Admin emergency list displays verification active and priority',
    (tester) async {
      await mount(
        tester,
        await services(
          contacts: InMemoryEmergencyRepository([
            testContact,
            contactWith({
              'id': 'hidden',
              'name': 'Hidden',
              'isVerified': false,
              'isActive': false,
            }),
          ]),
        ),
        AppRoutes.adminEmergency,
      );
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.textContaining('Priority 10'), findsNWidgets(2));
      await press(tester, 'View');
      expect(find.textContaining('Created by:'), findsOneWidget);
    },
  );
  testWidgets(
    'Emergency admin create form validates required fields and priority',
    (tester) async {
      await mount(tester, await services(), AppRoutes.adminEmergencyAdd);
      await press(tester, 'Save Contact');
      expect(find.text('This field is required'), findsNWidgets(3));
      expect(
        find.text('Enter a valid phone number or short code'),
        findsOneWidget,
      );
      final priority = find.widgetWithText(
        TextFormField,
        'Priority (0–999; lower first)',
      );
      await tester.ensureVisible(priority);
      await tester.enterText(priority, '1.5');
      await press(tester, 'Save Contact');
      expect(find.text('Enter a whole number from 0 to 999'), findsOneWidget);
    },
  );
  testWidgets(
    'Emergency delete confirmation can cancel then delete named contact',
    (tester) async {
      final app = await services(
        contacts: InMemoryEmergencyRepository([testContact]),
      );
      await mount(tester, app, AppRoutes.adminEmergency);
      await press(tester, 'Delete');
      expect(find.text('Delete ${testContact.name}?'), findsOneWidget);
      await press(tester, 'Cancel');
      expect(app.emergency.adminContacts.length, 1);
      await press(tester, 'Delete');
      await press(tester, 'Delete');
      expect(app.emergency.adminContacts, isEmpty);
    },
  );
  testWidgets(
    'PlaceImage displays asset and invalid references through placeholder',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceImage(
              place: HeritagePlace.fromMap({
                ...place.toMap(),
                'imagePath': 'http://invalid',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image).first);
      expect((image.image as AssetImage).assetName, AppAssets.placePlaceholder);
      expect(tester.takeException(), null);
    },
  );
  testWidgets('Remote image failure falls back without breaking layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceImage(
            place: HeritagePlace.fromMap({
              ...place.toMap(),
              'imagePath': 'https://example.com/missing.jpg',
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(find.byType(Image), findsWidgets);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any((image) => image.image is AssetImage),
      true,
    );
  });

  testWidgets(
    'Admin emergency form creates unverified contact then edits verification',
    (tester) async {
      final app = await services();
      await mount(tester, app, AppRoutes.adminEmergency);
      await press(tester, 'Add Contact');
      for (final entry in {
        'Service Name': 'Synthetic Contact',
        'Phone Number': '+12025550123',
        'Description': 'Synthetic fixture only',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('other').last);
      await tester.pumpAndSettle();
      await press(tester, 'Save Contact');
      expect(app.emergency.adminContacts.single.isVerified, false);
      expect(app.emergency.contacts, isEmpty);
      await press(tester, 'Edit');
      expect(
        find.widgetWithText(TextFormField, 'Synthetic Contact'),
        findsOneWidget,
      );
      final verified = find.widgetWithText(SwitchListTile, 'Verified');
      await tester.ensureVisible(verified);
      await tester.tap(verified);
      await tester.pumpAndSettle();
      await press(tester, 'Save Contact');
      expect(app.emergency.contacts.single.name, 'Synthetic Contact');
    },
  );

  testWidgets('Emergency form scrolls with large text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, await services(), AppRoutes.adminEmergencyAdd);
    await tester.ensureVisible(find.text('Save Contact'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
}

void packagedImageTests() {
  test('Catalog matches all 17 actual JPG paths without duplicates', () {
    final actual = Directory('assets/places')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .toSet();
    final expected = PlaceImageCatalog.options.map((o) => o.assetPath).toSet();
    expect(PlaceImageCatalog.options, hasLength(17));
    expect(expected, hasLength(17));
    expect(expected, actual);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('    - assets/places/'),
    );
  });
  test('All 17 explicit place mappings resolve without changing records', () {
    for (final option in PlaceImageCatalog.options) {
      expect(
        PlaceImageCatalog.forPlaceName(option.placeNames.first),
        same(option),
      );
      expect(PlaceImageCatalog.forAsset(option.assetPath), same(option));
    }
    expect(PlaceImageCatalog.forPlaceName('Unknown Place'), null);
  });
  test('Runtime dependencies and Firebase configuration do not require Storage or gallery', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, isNot(contains('firebase_storage:')));
    expect(pub, isNot(contains('image_picker:')));
    for (final package in [
      'firebase_core:',
      'firebase_auth:',
      'cloud_firestore:',
      'url_launcher:',
    ]) {
      expect(pub, contains(package));
    }
    final config = jsonDecode(File('firebase.json').readAsStringSync()) as Map;
    expect(config.containsKey('storage'), false);
    expect((config['emulators'] as Map).containsKey('storage'), false);
  });
  for (final option in PlaceImageCatalog.options) {
    testWidgets('Bundled JPG renders: ${option.displayName}', (tester) async {
      final bytes = File(option.assetPath).readAsBytesSync();
      expect(bytes.take(3), [255, 216, 255]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceImage(
              place: HeritagePlace.fromMap({
                ...place.toMap(),
                'imagePath': option.assetPath,
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        option.assetPath,
      );
      expect(tester.takeException(), null);
    });
  }
  test('Create persists the selected asset reference and stable ID', () async {
    final repo = InMemoryPlaceRepository();
    final app = await services(places: repo);
    addTearDown(app.dispose);
    addTearDown(repo.dispose);
    final selected = HeritagePlace.fromMap({
      ...place.toMap(),
      'id': repo.newId(),
      'imagePath': PlaceImageCatalog.options[2].assetPath,
    });
    await app.catalog.save(selected, create: true);
    final saved = (await repo.list()).single;
    expect(saved.id, selected.id);
    expect(saved.imagePath, 'assets/places/galle_fort_and_old_town.jpg');
    expect(HeritagePlace.fromMap(saved.toMap()).imagePath, saved.imagePath);
    expect(saved.toMap().containsKey('imageStoragePath'), false);
  });
  test('Edit changes asset reference and preserves creation audit', () async {
    final repo = InMemoryPlaceRepository();
    await repo.create(place, 'original-admin');
    final before = (await repo.list()).single;
    final app = await services(places: repo);
    addTearDown(app.dispose);
    addTearDown(repo.dispose);
    await app.catalog.save(
      HeritagePlace.fromMap({
        ...before.toMap(),
        'imagePath': PlaceImageCatalog.options.first.assetPath,
      }),
      create: false,
    );
    final saved = (await repo.list()).single;
    expect(saved.imagePath, PlaceImageCatalog.options.first.assetPath);
    expect(saved.createdBy, 'original-admin');
    expect(saved.createdAt, before.createdAt);
    await Future<void>.delayed(Duration.zero);
    expect(app.discovery.discovery.places.single.imagePath, saved.imagePath);
  });
  test(
    'Startup keeps an administrator-selected image rather than name mapping',
    () async {
      final selected = HeritagePlace.fromMap({
        ...place.toMap(),
        'name': 'Sigiriya Rock Fortress',
        'imagePath': PlaceImageCatalog.options.last.assetPath,
      });
      final repo = InMemoryPlaceRepository([selected]);
      final app = await services(places: repo);
      addTearDown(app.dispose);
      addTearDown(repo.dispose);
      expect((await repo.list()).single.imagePath, selected.imagePath);
      expect(app.catalog.places.single.imagePath, selected.imagePath);
    },
  );
  testWidgets(
    'Selector cancellation preserves current asset and has no raw image field',
    (tester) async {
      await mount(tester, await services(), AppRoutes.adminPlaces);
      await press(tester, 'Edit');
      expect(
        find.widgetWithText(TextFormField, 'Image reference (asset or HTTPS)'),
        findsNothing,
      );
      await press(tester, 'Choose Place Image');
      expect(find.byType(GridView), findsOneWidget);
      await press(tester, 'Cancel');
      expect(find.byType(AlertDialog), findsNothing);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        images.any(
          (i) =>
              i.image is AssetImage &&
              (i.image as AssetImage).assetName == place.imagePath,
        ),
        true,
      );
    },
  );
  testWidgets(
    'Selector confirms selected state preview and saves edited asset',
    (tester) async {
      final repo = InMemoryPlaceRepository([place]);
      final app = await services(places: repo);
      await mount(tester, app, AppRoutes.adminPlaces);
      await press(tester, 'Edit');
      await press(tester, 'Choose Place Image');
      final option = PlaceImageCatalog.options.first;
      await tester.tap(find.byKey(ValueKey(option.assetPath)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await press(tester, 'Use Image');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any(
              (i) =>
                  i.image is AssetImage &&
                  (i.image as AssetImage).assetName == option.assetPath,
            ),
        true,
      );
      await press(tester, 'Save Place');
      expect((await repo.list()).single.imagePath, option.assetPath);
      expect(find.text('Manage Historical Places'), findsOneWidget);
    },
  );
  testWidgets('Add place form stores a selected packaged image', (
    tester,
  ) async {
    final repo = InMemoryPlaceRepository();
    await mount(tester, await services(places: repo), AppRoutes.adminPlaces);
    await press(tester, 'Add Place');
    await tester.tap(find.byKey(const ValueKey('place-category-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forts').last);
    await tester.pumpAndSettle();
    await press(tester, 'Choose Place Image');
    await tester.tap(
      find.byKey(ValueKey(PlaceImageCatalog.options[2].assetPath)),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Use Image');
    for (final entry in {
      'Name *': 'New Fort',
      'Description *': 'Historical fort description',
      'City *': 'Galle',
      'District *': 'Galle',
    }.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await press(tester, 'Save Place');
    expect(
      (await repo.list()).single.imagePath,
      PlaceImageCatalog.options[2].assetPath,
    );
  });
  testWidgets(
    'Selector scrolls to last image on a narrow phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, await services(), AppRoutes.adminPlaces);
      await press(tester, 'Edit');
      await press(tester, 'Choose Place Image');
      final last = find.byKey(
        ValueKey(PlaceImageCatalog.options.last.assetPath),
      );
      await tester.scrollUntilVisible(
        last,
        180,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 30,
      );
      await Scrollable.ensureVisible(last.evaluate().single, alignment: 1);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.takeException(), null);
      await press(tester, 'Use Image');
    },
  );
}
