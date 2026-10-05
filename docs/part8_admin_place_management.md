# Part 8 — Admin and historical place management

Part 8 extends the existing app and Firebase repositories. The normal Android entry point still initializes Firebase and uses `AppServices.firebase()`. Parts 1–7, the logo, theme, routes, authentication, private data and demo navigation remain intact. No packages were added. Part 9 has not started.

## Architecture and authorization

`CatalogController` is injected through `AppServices` and `CatalogScope`. Production uses `FirestorePlaceRepository` and `FirestoreRoleRepository`. Default `AppServices()` keeps the eight local fixtures for existing tests; tests can inject `InMemoryPlaceRepository` and a fake role source. Flutter tests never connect to production Firebase.

The identity is the current Firebase Authentication UID. Its profile is `users/{uid}` with `role: "user" | "admin"`. Registration and missing-profile recovery write `user`. Missing/unknown roles decode as user. No first-user promotion, hard-coded admin email/password, local preferences, or editable role control exists. Profile copies preserve their role; production profile updates omit the role field entirely. Existing Part 7 profiles without role remain normal users and can still edit their other fields.

The production role listener grants privileged UI only for a server-confirmed snapshot without pending writes. Cache-only snapshots and role-stream failures deny access. Role changes update Profile and guard already-open admin screens; logout cancels subscriptions and clears management state. Every repository write is independently authorized by Firestore rules using the current `users/{request.auth.uid}.role`, so client state never grants backend permission.

All privileged routes wrap their content in a reactive `AdminGuard`:

- `/admin`
- `/admin/places`
- `/admin/places/add`
- `/admin/places/edit` (stable document ID argument)
- `/admin/places/preview` (place argument resolved against the management catalog)

Normal users see a safe denial for direct routes and no Profile Admin Panel entry. Existing cloud authentication guards still send unauthenticated users to Login.

## First-admin bootstrap and deployment

These manual actions are **not performed automatically**:

