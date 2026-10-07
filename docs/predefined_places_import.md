# Predefined historical-place auto-fill and import

## Single dataset and form behavior

`lib/features/admin/services/predefined_places.dart` contains the single immutable
17-place dataset used by both Add Place and bulk import. Supplied descriptions,
coordinates and visitor guidance were retained; fields map to the existing
HeritagePlace schema (`entranceFee`, `accessibilityInfo`, `isActive`, `isFeatured`).
All 17 actual JPEG paths exist under `assets/places/` and use the existing packaged
image renderer and placeholder fallback. No assets or dependencies were added.

Add Place exposes ?Load Predefined Place?. Explicit selection fills category,
image, name, short description, description, city, district, address, latitude,
longitude, historical period, opening hours, entry fee, newline-separated
highlights, accessibility information, Active and Featured. Fields stay editable;
selection does not save. Edit Place retains its existing values and does not
expose this replacement helper. Manual Add/Edit/Delete behavior is preserved.

## Stable IDs, image and category mappings

The six existing matching seed IDs are preferred: sigiriya, tooth-temple,
galle-fort, dambulla, nine-arch and jaffna-fort. For the five whose supplied long
IDs differ, import checks both IDs inside the transaction and uses an existing
long-ID document if no preferred-ID document exists. Add auto-fill likewise
reuses known IDs; Save still reports a duplicate rather than silently overwriting
an existing record. Such records can be edited through Edit Place.

The old broad `anuradhapura` and `polonnaruwa` city records are not replaced by
individual monuments. Other documents are retained. Import into a previously
seeded eight-place catalog therefore retains two distinct city records; it does
not delete records to force a total of 17. If both known IDs already exist, the
preferred ID is updated and the other record is retained rather than deleting
references or data. Unknown IDs are not guessed from names.

All image filenames below are actual verified files in `assets/places/`.

| Preferred stable ID | Place | Existing category | Actual image filename |
|---|---|---|---|
| sigiriya | Sigiriya Rock Fortress | Forts | `sigiriya_rock_fortress.jpg` |
| quadrangle-polonnaruwa | Quadrangle (Polonnaruwa) | Ancient Cities | `quadrangle_polonnaruwa.jpg` |
| galle-fort | Galle Fort and Old Town | Forts | `galle_fort_and_old_town.jpg` |
| adams-peak | Adam's Peak | Temples | `adams_peak.jpg` |
| dambulla | Cave Temples (Dambulla) | Temples | `cave_temples_dambulla.jpg` |
| abhayagiri-dagoba-anuradhapura | Abhayagiri Dagoba | Temples | `abhayagiri_dagoba_anuradhapura.jpg` |
| nine-arch | Nine Arch Bridge | Architecture | `nine_arch_bridge_ella.jpg` |
| gal-vihara-polonnaruwa | Gal Vihara Buddha Figures | Temples | `gal_vihara_buddha_figures_polonnaruwa.jpg` |
| tooth-temple | Temple of the Tooth | Temples | `temple_of_the_tooth_kandy.jpg` |
| worlds-end-horton-plains | World's End | Nature | `worlds_end_horton_plains.jpg` |
| kandasamy-kovil-trincomalee | Kandasamy Kovil | Temples | `kandasamy_kovil_trincomalee.jpg` |
| mulkirigala-rock-temples | Mulkirigala Rock Temples | Temples | `mulkirigala_rock_temples_tangalle.jpg` |
| liptons-seat-haputale | Lipton's Seat | Nature | `liptons_seat_haputale.jpg` |
| kiri-vihara-polonnaruwa | Kiri Vihara Dagoba | Temples | `kiri_vihara_dagoba_polonnaruwa.jpg` |
| jaffna-fort | Jaffna Fort | Forts | `jaffna_fort_jaffna.jpg` |
| mihintale-peak-and-ruins | Mihintale Peak and Ruins | Temples | `mihintale_peak_and_ruins_anuradhapura.jpg` |
| japanese-peace-pagoda-unawatuna | Japanese Peace Pagoda | Temples | `japanese_peace_pagoda_unawatuna.jpg` |

## Import behavior and authorization

