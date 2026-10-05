# Part 8.1: Emergency contacts and packaged place images

Firebase Storage was intentionally removed from the place-image workflow to avoid the Blaze billing requirement for this academic project. There is no runtime upload, gallery selection, Storage initialization, object deletion, upload progress or Storage deployment requirement. Part 9 has not started.

## Correction file inventory

Created:
- `lib/features/admin/services/place_image_catalog.dart`: centralized 17-option catalog, explicit name mappings and asset/HTTPS reference helpers.
- `lib/features/admin/widgets/place_image_selector.dart`: responsive scrollable thumbnail grid, selected state, Cancel and Use Image confirmation.

Modified:
- `lib/features/admin/services/catalog_controller.dart`: removed upload/deletion orchestration and media dependencies; normal guarded Firestore CRUD remains.
- `lib/features/admin/screens/admin_screens.dart`: existing Add/Edit form uses Choose Place Image, preview, restore and placeholder controls; removed raw image field/gallery/progress UI.
- `lib/core/firebase/app_services.dart`: removed Storage/picker injection and construction; preserved Firebase Auth, Firestore and emergency injection.
- `lib/features/discovery_planning/models/heritage_place.dart`: removed obsolete imageStoragePath; existing imagePath remains.
- `lib/features/discovery_planning/widgets/place_card.dart`, `lib/features/admin/services/place_validation.dart`: reference helpers now have no Storage dependency.
- `pubspec.yaml`, `pubspec.lock`: removed firebase_storage and image_picker and their unused transitive dependencies; registered assets/places/.
- `firebase.json`: removed Storage rule/emulator configuration; preserved project, FlutterFire, Firestore rules/indexes and Auth/Firestore emulator settings.
- `test/part81_emergency_images_test.dart`, `test/support/part81_fakes.dart`: retained every emergency test and renderer compatibility test; removed obsolete media fakes/tests and added asset selector tests.
- `README.md`, this document.

Removed:
- `lib/features/admin/services/place_images.dart`
- `storage.rules`
- `test/storage_rules_test.cjs`

The 17 JPGs already existed in assets/places/ when inspected; they were not generated or replaced. Existing branding/icons/placeholders are preserved. Generated plugin registration is maintained by Flutter. No manifest permission was added or removed by this correction. Generated firebase_options.dart still contains the FlutterFire bucket metadata as part of Firebase Core options; it neither initializes Storage nor requires a bucket or billing upgrade. Firebase Core initialization is unchanged.

## Packages and assets

Removed direct packages: firebase_storage 13.6.0 and image_picker 1.2.3. Inspection confirmed neither was used by any other feature. Preserved firebase_core, firebase_auth, cloud_firestore and url_launcher 6.3.3. No new package is needed.

pubspec.yaml registers assets/places/ along with all existing asset directories. All 17 actual JPG filenames match the centralized PlaceImageCatalog entries. Thumbnail labels and paths are defined once. Explicit name aliases are available through forPlaceName; this lookup does not mutate documents, auto-select by name or run at startup. Administrators retain their chosen image even if the place name matches a different catalog entry.

## Admin image flow and Firestore

Admin Panel ? Historical Places ? Add/Edit ? Choose Place Image ? tap thumbnail ? Use Image ? preview ? Save. The selector displays 17 thumbnails and names in a scrollable responsive grid, with a selected border/check and accessible selected semantics. Cancel preserves the previous selection. Use placeholder changes the pending reference to the existing fallback; Restore current image discards a pending change. No raw asset path needs to be typed.

The existing `places/{placeId}.imagePath` field stores a packaged path, for example `assets/places/galle_fort_and_old_town.jpg`. No duplicate imageReference field is introduced. Save uses the existing stable ID, guarded repository, server audit fields and duplicate-save protection. Edit updates only the reference through normal Firestore persistence; no upload/delete is involved. The live catalog updates discovery and admin consumers. No startup migration overwrites manual choices and no production records were altered during verification.

Legacy HTTPS imagePath values remain readable and are retained when editing other fields without choosing a different image. New selections come only from the packaged catalog or placeholder. Legacy imageStoragePath data is ignored; it is not written by the model. This correction neither deletes old cloud objects nor contacts Firebase Storage.

## Display compatibility

The shared PlaceImage renderer supports assets/places/, assets/placeholders/ and valid HTTPS URLs. Missing/invalid images fall back to assets/placeholders/place_placeholder.jpg; network images retain loading and failure fallback. Existing admin preview/list, Home/Discover, search, details, favorites and itinerary/place-card consumers inherit this behavior. Navigation and group destination selectors currently display names rather than thumbnails; their existing selection behavior is preserved and the chosen place retains its image reference. No new destination/photo field is introduced.

Packaged images work without image-network access after installation. Firestore still needs its existing authentication/network configuration for live data. Adding new built-in photos requires an updated asset catalog and app build. Old externally hosted HTTPS references remain dependent on their host. Stored itinerary snapshots keep their existing image reference until the user regenerates/edits the itinerary. This selector provides no camera/gallery/custom upload feature.

