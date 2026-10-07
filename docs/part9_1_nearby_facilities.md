# Part 9.1: Real nearby facilities

Completed 6 October 2026. Nearby Facilities now uses actual device GPS and OpenStreetMap data. The production static facility list, fictional distances, synthetic open/closed states and deferred Directions action have been removed. No new package, API key, billing account, Firebase service, Firestore collection/rule/index or deployment is introduced. Part 10 has not started.

## Architecture

Home -> Nearby Facilities is available directly from Quick Actions. Existing Place Details and Digital Guide entry points are preserved. A heritage argument remains accepted for route compatibility; discovery always searches around the **user's GPS fix**, not the heritage destination's coordinates.

`NearbyFacilityController` obtains a one-shot fix from the existing Part 9 `LocationService`. It requests the selected category from `NearbyFacilityService`; production injects `OverpassNearbyFacilityService`. There is no new GPS implementation or continuous GPS subscription. Hardware-free default harnesses explicitly report unavailable GPS/discovery; fixtures exist only under test support.

The screen distinguishes GPS loading, denial, permanent denial, services off, unavailable/timeout, query loading, genuine empty results, and network/server/rate-limit/malformed-response errors. Settings-return retries the location check. Refresh acquires a fresh fix and requests updated OSM data. Category/radius changes use the acquired search origin; text search filters names/addresses locally. Query generation checks discard obsolete responses after changes, backgrounding or disposal. An interrupted query is not reported as a successful empty result.

## Categories

Mappings are centralized in `FacilityCategory`:

| Category | OSM amenity tags |
| --- | --- |
| Hospital / Medical | hospital, clinic, doctors |
| Pharmacy | pharmacy |
| Police | police |
| ATM | atm |
| Restaurant / Food | restaurant, cafe, fast_food |
| Public Toilet | toilets |
| Fuel Station | fuel |
| Parking | parking |

Default radius: 5 km. Choices: 1, 2, 5 and 10 km. There is deliberately no unbounded all-category query. OSM facilities tagged differently from these mappings will not be discovered; expanding tags should be an explicit maintenance decision.

## Overpass and public-service responsibility

Endpoint: `https://overpass-api.de/api/interpreter`. An identifying HeritageWalk User-Agent accompanies HTTPS form POST requests. The query selects nodes, ways and relations (`nwr`) in the chosen radius and returns `out body center`; this retains node coordinates and supplies bounding-box centers for ways/relations. Centers are approximate facility positions, not verified entrances.

Example query shape (coordinates come from GPS, not a constant in production):

```text
[out:json][timeout:20][maxsize:16777216];
nwr(around:RADIUS,LATITUDE,LONGITUDE)["amenity"~"^(hospital|clinic|doctors)$"];
out body center;
```

The service applies a 25-second HTTP timeout, validates JSON structure and rejects incomplete responses carrying a server remark. HTTP 429, HTTP 504, other HTTP errors, transport errors and malformed data are distinct states. Invalid individual OSM elements are skipped. Responses larger than 4 MiB are rejected. A 16-entry in-memory cache expires after five minutes; identical in-flight requests are shared. Requests are serialized and separated by at least three seconds. HTTP 429 prevents further network requests during a cooldown (60-second default, numeric Retry-After bounded between 30 seconds and one day). There is no automatic retry storm or alternate-host quota bypass.

Requests occur on initial screen load, category/radius changes and explicit refresh/retry. Widget rebuilds, local text filtering, marker selection and map panning never query Overpass. Cache entries are cleared with the account/application session. A request already sent can finish after screen closure; its obsolete response cannot update that screen. Pending requests are not a background tracking loop.