?Import All 17 Places? on Manage Historical Places opens confirmation:
?Import all 17 predefined historical places?? with Cancel / Import.

The existing CatalogController operation guard requires an authenticated admin,
blocks repeated in-flight actions, and controls busy/error state. Production
Firestore rules remain the authority for authorization, including revocation.
There is no client-side admin bypass or automatic startup import.

One Firestore transaction reads all known candidate IDs before writing:

- **Created:** missing records receive predefined metadata, zero initial legacy
  aggregate values, and server creation/update audit timestamps and admin UID.
- **Updated:** changed records receive only predefined metadata and update audit
  fields through transaction.update; existing document contents are not replaced.
- **Skipped:** identical metadata causes no write or audit timestamp change.

UI reports all three counts. Empty test store: created 17 / updated 0 / skipped 0.
Second unchanged import: created 0 / updated 0 / skipped 17, still 17 records.
Existing creation metadata, rating/reviewCount, unknown fields, review
subcollections, favorites, and itinerary references remain intact. Nothing is
deleted during import. Reimport restores changed predefined metadata after the
admin's explicit confirmation; unrelated fields survive.

## Featured and discovery behavior

Featured subset (7): Sigiriya Rock Fortress, Galle Fort and Old Town, Cave Temples (Dambulla), Nine Arch Bridge, Temple of the Tooth, Jaffna Fort, Mihintale Peak and Ruins.

Home's existing selection still limits output to four active places, prioritizing
featured records. Explore's existing active/category/search logic receives all
17 active records; no Home/Explore code was changed.

## Files created/modified in this task

Created:
- `lib/features/admin/services/predefined_places.dart`
- `test/predefined_places_test.dart`
- `docs/predefined_places_import.md`

Modified:
- `lib/features/admin/services/place_repository.dart`
- `lib/features/admin/services/catalog_controller.dart`
- `lib/features/admin/screens/admin_screens.dart`
- `test/part8_admin_place_management_test.dart` (category finder now identifies
  the category dropdown explicitly; all original checks remain)
- `test/part81_emergency_images_test.dart` (the same category finder adjustment;
  packaged-image save coverage remains)
- `test/firestore_rules_test.cjs` (preserves the 212 existing assertions and adds
  seven authorization cases for atomic 17-record creation and metadata updates,
  with additional field-preservation checks)

## Tests and verification

19 new Flutter regression cases cover dataset cardinality/unique IDs/names,
coordinates/categories, actual image assets, complete supplied content,
legacy references, featured/active behavior, empty/repeated imports, non-admin
and signed-out denial, duplicate submission prevention, Firestore audit fields,
safe metadata updates preserving reviews/favorites/itineraries/unknown fields,
long-ID reuse, favorite reconciliation, manual CRUD, full Sigiriya/Galle form
auto-fill, editable saved values, Edit safety, and import confirmation/cancel.
Existing manual form retry, edit, delete, and compact-screen regressions remain.

Targeted new + existing admin tests: 65 passed.
- `dart format lib test`: 152 files, final run changed 0 files.
- `flutter analyze`: no issues, exit 0 (8.7 seconds).
- `flutter test`: **542 passed**, exit 0 (523 existing + 19 new; 39 seconds).
- Local Auth/Firestore emulator suite: **219 authorization/persistence assertions
  passed**, exit 0 (212 existing + 7 bulk-import cases), with additional checks
  preserving creation audit, aggregates and unknown metadata during update.
- `flutter build apk --debug`: success, exit 0; assembleDebug 64.7 seconds.
  APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Existing nonfatal build advisories remain: Java/Gradle restricted native access
  and firebase_auth/firebase_core Kotlin Gradle Plugin migration.
- Rules SHA-256 remained
  `E6908ED67E9DD3D3D9F7FD577E9B089A3116124A9E2A3C22B3DCBEB263BEC309`.
- No production import or deployment was performed. An admin can load the helper
  or initiate the confirmed import through the application.

Firestore rules changed in this task: **NO**. No production writes, deployment,
Firebase Storage, paid services, Part 10, authentication/social-login changes,
Group Tracking/lifecycle changes, or map/routing changes were made.
