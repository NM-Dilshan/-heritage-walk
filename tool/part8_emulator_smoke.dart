// Development-only Android SDK verification. Never uses the production project.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:heritage_walk/core/firebase/account_repository.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/firestore_repository.dart';
import 'package:heritage_walk/features/admin/services/place_repository.dart';
import 'package:heritage_walk/features/discovery_planning/models/itinerary.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/firebase_options.dart';

void must(bool value, String label) {
  if (!value) throw StateError(label);
}

Future<void> until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Timed out waiting for live catalog/role update');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Part 8 local SDK smoke'))),
    ),
  );
  try {
    const project = 'demo-heritagewalk';
    final android = DefaultFirebaseOptions.android;
    final firebase = await Firebase.initializeApp(
      name: 'part8-emulator',
      options: FirebaseOptions(
        apiKey: android.apiKey,
        appId: android.appId,
        messagingSenderId: android.messagingSenderId,
        projectId: project,
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: firebase);
    debugPrint('PART8_STEP: Firebase app initialized');
    final db = FirebaseFirestore.instanceFor(app: firebase);
    await auth.useAuthEmulator('10.0.2.2', 9099);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator('10.0.2.2', 8080);
    await auth
        .signOut(); // Discard credentials from an earlier emulator process.
    debugPrint('PART8_STEP: local endpoints configured');
    AppServices createServices() => AppServices(
      account: FirebaseAccountRepository(auth, db),
      data: FirestoreRepository(db),
      places: FirestorePlaceRepository(db),
      roles: FirestoreRoleRepository(db),
    );
    var services = createServices();
    await services.profile.ready;
    debugPrint('PART8_STEP: clean auth restored');
    final email =
        'part8-${DateTime.now().microsecondsSinceEpoch}@heritagewalk.test';
    await services.profile.register(
      fullName: 'Catalog Admin',
      email: email,
      password: 'LocalSmoke123!',
    );
    debugPrint('PART8_STEP: registration complete');
    final uid = services.profile.profile.id;
    must(
      (await db.collection('users').doc(uid).get()).data()?['role'] == 'user',
      'Registration default role',
    );
    // This owner token is recognized ONLY by the local emulator; trusted bootstrap fixture.
    final client = HttpClient();
    final request = await client.patchUrl(
      Uri.parse(
        'http://10.0.2.2:8080/v1/projects/$project/databases/(default)/documents/users/$uid?updateMask.fieldPaths=role',
      ),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'fields': {
          'role': {'stringValue': 'admin'},
        },
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    client.close();
    must(response.statusCode == 200, 'Trusted emulator bootstrap');
    await until(() => services.catalog.isAdmin);
    debugPrint('PART8_STEP: server admin role confirmed');
    final first = await services.catalog.seed();
    debugPrint('PART8_STEP: first seed complete');
    must(first.created == 8 && first.skipped == 0, 'First seed');
    final repeat = await services.catalog.seed();
    must(repeat.created == 0 && repeat.skipped == 8, 'Idempotent seed');
    await until(() => services.discovery.discovery.places.length == 8);
    final repo = services.catalog.repository!;
    final template = DiscoveryService.localPlaces.first;
    final place = template.copyWith(name: 'SDK Catalog Test');
    await services.catalog.save(place, create: false);
    await until(
      () => services.discovery.discovery.places.any(
        (p) => p.id == place.id && p.name == place.name,
      ),
    );
    final before = (await repo.list()).singleWhere((p) => p.id == place.id);
    must(
      before.createdBy == uid &&
          before.updatedBy == uid &&
          before.createdAt != null,
      'Server audit',
    );
    services.discovery.favorites.addFavorite(before);
    final itinerary = services.discovery.itineraries.generate(
      TourPlan(
        destination: before.city,
        date: DateTime.now(),
        duration: '1 Day',
        interests: ['History'],
        travelStyle: 'Balanced',
      ),
    );
    services.discovery.itineraries.save(itinerary.id);
    await services.sync!.flush();
    must(services.sync!.error == null, 'Saved references');
    await services.profile.update(
      services.profile.profile.copyWith(fullName: 'Edited Admin'),
    );
    must(
      (await db.collection('users').doc(uid).get()).data()?['role'] == 'admin',
      'Profile preserves server role',
    );
    await services.catalog.save(
      before.copyWith(isActive: false),
      create: false,
    );
    await until(
      () => !services.discovery.discovery.places.any((p) => p.id == before.id),
    );
    must(
      (await repo.list(activeOnly: false)).any((p) => p.id == before.id),
      'Admin sees inactive',
    );
    await services.catalog.save(before.copyWith(isActive: true), create: false);
    await until(
      () => services.discovery.discovery.places.any((p) => p.id == before.id),
    );
    await services.catalog.delete(before.id);
    await until(
      () => !services.discovery.discovery.places.any((p) => p.id == before.id),
    );
    await services.sync!.flush();
    must(
      (await db
              .collection('users')
              .doc(uid)
              .collection('favorites')
              .doc(before.id)
              .get())
          .exists,
      'Favorite retained after delete',
    );
    must(
      services.discovery.itineraries.savedItineraries.single.places.any(
        (p) => p.id == before.id,
      ),
      'Saved snapshot retained',
    );
    await services.profile.signOut();
    services.dispose();
    services = createServices();
    await services.profile.ready;
    await services.profile.signIn(email, password: 'LocalSmoke123!');
    await until(
      () =>
          services.catalog.isAdmin &&
          services.discovery.discovery.places.length == 7,
    );
    must(
      services.discovery.favorites.isFavorite(before.id),
      'Missing favorite restored after restart',
    );
    must(
      services.discovery.itineraries.savedItineraries.single.places.any(
        (p) => p.id == before.id,
      ),
      'Itinerary restored after restart',
    );
    services.dispose();
    debugPrint(
      'PART8_SDK_SMOKE_PASS: registration role, trusted bootstrap, seed, live catalog, audit, CRUD, profile role preservation, references and restart',
    );
  } catch (error, stack) {
    debugPrint('PART8_SDK_SMOKE_FAIL: $error\n$stack');
  }
}