The [Overpass operator's public-instance guidance](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html) describes shared resources, load shedding and rate limits. This default endpoint is for reasonable academic/light demonstrations and provides no unlimited production SLA. A broadly distributed tourism app should use an appropriately hosted or self-hosted Overpass instance, configured through the service's injectable endpoint. Existing [OSM tile usage requirements](https://operations.osmfoundation.org/policies/tiles/) still apply to the shared map. No paid map SDK or credit card is required for this academic architecture.

## Model, distance, map and routing

`NearbyFacility` holds a namespaced OSM ID (`node/…`, `way/…`, `relation/…`), category, latitude/longitude, proximity metres and optional name/address/phone/website/openingHours. Names and metadata come directly from OSM tags. Missing values remain null; the UI translates Unnamed facility and Address unavailable. It never invents a phone, address, website, hours or current open/closed status.

Proximity is a geographic distance computed with the existing `latlong2` distance implementation, sorted nearest first and filtered to the selected radius. Duplicate OSM type/ID entries are removed. It is explicitly labelled **direct approximate proximity**, not driving distance or ETA.

The existing HeritageMap shows the GPS search origin and facility markers, fits the results and preserves visible attribution. Tapping a marker selects the facility; View on Map selects/recenters it and scrolls to the map. The selected card offers Navigate. Up to 100 matching results/markers are displayed at once for mobile responsiveness, with an explicit limit message; local search can narrow the complete returned set.

`RouteDestination` is a generic coordinate contract. Existing HeritagePlace implements it without changing its serialized Firestore fields, identity or constructor. `FacilityDestination` adapts an OSM result. The existing Navigation screen/service accepts both, retains the catalog chooser and adds the current facility to the chooser without inserting it into the catalog. It acquires current GPS, calls the existing OSRM routing service and displays its actual polyline, distance and duration. Part 9's route-preview/live-GPS limitations remain: no voice/turn-by-turn, traffic-aware remaining estimate, automatic rerouting or offline routing is claimed.

## Privacy and emergency separation

Nearby search sends GPS coordinates and the chosen radius/category to Overpass; selected navigation sends coordinates to the existing routing provider. Provider logging is subject to their policies. Searches are transient application operations: no Firestore storage, user-profile attachment, persisted search history or location trail is added. The bounded cache is memory-only.

OSM hospitals, police and pharmacies are geographical listings, **not verified emergency contacts**. Any OSM phone is labelled unverified and has no Call action on facility cards. Existing Firestore/admin-managed emergency contacts, active/verified filtering and `tel:` launch behavior are untouched. Opening hours are shown as the source expression, without claiming that the facility is open now. OSM coverage and freshness vary; a missing result does not establish that a real-world service is absent.

## Localization

English, Sinhala and Tamil retain key/placeholder parity. Added 33 resources per locale and retired 22 obsolete demo-facility resources: **582 resources per locale**, 1,746 values total. Controls, categories, search/radius/status/error/proximity/selection strings and fallbacks are translated. Real OSM names, addresses, phone numbers, websites and opening-hour expressions stay verbatim. The About safety description now reflects real discovery. Existing `LanguageService` preference save/restore remains unchanged.

## Verification report

| Requested item | Result |
| --- | --- |
| 1. Files created | Five, listed below. |
| 2. Files modified | 23 task files, listed below; prior Part 9/user changes preserved. |
| 3. Categories | All eight categories above, including hospital/clinic/doctors and restaurant/cafe/fast_food grouping. |
| 4. Endpoint architecture | Injectable NearbyFacilityService; production HTTPS Overpass POST, bounded query/timeout/cache/rate handling. |
| 5. API key | Not required for nearby discovery/maps/routes. Existing Firebase configuration remains. |
| 6. Billing | No billing account, credit card, paid API, Storage, Cloud Functions or Blaze upgrade added. |
| 7. GPS reuse | Existing Part 9 LocationService; one-shot current fixes and settings/permission flow. |
| 8. Model | Real OSM identity/category/coordinates/proximity, optional source metadata; no fabricated missing fields. |
| 9. Distance | Direct geographic proximity for sorting; actual OSRM road/path distance/ETA on navigation. |
| 10. Map | Shared HeritageMap, current/facility markers, actual marker taps, selection, fit/recenter, attribution. |
| 11. Route integration | Generic destination adapter into existing Navigation/OSRM; no fake Firestore historical places. |
| 12. Localization | 33 additions and 22 demo-resource removals per locale; 582 matching resources in en/si/ta. |
| 13. Tests added | 64 new tests; existing demo-based Part 4 assertions adapted to isolated OSM-format fixtures, not deleted. |
| 14. Flutter total | **417 passed**: all original 353 retained + 64 new. |
| 15. Security total | **200 passed**, unchanged; demo Firebase Auth/Firestore emulators only. No rules change needed. |
| 16. Analysis | `flutter analyze`: **No issues found**. |
| 17. APK | Normal `flutter build apk --debug`: **success**, `build/app/outputs/flutter-apk/app-debug.apk`, 200,914,671 bytes. |
| 18. Physical tests | Checklist below remains to be performed on a physical phone. No physical GPS testing is claimed. |
| 19. Provider limits | Public Overpass/OSM are shared, network-dependent, rate-limited and have no production SLA; coverage/centers/hours are not guarantees. |
| 20. Demo removal | Production static facility records, fictional distance/open state and deferred Directions behavior removed. Test-only fixtures remain isolated. |

Commands completed:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
```

The automated suite uses fake GPS and fake/mock HTTP; it never requires a live public Overpass service. It covers all category tags, metadata/missing/unnamed cases, nodes/ways/relations, invalid coordinates, proximity/sorting/dedup/radius, GPS errors, HTTP errors/timeouts/malformed responses, cache/concurrent sharing/429 backoff/refresh, generation races, cancellation, map markers and actual marker taps, map selection/panning, facility -> existing navigation, unchanged catalog, Home entry, all locales and compact layouts at 320 pixels/1.4 text scaling.

A separate, **single bounded provider syntax check** at a fixed test point near Galle returned six real OSM elements (four nodes, two ways). This confirms endpoint/query response shape and is not presented as the user's GPS position or a physical-device flow.

Build completed in 85.2 seconds; APK SHA-256: `4B1B5E4859E7AA64DA7FC8C7DE5BBDF241E6E18AA50EF414F1C7E0AABC8E1DC7`. Existing Firebase Auth/Core plugins emitted the upstream Kotlin Gradle compatibility warning for future Flutter versions; the current build succeeds. Pub reports 12 newer package versions outside existing constraints; no dependency upgrade was needed. Firebase CLI emitted an optional missing VS Code notification-endpoint notice; all 200 assertions succeeded. No deployment was performed.

## Physical-phone checklist

1. Install the normal APK, launch and log in. From Home choose Nearby Facilities; also verify the existing Details/Guide entry points.
2. Allow precise/approximate GPS. Confirm the current marker matches the phone location and default Hospital / Medical search uses 5 km. No fake fallback may appear if a fix is unavailable.
3. Inspect real hospital/clinic results, then choose Pharmacy and confirm category/results change. Inspect Police, ATM, Food, Public Toilet, Fuel and Parking as local OSM coverage permits.
4. Change 1/2/5/10 km radius, check nearest ordering and the direct-proximity label. Search a real result by name/address. Pan/zoom the map without triggering new queries.
5. Tap a facility marker and View on Map. Verify selected name/coordinates and recenter. Choose Navigate; confirm the facility remains selected and the actual OSRM road/path polyline, distance and ETA load. Test walking/driving modes.
6. Turn GPS off, deny permission, permanently deny permission and return from settings. Check timeout/unavailable handling and recovery. Background/close during a pending search; no late UI updates or false empty-success message should appear.
7. Disable Internet and test refresh/error recovery; choose a category/region with no mapped results and verify the honest empty state. Respect Overpass busy/cooldown messages instead of repeatedly retrying.
8. Refresh after moving to confirm a fresh GPS fix and recalculated proximity. Missing addresses/hours/phone fields must not be fabricated. OSM phones must remain separate from verified Emergency Support contacts.
9. Inspect Sinhala and Tamil categories, radius, cards, errors and route fallback names on a narrow phone with large text and keyboard. Real facility names/metadata must remain unchanged; verify existing language persistence, reviews/images/groups/emergency flows still work.

## Files created

- `lib/features/navigation_guide/models/navigation_destination.dart`
- `lib/features/navigation_guide/services/nearby_facility_controller.dart`
- `test/part91_nearby_facilities_test.dart`
- `test/support/part91_fakes.dart`
- `docs/part9_1_nearby_facilities.md`

## Files modified

- `README.md`
- `assets/l10n/en.json`
- `assets/l10n/si.json`
- `assets/l10n/ta.json`
- `lib/core/firebase/app_services.dart`
- `lib/core/localization/messages.g.dart`
- `lib/core/routes/app_routes.dart`
- `lib/features/discovery_planning/models/heritage_place.dart`
- `lib/features/discovery_planning/screens/home_screen.dart`
- `lib/features/group_support/screens/about_screen.dart`
- `lib/features/navigation_guide/models/facility.dart`
- `lib/features/navigation_guide/models/route_info.dart`
- `lib/features/navigation_guide/screens/navigation_screen.dart`
- `lib/features/navigation_guide/screens/nearby_facilities_screen.dart`
- `lib/features/navigation_guide/services/facility_service.dart`
- `lib/features/navigation_guide/services/navigation_guide_scope.dart`
- `lib/features/navigation_guide/services/navigation_service.dart`
- `lib/features/navigation_guide/widgets/facility_card.dart`
- `lib/features/navigation_guide/widgets/heritage_map.dart`
- `lib/features/navigation_guide/widgets/route_summary_card.dart`
- `tool/part9_translations.tsv`
- `test/part4_navigation_guide_test.dart`
- `test/part4_services_test.dart`

No Firestore-rule or index modification is required for Part 9.1. No automatic deployment or Part 10 work was performed.
