import 'dart:math';

import '../../features/reviews/services/review_repository.dart';
import '../../features/reviews/services/review_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth_profile/services/profile_service.dart';
import '../../features/discovery_planning/services/discovery_scope.dart';
import '../../features/discovery_planning/models/itinerary.dart';
import '../../features/navigation_guide/services/navigation_guide_scope.dart';
import '../../features/navigation_guide/models/guide_note.dart';
import '../../features/group_support/services/group_tour_service.dart';
import '../../features/group_support/services/language_service.dart';
import '../../features/group_support/services/support_service.dart';
import '../../features/group_support/models/support_request.dart';
import '../../features/group_support/models/tour_group.dart';
import 'account_repository.dart';
import 'data_repository.dart';
import 'firestore_repository.dart';
import 'sync_controller.dart';
import 'cloud_values.dart';
import '../../features/admin/services/place_repository.dart';
import '../../features/admin/services/catalog_controller.dart';
import '../../features/navigation_guide/services/emergency_repository.dart';
import '../../features/navigation_guide/services/emergency_controller.dart';
import '../../features/navigation_guide/services/phone_launcher.dart';

class AppServices {
  AppServices({
    AccountRepository? account,
    DataRepository? data,
    PlaceRepository? places,
    RoleRepository? roles,
    EmergencyRepository? emergencyContacts,
    PhoneLauncher? phone,
    ReviewRepository? reviews,
  }) {
    profile = ProfileService(repository: account);
    catalog = CatalogController(
      profile,
      discovery,
      repository: places,
      roles: roles,
    );
    emergency = EmergencyController(
      catalog,
      repository: emergencyContacts,
      phone: phone,
    );
    this.reviews = ReviewController(
      catalog,
      reviews ?? InMemoryReviewRepository(),
      ownsRepository: reviews == null,
    );
    groups = GroupTourService(profile);
    if (data != null) {
      sync = SyncController(data, [
        CollectionBinding(
          'favorites',
          discovery.favorites,
          () => {
            for (final place in discovery.favorites.getFavorites())
              place.id: {'placeId': place.id},
          },
          (documents) => discovery.favorites.restoreIds(
            documents.keys,
            discovery.discovery.places,
          ),
        ),
        CollectionBinding(
          'itineraries',
          discovery.itineraries,
          () => {
            for (final item in discovery.itineraries.savedItineraries)
              item.id: item.toMap(),
          },
          (documents) => discovery.itineraries.restore(
            documents.values.map(
              (data) => Itinerary.fromMap({...data, 'isSaved': true}),
            ),
          ),
        ),
        CollectionBinding(
          'guideNotes',
          navigation.notes,
          () => {
            for (final note in navigation.notes.allNotes) note.id: note.toMap(),
          },
          (documents) =>
              navigation.notes.restore(documents.values.map(GuideNote.fromMap)),
        ),
        CollectionBinding(
          'supportRequests',
          support,
          () => {
            for (final request in support.getSupportRequests())
              request.id: request.toMap(),
          },
          (documents) =>
              support.restore(documents.values.map(SupportRequest.fromMap)),
        ),
        CollectionBinding(
          'preferences',
          language,
          () => {
            'settings': {'selectedLanguageCode': language.selectedLanguageCode},
          },
          (documents) {
            final code = CloudValues.text(
              documents['settings']?['selectedLanguageCode'],
              'en',
            );
            language.setLanguage(
              ['en', 'si', 'ta'].contains(code) ? code : 'en',
            );
          },
        ),
        CollectionBinding('groups', groups, _groupDocuments, (documents) {
          final previous = {
            for (final group in groups.getGroups()) group.id: group,
          };
          groups.restore(
            documents.values.map((data) {
              final group = TourGroup.fromMap(data);
              return group.copyWith(
                members: group.members.map((member) {
                  final old = previous[group.id]?.members
                      .where((item) => item.id == member.id)
                      .firstOrNull;
                  return member.copyWith(
                    relativeX:
                        old?.relativeX ??
                        .2 + (member.id.hashCode.abs() % 5) * .12,
                    relativeY:
                        old?.relativeY ??
                        .3 + (member.id.hashCode.abs() % 3) * .14,
                    lastUpdated: old?.lastUpdated ?? DateTime.now(),
                  );
                }).toList(),
              );
            }),
          );
        }),
      ], clearLocal);
      profile.onSession = (uid) async {
        if (uid == null) {
          sync!.stop();
          clearLocal();
        } else {
          await sync!.start(uid);
        }
      };
      groups.idFactory = data.newId;
      groups.inviteFactory = newInviteCode;
      groups.cloudJoin = (code, user) => sync!.operation(() async {
        final group = await data.join(code, user);
        if (group != null) {
          final binding = sync!.bindings.singleWhere(
            (binding) => binding.name == 'groups',
          );
          binding.accept(await data.load(user.id, 'groups'));
        }
        return group;
      });
      support.idFactory = data.newId;
    }
    profile.initialize();
  }
  factory AppServices.firebase() => AppServices(
    account: FirebaseAccountRepository(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    ),
    data: FirestoreRepository(FirebaseFirestore.instance),
    places: FirestorePlaceRepository(FirebaseFirestore.instance),
    roles: FirestoreRoleRepository(FirebaseFirestore.instance),
    emergencyContacts: FirestoreEmergencyRepository(FirebaseFirestore.instance),
    phone: DevicePhoneLauncher(),
    reviews: FirestoreReviewRepository(FirebaseFirestore.instance),
  );
  late final ProfileService profile;
  late final CatalogController catalog;
  late final EmergencyController emergency;
  late final ReviewController reviews;
  late final GroupTourService groups;
  final discovery = DiscoveryState();
  final navigation = NavigationGuideState();
  final language = LanguageService();
  final support = SupportService();
  SyncController? sync;
  static String newInviteCode() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return 'HW-${List.generate(16, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
  }

  CloudDocuments _groupDocuments() => {
    for (final group in groups.getGroups())
      group.id: {
        ...group.toMap(),
        'members': [
          for (final member in group.members)
            {
              ...member.toMap()
                ..remove('relativeX')
                ..remove('relativeY')
                ..remove('lastUpdated')
                ..remove('isOnline'),
            },
        ],
      },
  };
  void clearLocal() {
    discovery.clearSession();
    navigation.clearSession();
    groups.clear();
    support.clear();
    language.setLanguage('en');
  }

  void dispose() {
    reviews.dispose();
    emergency.dispose();
    catalog.dispose();
    sync?.dispose();
    groups.dispose();
    profile.dispose();
    discovery.dispose();
    navigation.dispose();
    language.dispose();
    support.dispose();
  }
}
