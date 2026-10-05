# Part 7: Firebase Authentication and Firestore persistence

## Packages and app wiring

Firebase Core initialization and the generated Android options remain intact.
This part adds firebase_auth 6.7.0 and cloud_firestore 6.10.0 (plus their SDK
dependencies). No Storage, maps, GPS, social authentication or Admin packages.

main() explicitly runs HeritageWalkApp with AppServices.firebase(). AppServices
injects AccountRepository and DataRepository into the existing services/scopes.
HeritageWalkApp without injected services retains the memory implementation for
the original widget tests and foundation previews; it is not the production entry
point. All original interfaces, catalog, theme, assets, routes and CRUD remain.

FirebaseAccountRepository handles email/password registration, sign-in, reset
email, restored authentication and logout. Firebase UID is canonical. Registration
preserves the entered name in Auth and creates users/{uid} with server timestamps.
If profile creation fails after Auth creation, the account still exists: sign in
again to recover its profile (the name is retained in Auth). No fake profile is
uploaded. Auth state changes clear expired sessions; Splash retains its two-second
experience and waits for restored auth and data before choosing Home or Login.
Protected routes require an authenticated cloud session. Error codes are mapped
to safe user-facing messages. Passwords are passed only to Auth, never Firestore.

Profile changes await Firestore. The existing editable email is a contact email;
changing it does not change the Auth sign-in address. The form explains this.
Profile photos remain local/demo asset references. There is no image upload.

## Firestore schema

| Path | Purpose |
| --- | --- |
| users/{uid} | id/uid, fullName, contact email, phone, bio, photoPath, createdAt/updatedAt |
| users/{uid}/favorites/{placeId} | Place ID only; local catalog resolves content |
| users/{uid}/itineraries/{id} | Saved title, plan, catalog place snapshots, timestamps |
| users/{uid}/guideNotes/{id} | Place ID, note text, timestamps |
| users/{uid}/supportRequests/{id} | Subject, message, category, status, timestamps |
| users/{uid}/preferences/settings | selectedLanguageCode: en/si/ta |
| groups/{id} | Metadata, leader ID, invite code, memberIds and members map keyed by ID |
| groupInvites/{code} | groupId, leaderId; get-by-code only, no enumeration |

Private collections use their authenticated UID path. Favorites deduplicate by
place ID. Only saved itineraries upload; drafts, generation and regeneration stay
local until saved. Notes, requests and preferences restore across logout/login
and restart. Support requests remain academic records, not real team delivery.
IDs for cloud groups/support requests use Firestore auto IDs. Invite codes contain
16 cryptographically random uppercase alphanumeric characters after HW- (about
83 bits), with a transaction reserving the code and group atomically. Collisions
fail safely rather than overwrite another invite.

Groups embed a bounded members map (maximum 50 members), avoiding orphaned member
subcollections on deletion. Member-filtered queries show only joined groups.
Code holders resolve the invite and perform a self-only atomic join. Duplicate
membership is prevented by UID keys and arrayUnion. Leaders can rename/change
destinations, remove nonleaders and explicitly add demonstration entries; demo
members are not Auth accounts and have no permissions. These entries are uploaded
only after the user's explicit Add Demo Member action, never seeded automatically.
Group deletion also deletes the invite in one batch. Only a user's own sharing
state and member identity are updated by members; leaders cannot change another
real member's sharing state. Leader reassignment/removal is forbidden.

Relative marker positions, online indicators, tracking refresh and route estimates
are local DEMO values, never geographical data. Marker movement is not persisted.
The member sharing boolean is persisted. Full-app localization is still deferred;
the existing translated language preview remains immediate.

## Async persistence and migration decisions

SyncController binds existing synchronous view-model mutations to asynchronous
repository diffs. Hydration is suppressed from uploading, and initial user data is
loaded before controls are enabled. Snapshot listeners refresh views across devices.
During writes a shared loading indicator absorbs input to avoid duplicate actions.
Failed saves restore the prior local view and show an error with Reload Saved Data
and Sign Out. Reload fetches authoritative server state before further edits.
Writes/loads have a 20-second confirmation timeout. A native offline queued write
cannot be cancelled by this timeout and may later reach Firestore; the banner says
the save is unconfirmed, and reload is required. This is not an offline-editing UI.

Logout first signs out of Firebase, detaches listeners and clears transient caches,
without issuing remote deletions. Cloud language resets locally to English on
logout and restores the next user's saved preference on login, preventing account
leakage. The memory test implementation keeps its original Part 6 session behavior.
Generation tokens prevent stale reads/writes from populating another user's view.
Existing historical place and facilities catalogs remain local/demo. No automatic
upload of old session data or the sample demo identity occurs.

CloudValues handles SDK Timestamp (UTC), DateTime and legacy ISO strings, null or
missing optional values and unknown enum values. Model factories use typed
fallbacks instead of blind casts. Server timestamps are used on cloud creation/
updates while legacy local serialization remains supported.
Tour dates keep their calendar ISO value instead of becoming UTC audit timestamps;
audit dates are displayed in the device's local time.

## Security and deployment

