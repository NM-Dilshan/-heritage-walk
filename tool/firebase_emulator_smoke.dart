// Run only via run_firebase_smoke.ps1 with local Firebase emulators.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:heritage_walk/firebase_options.dart';
import 'package:heritage_walk/core/firebase/app_services.dart';
import 'package:heritage_walk/core/firebase/account_repository.dart';
import 'package:heritage_walk/core/firebase/firestore_repository.dart';
import 'package:heritage_walk/features/discovery_planning/models/itinerary.dart';
import 'package:heritage_walk/features/group_support/models/support_request.dart';

void must(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Part 7 local SDK smoke running')),
      ),
    ),
  );
  try {
    final android = DefaultFirebaseOptions.android;
    final app = await Firebase.initializeApp(
      name: 'part7-emulator',
      options: FirebaseOptions(
        apiKey: android.apiKey,
        appId: android.appId,
        messagingSenderId: android.messagingSenderId,
        projectId: 'demo-heritagewalk',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    await auth.useAuthEmulator('10.0.2.2', 9099);
    db.settings = const Settings(persistenceEnabled: false);
    db.useFirestoreEmulator('10.0.2.2', 8080);
    final services = AppServices(
      account: FirebaseAccountRepository(auth, db),
      data: FirestoreRepository(db),
    );
    await services.profile.ready;
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final emailA = 'sdk-a-$suffix@heritagewalk.test',
        emailB = 'sdk-b-$suffix@heritagewalk.test';
    const password = 'LocalSmoke123!';
    await services.profile.register(
      fullName: 'SDK Alice',
      email: emailA,
      password: password,
    );
    final uidA = services.profile.profile.id;
    await services.profile.update(
      services.profile.profile.copyWith(
        fullName: 'Updated Alice',
        bio: 'Persisted',
      ),
    );
    Future<void> saved() async {
      await services.sync!.flush();
      must(services.sync!.error == null, 'Cloud sync: ${services.sync!.error}');
    }

    final place = services.discovery.discovery.places.first;
    services.discovery.favorites.addFavorite(place);
    await saved();
    final itinerary = services.discovery.itineraries.generate(
      TourPlan(
        destination: 'Kandy',
        date: DateTime.now().add(const Duration(days: 3)),
        duration: '1 Day',
        interests: ['History'],
        travelStyle: 'Balanced',
      ),
    );
    services.discovery.itineraries.save(itinerary.id);
    await saved();
    services.discovery.itineraries.rename(itinerary.id, 'SDK persisted trip');
    await saved();
    final note = services.navigation.notes.add(place.id, 'SDK note');
    await saved();
    services.navigation.notes.update(note.id, 'SDK edited note');
    await saved();
    final support = services.support.createSupportRequest(
      subject: 'SDK request',
      message: 'Academic record',
      category: SupportCategory.general,
    );
    await saved();
    services.support.markResolved(support.id);
    await saved();
    services.language.setLanguage('ta');
    await saved();
    final group = services.groups.createGroup('SDK group', place);
    await saved();
    services.groups.renameGroup(group.id, 'SDK renamed group');
    await saved();
    final demo = services.groups.addMember(group.id, 'Explicit demo member');
    await saved();
    services.groups.removeMember(group.id, demo.id);
    await saved();
    services.groups.toggleMemberLocationSharing(group.id, uidA, true);
    await saved();
    await services.profile.signOut();
    must(
      services.discovery.favorites.getFavorites().isEmpty,
      'Logout cache clear',
    );
    await services.profile.signIn(emailA, password: password);
    must(
      services.profile.profile.fullName == 'Updated Alice',
      'Profile restore',
    );
    must(services.discovery.favorites.isFavorite(place.id), 'Favorite restore');
    must(
      services.discovery.itineraries.find(itinerary.id)?.title ==
          'SDK persisted trip',
      'Itinerary restore',
    );
    must(
      services.navigation.notes.forPlace(place.id).single.text ==
          'SDK edited note',
      'Note restore',
    );
    must(
      services.support.getById(support.id)?.status == SupportStatus.resolved,
      'Support restore',
    );
    must(services.language.selectedLanguageCode == 'ta', 'Language restore');
    must(
      services.groups.getGroupById(group.id)?.name == 'SDK renamed group',
      'Group restore',
    );
    // Destroy all view models and create fresh ones with the same persisted Auth.
    services.dispose();
    final restored = AppServices(
      account: FirebaseAccountRepository(auth, db),
      data: FirestoreRepository(db),
    );
    await restored.profile.ready;
    must(
      restored.profile.isAuthenticated &&
          restored.discovery.favorites.isFavorite(place.id),
      'Fresh app state restore',
    );
    await restored.profile.signOut();
    await restored.profile.register(
      fullName: 'SDK Bob',
      email: emailB,
      password: password,
    );
    must(
      restored.discovery.favorites.getFavorites().isEmpty &&
          restored.navigation.notes.allNotes.isEmpty &&
          restored.support.getSupportRequests().isEmpty,
      'User B private isolation',
    );
    must(
      restored.language.selectedLanguageCode == 'en' &&
          restored.groups.getGroups().isEmpty,
      'User B default language/groups',
    );
    await restored.groups.join(group.inviteCode);
    await restored.groups.join(group.inviteCode);
    must(
      restored.groups
              .getGroupById(group.id)!
              .members
              .where((member) => member.id == restored.profile.profile.id)
              .length ==
          1,
      'UID deduplication',
    );
    restored.groups.toggleMemberLocationSharing(
      group.id,
      restored.profile.profile.id,
      true,
    );
    await restored.sync!.flush();
    must(restored.sync!.error == null, 'Member sharing persisted');
    await restored.profile.signOut();
    await restored.profile.signIn(emailA, password: password);
    must(
      restored.groups.getGroupById(group.id)!.members.length == 2,
      'Joined member restored to leader',
    );
    restored.groups.deleteGroup(group.id);
    await restored.sync!.flush();
    must(
      restored.sync!.error == null && restored.groups.getGroups().isEmpty,
      'Cloud group delete',
    );
    await restored.profile.signOut();
    restored.dispose();
    debugPrint(
      'PART7_SDK_SMOKE_PASS: auth, every persisted feature, fresh app restore, group joins and user isolation',
    );
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('PART7_SDK_SMOKE_PASS'))),
      ),
    );
  } catch (error, stack) {
    debugPrint('PART7_SDK_SMOKE_FAIL: $error\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('PART7_SDK_SMOKE_FAIL: $error')),
        ),
      ),
    );
  }
}
