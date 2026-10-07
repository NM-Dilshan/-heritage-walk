# Map marker stability fix

## Root cause

`HeritageMap._markerAlignment` projected member positions into screen pixels,
classified overlap using a 130 x 70 pixel threshold, and changed marker alignment
when that classification changed with zoom. This moved the rendered symbol while
its saved LatLng stayed correct. A second offset came from centering the entire
130 x 70 label-and-icon column instead of anchoring the symbol itself.

Manual screen-pixel calculations existed for overlap/alignment; markers already
used MarkerLayer and real geographic points. Camera state never wrote GPS or
Firestore location state. The fault was visual anchoring.

## Implementation

- Removed camera-dependent overlap calculations and the associated group option.
- Every symbol is a 30 x 30 Marker with `point: m.position` directly.
- Current-location symbol: `Alignment.center`.
- Member and destination pins: `Alignment.topCenter`, which flutter_map defines
  as the widget above its point, anchoring the bottom center to the coordinate.
- Labels use a separate MarkerLayer at the same geographic coordinates. Label-only
  padding clears the icon, without moving its geographic anchor.
- Exactly coincident members have a shared column of individually tappable labels;
  their symbols intentionally retain the identical geographic point.
- Symbols/labels counter-rotate around their supported anchors.
- OSRM PolylineLayer still receives the original route points directly.
- Recenter retains camera-only current-user/group-fit behavior. “Fix the map”
  remains the OpenStreetMap correction link.

GPS, Firestore records/schema/rules, five-minute foreground sharing, two-minute
stale filtering, consent/start/stop behavior, routing, attribution and navigation
were not changed. No packages or map services were added. No deployment or Part 10.

## Files changed in this task

1. `lib/features/navigation_guide/widgets/heritage_map.dart`
2. `lib/features/group_support/screens/group_tracking_screen.dart`
3. `test/group_tracking_regression_test.dart`
4. `test/map_marker_stability_test.dart` (new)
5. `docs/map_marker_stability_fix.md` (this report)

The existing coincident-member regression now verifies identical geographic
anchors rather than requiring visually displaced icons. Its labels, distinct
member records, incoming GPS updates and group-recenter checks remain.

## Automated regressions

Four new widget tests verify direct LatLng identity and symbol construction,
center/bottom anchors against flutter_map's actual geographic projection at
zoom 7/10/13/16/18, pan and rotation, camera-only recenter, unchanged route points,
and separation of labels from symbol bounds. They compare geometry/model state,
not screenshots. Existing sharing lifecycle and security tests are preserved.

## Manual device verification (pending)

Automated widget tests use fixed coordinate 6.032, 80.218. A physical-device
OpenStreetMap/OSRM check has not been performed for this change:

1. Use a fixed current GPS coordinate 6.032, 80.218; a stationary second member;
   and a fixed destination. Display a real OSRM route between the endpoints.
2. Zoom 7 -> 10 -> 13 -> 16 -> 18, then pan in every direction and recenter.
3. Check that the blue symbol center and red pin bottom anchors stay attached to
   the same road/ground points and route endpoints as tiles move beneath them.
4. Confirm stored GPS/Firestore coordinates do not change from camera gestures.
5. Put two members at the same coordinate: both names remain readable and their
   geographic anchors coincide; no artificial location displacement occurs.
6. Navigate away/back while sharing; verify the existing five-minute deadline,
   background stop, manual stop, and two-minute stale filtering remain intact.

## Verification results

- `dart format lib test`: 150 files; final pass changed 0 files.
- `flutter analyze`: no issues, exit 0 (112.5 seconds).
- Targeted map/tracking regression run: 16 tests passed, exit 0.
- `flutter test`: all 523 tests passed, exit 0 (519 existing + 4 new).
  This includes the existing 15 sharing lifecycle regressions.
- `flutter build apk --debug`: success, exit 0; assembleDebug 49.7 seconds.
  Output: `build/app/outputs/flutter-apk/app-debug.apk`.
- Existing nonfatal build warnings: Java/Gradle restricted native access and
  firebase_auth/firebase_core Kotlin Gradle Plugin migration advisory.
- Firestore security tests/rules were not modified; their emulator suite was
  not rerun for this visual-only change. No Firebase deployment is required.
- Physical-device/manual tile verification remains pending; no claim of a
  completed real-device GPS/OSRM check is made.