firestore.rules denies private access without Auth and restricts profiles and known
private subcollections to their owner. Groups are readable only by members;
invites cannot be listed. Leader-only metadata/member management, leader
protection, self-only sharing, code-validated joining and immutable group identity
are enforced on the server. Client role checks provide immediate feedback but are
not the security boundary. No blanket public-read/write rule exists. Unknown
collections are denied. The group memberIds array query uses automatic single-field
indexing; firestore.indexes.json has no composite indexes.

The existing FlutterFire section of firebase.json is preserved. It now references
the rules/indexes and local test emulator ports. Production rules are NOT deployed
automatically. Production-mode deny rules must be replaced with these validated
rules before cloud features can work. From the project root, an authorized project
owner should run:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project heritagewalk-sri-lanka
```

Confirm Email/Password is enabled and the default Firestore database exists (both
reported already configured). No FlutterFire reconfiguration is required.

## Verification

All original tests remain. New injected fake-repository tests exercise auth
registration/login/restore/logout, clean initialization, user isolation, profile
updates, every persisted CRUD feature, invites/permissions, timestamps, error
mapping and loading/retry states. Widget tests use no live Firebase or network.

The independent Node script uses built-in fetch/assert against local emulators,
validates rules and real document persistence with two distinct Auth identities,
and never touches production:

```powershell
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
```

Run flutter pub get, dart format lib test, flutter analyze, flutter test and
flutter build apk --debug. Native SDK emulator smoke tooling, when available,
is described in tool/run_firebase_smoke.ps1. Actual production persistence should
also be checked after rule deployment, including force-close/restart and two
separate accounts. Emulator verification does not assert production rules have
already been deployed or that a real support team exists.

The SDK smoke uses a named Firebase app with project ID demo-heritagewalk and
10.0.2.2 Auth/Firestore emulator endpoints, never the production project.
The debug source set permits HTTP only to that emulator host; release has no such
exception. Run it with an Android emulator at emulator-5554:

```powershell
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "powershell -NoProfile -File tool/run_firebase_smoke.ps1"
```

It installs a temporary smoke entry point; rebuild/run the normal lib/main.dart
afterward. The final delivered APK is always built from the normal entry point.

## Limitations and deferred work

Auth/profile creation is not a cross-service transaction; recovery is described
above. Contact email changes do not change sign-in identity. Saved catalog
references may skip removed/unknown favorites. Explicit demo members are local
identities in a persisted group, not actual invited users. Groups are limited to
50 members in this academic build. Permission loss/network errors use reload or
sign-out recovery; offline edits are not supported. Existing Part 1–6 documents
describe their historical in-memory stages; this document supersedes their
production persistence notices.

Parts 8–10 are not started. Admin place management, real maps/GPS/live tracking,
Firebase Storage/photo uploads, complete localization, real support workflows,
social sign-in and push notifications remain deferred. Existing Java native-access
and Firebase plugin/Kotlin compatibility warnings may remain. The Windows Kotlin
incremental-cache workaround from Core setup is preserved.

## Completed verification and file inventory

Dependency resolution/formatting succeeded. Final flutter analyze: no issues.
All 120 Flutter tests passed (the original 89 unchanged plus 31 Part 7 tests).
The local rules test passed 59 authorization/persistence assertions. The native
Android Firebase SDK smoke passed every saved feature, fresh service restoration,
two-user isolation, group joins/sharing/deduplication and group deletion. The normal
lib/main.dart debug APK built successfully. Production rules have not been deployed.

Created:

- lib/core/firebase/: account_repository.dart, app_services.dart,
  backend_error.dart, cloud_status.dart, cloud_values.dart, data_repository.dart,
  firestore_repository.dart, sync_controller.dart.
- firestore.rules, firestore.indexes.json; this documentation.
- test/part7_persistence_test.dart, test/part7_auth_widgets_test.dart,
  test/support/part7_fakes.dart, test/firestore_rules_test.cjs.
- tool/firebase_emulator_smoke.dart, tool/run_firebase_smoke.ps1.
- android/app/src/debug/res/xml/firebase_emulator_network_security.xml.

Modified existing files:

- lib/main.dart, pubspec.yaml, pubspec.lock, firebase.json, README.md;
  Android main/debug manifests (Internet permission and emulator-only debug policy).
- Model factories: UserProfile, HeritagePlace, TourPlan/Itinerary, GuideNote,
  GroupMember, TourGroup, SupportRequest.
- Services: ProfileService/AuthValidators, FavoritesService, ItineraryService,
  GuideNotesService, GroupTourService, SupportService.
- Auth UI: Splash, Login, Register, Edit Profile, password reset and sign-out.
- group_support UI: Group Tours/Create/Details, Language, Help & Support, About,
  FAQ/invite/form/dialog copy and async joining. Existing layout/design preserved.
- discovery_layout.dart: display audit dates in local time.

No original tests, Firebase generated options, logos or catalog assets were
removed/replaced. AppRoutes from Parts 1–6 are preserved. Windows emulator shutdown
occasionally left a demo Firestore Java process on port 8080; only verified
demo-heritagewalk test processes were stopped before reruns. The initial SDK check
found Android's HTTP emulator restriction and then a rejected demo-field join
payload; both were corrected and the final smoke passed without weakening rules.