## Emergency Contacts: preserved

Production still uses FirestoreEmergencyRepository and EmergencyController; it has not reverted to demo contacts. Admin CRUD, search, category filter, active/verified toggles and priority remain. Top-level emergencyContacts/{id} stores id, name, category, phoneNumber, description, isActive, isVerified, priority, createdAt/updatedAt and createdBy/updatedBy. Server audit values and immutable creation fields are preserved. New contacts default inactive/unverified. No real emergency numbers are seeded; the synthetic number in tests is never production data.

Normal users query contacts where BOTH isActive and isVerified are true. Loading/error/retry/empty states and priority/name sorting remain. Call normalizes the current valid number and opens a tel: URI through url_launcher externalApplication. The user decides whether to call. Dialer-unavailable errors are friendly; CALL_PHONE is not requested. Administrator verification still requires checking an authoritative source.

## Security and deployment

firestore.rules and test/firestore_rules_test.cjs are unchanged by this correction. User isolation, protected admin role, places, emergencyContacts and group protections remain. Storage rules/tests/configuration were removed because the application no longer uses that service. No production deployment was performed.

From this project directory, the exact resulting deployment command is:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project heritagewalk-sri-lanka
```

Do not deploy Storage. No Storage bucket or Blaze upgrade is required for the packaged-image workflow. Existing Firebase Email/Password Auth setup and trusted Part 8 admin bootstrap still apply. Keep the project heritagewalk-sri-lanka and application ID lk.heritagewalk.heritage_walk. A client cannot promote its own role.

## Tests and local verification

Before correction: 222 Flutter tests; 121 Firestore assertions plus 21 Storage assertions (142 combined).

Removed only 22 obsolete upload/picker/managed-object tests. Retained all 34 other Part 8.1 tests, including every emergency test and asset/HTTPS renderer compatibility test. Added 27 packaged-image tests: catalog/actual file equality, explicit mappings, package/config absence, individual rendering of all 17 JPGs, create/edit references and audit preservation, startup choice preservation, cancel, selected-state/preview/save, Add flow and narrow-phone/large-text grid scrolling. All 166 pre-Part-8.1 tests remain.

Verified Flutter count: **227 passed** (166 existing +34 retained Part 8.1 +27 new packaged-image tests). `flutter pub get` succeeded, `dart format lib test` completed on 125 files, and `flutter analyze` reported no issues. Storage's 21 assertions were removed; all **121 Firestore assertions passed** against demo emulators without production writes:

```powershell
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
```

Requested verification:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

`flutter build apk --debug` succeeded. Output: build/app/outputs/flutter-apk/app-debug.apk. ZIP inspection verified all 17 JPGs are included. The APK installed successfully on emulator-5554 and reached the normal Welcome Back / Sign In screen; the HeritageWalk process remained resumed and reported no startup errors. No emulator test numbers or role fixtures were inserted into production.

## Manual acceptance

- Admin Add Place: fill required fields, select one of the 17 images, confirm preview, save and check Firestore imagePath.
- Admin Edit: check current selection; cancel another selection; confirm a replacement; restore or use placeholder; save and restart to verify persistence.
- Scroll to all images on a small phone/large text setting. Check admin preview/list, Home/search, Place Details, favorites, itinerary cards and destination previews where relevant.
- Confirm an existing HTTPS reference still displays or falls back; editing unrelated fields must retain it.
- Admin Emergency Contacts: create/edit/search/filter, deactivate/reactivate, verify/unverify, change priority and delete. Use a properly sourced number; do not call a real emergency service merely to test.
- Normal user sees only active+verified contacts and can open/cancel the dialer. Verify inaccessible admin routes and denied writes.
- Deploy reviewed Firestore rules/indexes using the explicit command above and check the actual production account/permissions. No Storage setup step is needed.

## Warnings and limits

Dependency resolution reports four newer package versions incompatible with current constraints. The successful build warned about Java native access and firebase_auth/firebase_core plugins still applying KGP; future Built-in Kotlin support may require plugin updates. The first APK build attempt was not executed because automatic approval review hit a usage limit; the later approved retry completed. A leftover local demo Firestore process initially occupied port 8080; only the verified demo process was stopped, then all 121 assertions passed with CLI exit 0. No security assertion failed.

ADB's initial 15-second launch wait timed out on this emulator, but Android subsequently reported the app fully drawn after approximately 24 seconds and independent UI inspection confirmed the Sign In screen. An unrelated android.vending process emitted a native emulator crash; HeritageWalk stayed running and its own error log was clear. These observations do not prove physical-device performance. Synthetic tests cannot prove a physical device dialer or production deployment. Place images are bundled and cannot be replaced with arbitrary photos at runtime.

Part 9, Maps/GPS and live tracking remain deferred.
