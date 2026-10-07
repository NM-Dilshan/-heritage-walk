# Part 9: Maps, GPS, groups and localization

The project uses a free/no-credit-card map architecture for academic use and does not require Google Maps billing for its core map feature. Existing Firebase authentication, catalog, reviews, images, planning, notes, emergency contacts and support persistence remain in place. No production rules have been deployed for Part 9. Part 10 has not been started.

## Dependencies and providers

Added `flutter_map 8.3.2`, `latlong2 0.10.1`, `geolocator 14.1.1`, `http 1.6.0`, `intl 0.20.3` and the SDK `flutter_localizations` package. These resolve with the installed Flutter 3.47.5 / Dart 3.13.4. Flutter Map provides native Flutter pan/zoom, markers, route polylines and camera controls without a paid maps SDK. Google Maps was excluded to meet the no-billing requirement. No API key, Google Maps account, Storage, Cloud Functions or Blaze upgrade is introduced.

Map tiles: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Attribution links remain visible below every map. Requests identify `lk.heritagewalk.heritage_walk`; Flutter Map's default native caching provider respects tile HTTP caching headers. There is no bulk download, offline prefetch or promised offline map support. See the [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) and [Flutter Map cache documentation](https://docs.fleaflet.dev/tile-servers/caching). Public tiles have no service guarantee and can block inappropriate use; a larger deployment needs a suitable provider or self-hosted tiles.