1. Deploy the locally validated Part 8 rules before using the new catalog:

   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes --project heritagewalk-sri-lanka
   ```

2. Register the intended administrator through the existing app, or log in to an existing intended account. Ensure `users/{uid}` exists.
3. In Firebase Console, select **heritagewalk-sri-lanka → Authentication → Users**, select that account, and copy its UID.
4. In **Firestore Database → Data → users → that exact UID**, add/edit the **string** field `role` to **admin**. Use your authorized Firebase project-owner access. Do not change UID, document ID, creation metadata or private records.
5. Return online to the app. Its live role listener should reveal **Profile → Admin Panel**; sign out/in if necessary.
6. To revoke privileges, use the same trusted Console access to set `role` to `user`. Clients cannot grant or revoke their own role.
7. Open **Manage Historical Places → Seed original catalog (one-time setup)** and confirm. Verify the created/skipped result and catalog contents.

Only an authorized project owner/trusted administrative process should assign roles. Do not put service-account credentials into the mobile app. This implementation does not add an in-app role-management UI or deploy production rules. A successful local emulator run is not a production deployment.

## Catalog schema

The canonical production collection is `places/{placeId}`. Existing `HeritagePlace` is extended; no second conflicting place model was created.

| Field | Representation / behavior |
| --- | --- |
| id | Stable document ID; decoding always uses the actual document ID |
| name, shortDescription, description | Text; name and description required |
| category | Ancient Cities, Temples, Forts, Nature, Architecture |
| city, district | Required text; planning destinations derive from active catalog cities |
| address, historicalPeriod, accessibilityInfo | Optional text |
| latitude, longitude | Optional finite numbers; latitude −90…90, longitude −180…180 |
| imagePath | Packaged `assets/` reference, preserving existing assets |
| openingHours, entranceFee | Optional display text; existing `entranceFee` spelling retained for compatibility |
| highlights | List of strings; form accepts one per line |
| isActive | Boolean; only true is discoverable by normal users |
| isFeatured | Existing featured-home flag |
| rating, reviewCount | Existing illustrative demo values; new places default to zero, not actual user analytics |
| createdAt, updatedAt | Firestore server timestamps on writes; model accepts Timestamp, DateTime, legacy ISO strings |
| createdBy, updatedBy | Authenticated admin UID; creation metadata immutable on edits |

Malformed optional values decode safely. Invalid/out-of-range coordinates decode to null; forms reject invalid supplied values before constructing the model. Legacy/local snapshots default to active, but production queries and rules require an explicit `isActive: true` in catalog documents. Seeded documents include this field. No fake geographic coordinates were invented for the original fixtures, which did not supply coordinates.

## Dashboard, CRUD and failures

The dashboard shows actual total/active counts, category counts and recent updates. It does not imply user analytics. Existing green/gold Material 3 styling and scrolling layout are reused.

Management supports loading, empty, safe backend error/reload, search, category filtering, Add, Edit, Preview and named Delete confirmation. Active and inactive places remain visible to admins. Preview reuses Place Details, adding administrative status, image reference and audit information. No normal-user editing controls were added.

Create validates required fields and optional coordinates, generates one stable ID per form, and uses a Firestore transaction to create only if absent. A failed retry keeps that ID. Edit is prefilled and preserves existing creation metadata in the transaction while setting current server update time/updater. Delete verifies the document exists and deletes only that catalog document. Pending operations disable repeated submissions; missing documents, permission failures and network failures display safe messages via the existing backend error mapper.

Writes use transactions, which require connectivity. The controller waits up to 20 seconds. A timeout cannot cancel an already submitted SDK request: reload the catalog before deciding whether to retry. Stable IDs protect create retries. Updates use last confirmed writer behavior; simultaneous administrators can overwrite editable fields, but cannot alter the original creation metadata.

## Explicit catalog seed

There is **no startup seeding or production local fallback**. The admin management screen exposes a confirmed setup action with created/skipped counts. `CatalogController.seed()` iterates `DiscoveryService.localPlaces` and calls transactional create-if-absent.

Stable IDs are `sigiriya`, `tooth-temple`, `galle-fort`, `dambulla`, `polonnaruwa`, `anuradhapura`, `nine-arch`, `jaffna-fort`. An empty catalog produces **created 8 / skipped 0**; repeating produces **created 0 / skipped 8**. Existing records, including admin edits and inactive places, are never overwritten. A partially interrupted seed can be rerun safely. If an original seed document was deliberately deleted and seeding is explicitly rerun, that missing original ID is recreated; deactivate to retain a hidden original document.

Local fixtures remain for offline unit/widget tests. Until deployment/bootstrap/seeding or manual creation, a production catalog is empty or reports a permission error under the previous rules; it does not silently display hard-coded places as cloud data.

## User integration and saved references

Production subscribes to `places.where('isActive', isEqualTo: true)` after authentication. Discovery, home/search/category filters, previews/details, itinerary generation, navigation destination selection and group destination selection consume the shared catalog service. Existing chooser consumers therefore receive Firestore places without a redesign. New cities appear in tour planning. Catalog changes rebuild screens; selectors reset safely when their selected destination disappears.

Favorite persistence remains a map of stable place IDs. Display metadata is reconciled with current active catalog data. Missing/deleted/inactive IDs remain saved, display **Unavailable place**, and can be explicitly removed by the user. Catalog reconciliation does not change favorite IDs and therefore does not trigger cloud deletion or redundant uploads. Favorites arriving before catalog snapshots resolve when the catalog arrives.

Saved itineraries retain their existing embedded place snapshots and chosen dates; admin changes never rewrite them. Groups retain destination ID/name snapshots. No cascade deletes private favorites, itineraries, guide notes or groups. Existing saved content can still show historical snapshot information, while new destination selection uses the active catalog. Navigation and tracking remain labeled demo behavior.

## Images

The existing `PlaceImage` uses `Image.asset` with an error fallback and placeholder labeling. Part 8 preserves this strategy. Admins may enter a bundled `assets/` path or leave it blank for the original placeholder. Traversal and remote references are rejected by the form/controller. Missing packaged files fall back safely. Adding a new asset requires bundling it in a future app build. No Firebase Storage, file upload or remote image downloads are implemented or advertised.

## Security rules and indexes

The existing private-user and group/invite rules remain in force. Profile creation now requires `role == 'user'`; the existing update allowlist excludes role and identity fields. Place rules grant authenticated normal users active-only reads, deny their CRUD, and grant trusted-role admins catalog CRUD. Anonymous catalog reads/writes are denied. Place writes enforce identity, required core data, category, coordinate bounds, server update timestamps/current updater, and immutable creation metadata. Admin status does not bypass another user's private-data isolation.

No composite indexes were added. Production discovery uses one equality condition on `isActive`; admin list reads the collection. Search, category summaries and sorting run locally on the academic-size catalog. Existing `firestore.indexes.json` remains unchanged. Security rules are not query filters: the active-only query constraint intentionally matches the read rule ([Firebase documentation](https://firebase.google.com/docs/firestore/security/rules-query)). For a substantially larger catalog, add pagination/query design with the corresponding tested indexes.

## Local verification

Commands, from the project directory:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "powershell -NoProfile -File tool/run_part8_smoke.ps1"
```

