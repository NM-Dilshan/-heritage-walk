# Part 4: Navigation, digital guide, facilities and safety

Owner: N M S H Premarathna (IT23825550), navigation_guide module.

## Guide Notes: working local CRUD

- Create: Add Note opens a keyboard-safe dialog; Save requires non-empty text
  and a maximum of 500 characters. The service assigns an ID and timestamps.
- Read: My Notes displays only notes for the selected place ID. Notes remain
  available when revisiting that place within the current application session.
- Update: Edit Note pre-fills the existing text, validates it and updates the
  same record. createdAt is preserved; updatedAt changes.
- Delete: Delete Note requires confirmation. Cancel retains the note; Delete
  removes the record and refreshes the list immediately.

GuideNotesService is the single source of truth. GuideNote has map serialization
without Firebase imports. Notes are in memory, lost on restart and cleared on
confirmed logout. Persistent Firestore integration comes later.

## NavigationService

The Map tab opens NavigationScreen. Without a selected place it shows a
chooser using the existing DiscoveryService catalogue. Place Details and
Digital Guide pass the selected HeritagePlace directly through named routes.
Missing or incorrectly typed arguments on required-place routes show a safe
chooser rather than crashing. Existing routes are preserved.

MapPlaceholder is a schematic Flutter-painted illustration. There is no live
GPS, Google Maps key, Google Directions API, traffic or calculated street route.
The current-location marker is a demo marker; it is not the user's position.
NavigationService returns deterministic illustrative values (4.8 km, driving
15 minutes or walking 58 minutes) for UI testing, not measured travel estimates.
Mode/destination changes stop the active demo state. Start Demo Navigation and
End Navigation change real UI state, without device navigation or GPS movement.

## FacilityService

Search and filter methods operate on eight fictional records. Food combines
restaurant/cafe types; other filters cover restrooms, parking, medical, ATM and
police. Search and type filtering combine. Distances and open/closed status are
explicitly labeled demo information. These are not verified nearby services.
Directions shows an integration message, rather than a fake facility route.

## EmergencyService

The service provides four placeholder contact categories with null phone numbers.
No emergency numbers are invented or stored. The screen displays that verified
service data is not connected. Calling and Share My Location show deferred
integration feedback. No calls, coordinates, location access or permissions are
requested. Generic safety reminders follow the assignment's supplied wording.

## Place Details and Digital Guide

PlaceImage is reused with its honest placeholder label. Place Details uses the
existing FavoritesService and displays rating/review demo labels. Hours and fees
are shown as Not verified when missing. Visit duration is explicitly a demo
estimate. Model constructors and existing place data remain unchanged.

The guide provides overview, history, architectural significance, highlights and
visitor tips with expandable cards. Short historical introductions build on the
existing Part 3 descriptions, checked against [Sri Lanka Tourism's cultural
heritage page](https://www.srilanka.travel/cultural_heritage) and [UNESCO's Sri
Lanka listing](https://whc.unesco.org/en/statesparties/lk). Jaffna and Nine Arch
Bridge reuse their already documented short descriptions; no new detailed
historical assertions are introduced for those sites.

No local audio asset exists. DemoAudioGuide is UI-only, explicitly says no audio
is playing, and uses a local 60-second progress timer. Play/Pause work; timers are
cancelled on disposal and paused when the application leaves the foreground.
Guide navigation, nearby facilities and emergency-support actions are connected.
The existing Home place-preview sheet is retained; View Full Details now opens
the full PlaceDetailsScreen. The Map tab replaces its previous deferred message.

## Scope and verification

No packages, API keys, platform permissions or asset changes were introduced.
Parts 1-3 tests are retained; the two Part 3 assertions about deferred full details
and maps are updated to reflect the legitimate Part 4 navigation changes.
Part 4 tests cover screen flows, same-source favorites, safe route arguments,
route modes/start/end, notes CRUD/isolation, demo audio, facilities, emergency
feedback, logout state clearing, and small-screen/keyboard layouts.

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`,
and `flutter build apk --debug` from the project root.

## Deferred

Firebase/Firestore/Auth/Storage, actual maps/directions/geolocation/traffic,
verified service contacts and facilities, calls/location sharing, real audio,
licensed landmark photos, persistent offline guides, AI APIs, group tools,
language, Help/About and admin. Guide notes provide useful CRUD without adding
a second favorites/offline-save implementation. Part 5 is not implemented.
