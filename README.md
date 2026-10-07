# HeritageWalk Sri Lanka

Parts 1–9.2: Android Flutter foundation, Material 3 theme, existing assets,
reusable widgets, account/profile, discovery/planning, navigation/guide,
group tours, language preferences, local support requests and About.

## Module ownership

| Module | Student | Student ID | Responsibility |
| --- | --- | --- | --- |
| auth_profile | W A N M Dilshan | IT23839410 | Account Authentication & Profile Management |
| discovery_planning | A B K S I Sithuruwan | IT23839038 | Tour Discovery, Planning & Saved Content |
| navigation_guide | N M S H Premarathna | IT23825550 | Navigation, Digital Guide, Facilities & Safety |
| group_support | R D I H Rajapaksha | IT23841772 | Group Tour, Language & Support Features |

Production uses Firebase Email/Password Auth and user-scoped Firestore persistence.
Part 9.2 adds secure password reset and Google/Facebook credential flows through Firebase.
Facebook requires real Meta/Firebase configuration before physical login; see the setup report below.
Tests and foundation previews keep isolated in-memory services. Admin place images
use a selector for 17 packaged photos. Part 9 adds OpenStreetMap maps, actual device GPS,
FOSSGIS/OSRM route geometry and metrics, opt-in foreground group location sharing,
and English/Sinhala/Tamil application localization. Production discovery uses the Firestore historical-place catalog.
Deploy the Part 8 rules, bootstrap the intended admin in Firebase Console, then explicitly seed the original catalog.
Startup: Splash -> restored Home or Login/Register -> Home. Production uses Firebase;
the default injected-free widget test harness retains the memory demo behavior.
See [Part 2 CRUD documentation](docs/part2_auth_profile_crud.md) and [Part 3 CRUD documentation](docs/part3_discovery_planning_crud.md) and [Part 4 CRUD documentation](docs/part4_navigation_guide_crud.md) and [Part 5 CRUD documentation](docs/part5_group_tour_crud.md).
FoundationPreviewScreen is preserved at the development route '/'.
See [Part 6 language, support and About documentation](docs/part6_language_support_about.md).
See [Part 7 Firebase architecture, rules deployment and verification](docs/part7_firebase_integration.md).
See [Part 8 admin, catalog CRUD, bootstrap, seed and manual checklist](docs/part8_admin_place_management.md).
See [Part 8.1 emergency contacts, packaged-image selector, rules and verification](docs/part8_1_emergency_and_images.md).

See [Part 8.2 Home/Explore separation, real reviews, moderation and verification](docs/part8_2_home_explore_reviews.md).
See [Part 9 maps, GPS, group privacy, localization and device checklist](docs/part9_maps_gps_groups_localization.md).
See [Part 9.1 real nearby facilities, Overpass limits and verification](docs/part9_1_nearby_facilities.md).
See [Part 9.2 authentication upgrade, Google/Meta configuration and verification](docs/part9_2_authentication_upgrade.md).

## Run

From this project directory with an Android emulator or device connected:

```powershell
flutter pub get
flutter run
```

Validate with `flutter analyze` and `flutter test`.
Build an APK later with `flutter build apk` (requires configured Android SDK).
The Android launcher icon remains the generated Flutter default; the preview
uses the official existing logo. All asset constants use relative paths.