Routing: FOSSGIS public OSRM at `routing.openstreetmap.de`, with distinct `routed-car` and `routed-foot` services. Requests specify full GeoJSON geometry, use an identifying User-Agent, run serially at least two seconds apart and reuse a bounded 20-entry, five-minute in-memory cache. Opening/choosing a destination, changing mode and explicit recalculation trigger requests; GPS stream updates do not. The [provider policy](https://routing.openstreetmap.de/about.html) limits use to one request/second, forbids heavy/scraping usage and requires attribution plus a Fix the map link. Both links are visible. This implementation is appropriate for light academic demonstrations, not an unlimited hosted production navigation service.

## GPS and route architecture

`LocationService` and `RoutingService` are injectable. Production uses `DeviceLocationService` and `FossgisRoutingService`; hardware-free test harnesses explicitly report unavailable GPS unless supplied a fake. Sri Lanka's initial map camera is an overview, never a claimed current position.

Android requests only fine/coarse foreground location in addition to the existing Internet permission. Geolocator checks whether device location is enabled, checks/requests runtime permission and obtains a high-accuracy fix with a 20-second timeout. The UI distinguishes denied, permanently denied, services off, unavailable, timeout and general error, with Allow Location, Open Settings, Enable Location or retry actions. Approximate permission is usable; route accuracy depends on the available fix. No background location permission or foreground notification tracking service is configured.

Home and Explore open the existing Place Details model. Navigate passes that exact model, including its Firestore latitude/longitude and ID, into Navigation. The chooser remains available. Non-finite/missing/out-of-range coordinates produce an unavailable-destination message and disable routing.

OSRM supplies the road/path polyline, distance in metres and duration in seconds. GeoJSON longitude/latitude pairs are validated and decoded into map coordinates. The displayed kilometres and rounded-up minutes derive from those server fields. They are initial route estimates, not traffic-aware live remaining distance/time. Offline, timeout, HTTP error, malformed response and no-route responses have distinct retryable states. Generation checks discard obsolete GPS and route responses when the destination, mode, screen or lifecycle changes.

Start Route Guidance starts live GPS marker updates (25-metre distance filter, ten-second Android interval). The stream uses Geolocator's direct Android LocationManager option to avoid a delayed fused-provider settings callback restarting updates after an immediate cancellation. Ending guidance, closing the screen, signing out or leaving the foreground cancels tracking. Destination/mode changes stop previous guidance. Emergency navigation suspends GPS first. This is route preview plus live positioning: no spoken instructions, automatic turn-by-turn directions, compass integration, automatic rerouting or offline routing is claimed.

GPS used for personal navigation stays off Firestore. Route requests transmit the start/destination coordinates to FOSSGIS; tiles expose the viewed area and network address to the tile provider. Provider server logging is governed by their policies. The navigation screen describes the coordinate transfer.

## Group location sharing and security

The screen owns a `GroupLocationSession`. Opening tracking or logging in never starts GPS or uploads a position. An authenticated current member must explicitly press Start Sharing Location. Stop removes the current snapshot and cancels GPS; screen disposal, backgrounding, membership loss, deletion and signout stop sharing. Opening destination details or navigation stops sharing first. Sharing does not automatically resume.

Only the latest snapshot is stored at `groups/{groupId}/locations/{uid}`:

| Field | Meaning |
| --- | --- |
| userId | Authenticated owner UID, matching document ID |
| displayName | Public display name, at most 80 characters; email-like/empty names replaced |
| latitude | Finite latitude in [-90, 90] |
| longitude | Finite longitude in [-180, 180] |
| updatedAt | Firestore server timestamp |

GPS updates write at most once per ten seconds. A fresh GPS heartbeat every 60 seconds keeps stationary sharers current. Writes and deletion are serialized so a late queued write cannot recreate the snapshot after Stop. The UI excludes unconfirmed cached/pending snapshots, removed members, invalid positions, timestamps more than a minute in the future, and positions older than two minutes. Missing and stale members are labelled honestly; there are no demo moving markers or fake online statuses.

Rules permit reads only to current group members, even for administrators. Only the matching authenticated member can create/update their own document. Exact allowed fields, ownership, bounded coordinates, safe name and server timestamp are enforced. An owner may delete their own snapshot after leaving or parent-group deletion, enabling cleanup; other users cannot. Existing group ownership, catalog, admin, review and per-user persistence rules remain intact. There is no new index requirement.

This is foreground sharing, not background tracking. Removal is best effort when offline or when credentials are already revoked during signout. Old server snapshots may remain stored until a successful owner cleanup; stale UI positions disappear after two minutes. No TTL or scheduled server deletion is claimed. Firestore may queue an offline write already submitted to the SDK; the serialized delete follows it. A lost connection cannot provide a real-time revocation guarantee. No location history, trails or private profile/contact fields are stored.

## Localization

Flutter `LocalizationsDelegate` plus `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations` and `GlobalCupertinoLocalizations` support `en`, `si` and `ta` throughout the app. Three standard JSON resource files hold 571 matching resources per locale (1,713 translated values). `tool/part9_translations.tsv` is the editable source; `node tool/part9_build_locales.cjs` regenerates JSON and the synchronous Dart resource map. Format the generated Dart file afterwards. Synchronous loading preserves the existing initialization and widget tests.

`LanguageService` controls MaterialApp.locale and retains the existing Firestore preference restore/save mechanism. Normal-user labels, navigation, forms, validators, tooltips, permission/routing messages, review controls, safety, group controls, support FAQs and app-owned guide paragraphs are translated. Existing theme, scopes, providers, routes and state remain. Proper names, place descriptions/highlights supplied by administrators, usernames, review comments, personal notes, support messages and itinerary titles are displayed verbatim. The packaged photos and HTTPS image handling are unchanged. Human review by fluent Sinhala/Tamil speakers remains advisable before submission.

## Verification and manual Android checklist

Automated Flutter tests use injected GPS/routing/repositories and HTTP mock responses, not live public routing/tile requests. The local `demo-heritagewalk` Firebase emulator security suite has 200 passing assertions, retaining all 164 previous checks and adding 36 group-location checks. Device smoke entry `tool/part9_device_smoke.dart` uses the real Android Geolocator plugin and one public routing request; it initializes no Firebase app and writes no production data. Emulator-injected location is development test input, not proof of a physical phone fix.

Run the normal verification commands:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
```

Manual physical-device checks still required:

1. Install the normal APK, launch, log in and verify restored profile, preferences and real catalog.
2. Home -> Explore -> Galle Fort -> Place Details -> Navigate. Confirm selected name, valid stored coordinates, actual current GPS marker, destination and road polyline. Check OSRM distance/ETA, pan, zoom and recenter.
3. Allow precise/approximate GPS; separately test first denial, permanent denial, device location disabled, temporary unavailable fix and timeout. Verify settings/retry recovery without a fake fallback.
4. Disable Internet: observe tile/route error handling and group unavailability/stale states. Restore connectivity and retry. Verify no false offline-map claim.
5. Start/end route guidance; move outside the 25-metre filter. Check marker updates and that the initial estimate is labelled accurately. Background/close the screen and confirm location updates stop.
6. Inspect all normal-user routes in English, Sinhala and Tamil, including login/register/reset/edit-profile, planning, favorites, saved itinerary, details, guide, review create/edit/delete, groups, emergency, language, support and About. Use a narrow phone, large text and a visible keyboard. Verify user/admin content remains unchanged.
7. Restart while signed in and verify the stored language is restored. Check review aggregates/ownership, moderation and all 17 packaged image choices remain functional.
8. With two authenticated test users on separate devices, create/join a group. Sharing must remain off until each explicitly starts it. Verify both live positions, movement, stop, leaving, deletion, signout, backgrounding and stale expiry. A nonmember/admin who is not a member must be denied location access. Prefer Firebase emulators for this test until production rules are reviewed/deployed.
9. Verify only active verified real emergency contacts are callable through `tel:`; inactive/unverified/placeholder contacts must not initiate a call. No CALL_PHONE permission is needed.

Production deployment is a separate reviewed step, **not executed here**:

```powershell
firebase deploy --only firestore:rules --project heritagewalk-sri-lanka
```

Existing production Part 8.2 rules will reject the new group-location operations until the reviewed Part 9 rules are deployed. Personal maps/GPS/routing and localization do not depend on that new rule path. See the final verification report for the exact test total, analysis/build results and file inventory.