The Node suite retains all **59 Part 7 assertions** and adds **32 Part 8 assertions**, totaling **91**. Tests cover default-user creation, protected role changes, trusted bootstrap/revocation, private-data isolation, active queries, normal/anonymous denials, admin CRUD, coordinate validation and server audit protection. Its emulator-only owner token simulates trusted Console access, and is never used by production application code.

The new Flutter suite covers roles/guards, model and timestamps, validation, repository CRUD/watch, search/categories, idempotent seed, live catalog, stale favorites, saved itinerary snapshots, errors/loading/empty state, form submission/retries/editing/delete confirmation, role revocation and small-screen layouts. All original 120 tests are retained.

Final local results (5 October 2026): `flutter pub get` succeeded; formatting completed; `flutter analyze` reported **No issues found**; **166 Flutter tests passed (120 existing + 46 new)**; **91 security assertions passed (59 existing + 32 new)**; the Android SDK smoke retry printed **PART8_SDK_SMOKE_PASS**; the ordinary `flutter build apk --debug` succeeded. APK: `build/app/outputs/flutter-apk/app-debug.apk`. The rebuilt normal APK was installed and launched on Android; UI Automator confirmed Login is visible. Login/Home routes also pass the preserved authentication widget suite.

Nonblocking warnings: four existing transitive packages have newer versions outside the current constraints; Gradle reports Java native-access warnings; existing Firebase Auth/Core plugins report future Built-in Kotlin compatibility warnings. The first extra SDK smoke attempt hit an Android emulator native JIT SIGSEGV and timed out; its retry passed. No analyzer errors or failing final Flutter/security tests remain. Production deployment and production admin CRUD acceptance are still manual.

The Android SDK smoke tool uses a named Firebase app with **demo-heritagewalk**, disabled local persistence, and only `10.0.2.2` emulator endpoints. It verifies actual Firebase registration, default role, trusted local bootstrap, live role/catalog subscriptions, transactional seed, server audit, profile-role preservation, CRUD, references and restart restoration. It never writes production data. Rebuild the ordinary `lib/main.dart` APK after running a smoke target.

## Manual acceptance checklist (after deployment and bootstrap)

- **Normal user:** register/login → Home → active catalog → search/category → preview/details → favorite → generate/save itinerary. Confirm Profile has no Admin Panel; direct admin routes deny access.
- **Admin:** login → Profile → Admin Panel → check counts → Add a disposable place with coordinates and asset reference → preview → edit → verify another signed-in user sees changes → deactivate (hidden from normal user) → reactivate → cancel Delete once → confirm Delete.
- **Security:** repeat normal-user place writes and role escalation against local emulators using the supplied suite. They must fail. Admin private access to another user must also fail. Revoke role in Console and confirm an open admin screen becomes denied.
- **Persistence:** save favorites/itinerary, restart app, log in, confirm catalog/user records remain. Delete a favorited test place as admin, confirm the user sees an unavailable favorite and their old saved itinerary still opens.
- **Seeding:** first run reports the missing records created; repeat reports them skipped and preserves edits. Never seed as an automatic login/startup action.
- **Errors/layout:** check airplane mode/reload, a missing image asset, narrow phone/text scaling, invalid coordinates, and a place deleted by another admin while its edit form is open.

## Files and limitations

Created: `lib/features/admin/services/{place_repository,place_validation,catalog_controller}.dart`, `lib/features/admin/screens/admin_screens.dart`, `test/part8_admin_place_management_test.dart`, `tool/part8_emulator_smoke.dart`, `tool/run_part8_smoke.ps1`, this document.

Modified for Part 8: `lib/core/firebase/{account_repository,app_services}.dart`, `lib/core/routes/app_routes.dart`, `lib/main.dart`, `lib/features/auth_profile/{models/user_profile,screens/profile_screen}.dart`, `lib/features/discovery_planning/models/heritage_place.dart`, its services `{discovery_service,favorites_service,itinerary_service}.dart`, its screens `{home_screen,plan_tour_screen}.dart`, `lib/features/discovery_planning/widgets/place_preview_sheet.dart`, `lib/features/navigation_guide/{screens/place_details_screen,screens/navigation_screen}.dart`, `lib/features/group_support/{screens/create_group_screen,widgets/group_dialogs}.dart`, `firestore.rules`, `test/firestore_rules_test.cjs`, `README.md`.

No packages, Firebase services or composite indexes were added. Production deployment, admin assignment and seeding remain manual. The original catalog has illustrative ratings and placeholders; opening information should be verified before visiting. Catalog browsing currently loads the complete academic-size active/admin catalog; pagination, remote images, upload, role management UI, concurrent edit conflict UI, real Maps/GPS/directions, full localization and support-team delivery are outside Part 8. Part 9 is deferred.
