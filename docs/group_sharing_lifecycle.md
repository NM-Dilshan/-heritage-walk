# Five-minute foreground group sharing

## Root cause and ownership change

`GroupTrackingScreen` constructed and owned `GroupLocationSession`. Its `dispose`
disposed the session, which cancelled GPS and removed the own location document.
The destination/navigation actions also explicitly stopped sharing. The original
screen-disposal regression failed with one GPS cancellation where zero was
expected; it passes with service ownership.

`GroupTourService.sharing` now owns `GroupLocationSharingController` for the app's
authenticated session. A screen acquires/releases a UI lease on a group session.
Releasing the last screen preserves a sharing or starting session; it releases
an idle session's feed/timer resources. Returning acquires the same active session,
so its GPS stream and original deadline are reused. Changing the tracking widget's
group ID rebinds its view without reassigning existing sharing.

Only an explicit Start can select a publishing group. Starts are guarded against
repeated/concurrent taps. Starting Y while X is active stops/cleans X before Y can
start. Membership and authenticated UID changes invalidate the old session and
late GPS callbacks. There is at most one group-sharing GPS stream per app user.

The app root owns the lifecycle observer. Home, Explore, destination, navigation,
and other ordinary route changes do not stop sharing. Background/hidden/detached
transitions stop sharing; inactive also stops an already-sharing session. The
permission dialog's inactive transition does not cancel an unstarted GPS request.
Resume reconciles the monotonic deadline and never automatically starts sharing.

## Exact expiry and cleanup

The first successful own-document write calls `_beginSharingWindow()`, recording
the monotonic start tick and observable `sharingStartedAt`/`sharingExpiresAt`.
It creates `Timer(const Duration(minutes: 5), ...)` to call Stop. Returning to the
screen or repeated Start taps during sharing do not replace this timer.

The publish entry point and queued writer both check the monotonic five-minute
deadline, preventing late uploads if timer delivery is delayed. Resume checks it
too. Manual Stop/expiry immediately mark sharing OFF, invalidate pending fixes,
cancel GPS, heartbeat and expiry timers, and queue removal of the captured own UID
after any already-running write. No automatic restart occurs. A new five-minute
window requires another explicit Start.

`ProfileService.beforeSignOut` invokes the sharing owner's cleanup **before** the
existing Firebase sign-out operation, while that UID is still authorized to delete
its document. Login/provider implementations remain unchanged. Group departure or
deletion stops the session using the existing membership listener. A different
authenticated UID cannot inherit consent or receive writes from old callbacks.

An externally revoked/replaced credential or lost connection can prevent deletion
of an old UID document. GPS and publishing still stop; the existing stale-position
filter provides the fallback. Killing/force-stopping the app cannot guarantee an
immediate delete or continuous uploads. Sharing is not persisted across process
restart, and surviving positions are subject to the existing two-minute stale
filter. No background service, notification or background permission was added.

## Firestore, UI, and security

The path remains `groups/{groupId}/locations/{uid}`. The schema remains exactly
`userId`, `displayName`, `latitude`, `longitude`, and server `updatedAt`. Writes
overwrite the current position using `FieldValue.serverTimestamp()`; no history,
new collection, or background tracking was added. Whole-group snapshot listening,
Firebase UID ownership, coordinate/member validation, own/other markers, and the
two-minute stale filter remain in place. Stop removes only the captured own UID.

The same HeritageWalk layout now displays `Sharing ON`/`Sharing OFF`. The privacy
sentence accurately explains that sharing continues across screens for up to five
minutes and stops when the app leaves the foreground. Only these three sharing
strings changed in English, Sinhala and Tamil; all 595 resources per locale and
unrelated translations remain. No countdown or unrelated screen redesign was added.

**Background permissions/services added: NO.**
**firestore.rules changed: NO.**
**Production deployment performed: NO.**
**Packages added: NONE.**

## Exact files changed by this task

1. `lib/features/group_support/services/group_location_service.dart`
2. `lib/features/group_support/services/group_tour_service.dart`
3. `lib/features/group_support/screens/group_tracking_screen.dart`
4. `lib/core/firebase/app_services.dart`
5. `lib/features/auth_profile/services/profile_service.dart`
6. `lib/main.dart`
7. `tool/part9_translations.tsv`
8. `assets/l10n/en.json`
9. `assets/l10n/si.json`
10. `assets/l10n/ta.json`
11. `lib/core/localization/messages.g.dart`
12. `test/part5_group_tour_test.dart` — only three updated sharing-label assertions.
13. `test/group_sharing_lifecycle_test.dart` — new regression suite.
14. `docs/group_sharing_lifecycle.md` — this report.

Existing unrelated working-tree changes were preserved. The shared map,
authentication provider flows, nearby facilities, reviews, admin, and other
Parts 1–9 features were not modified by this lifecycle task. Part 10 was not started.

## Automated verification

Fifteen new regressions cover Start, navigation/screen disposal, updates after
disposal, A reaching B from Home/Explore, returning ON without another stream or
deadline extension, correct active group, explicit X-to-Y switching, widget group
rebinding, immediate Stop and own-only deletion, cancelled old timers, exact
five-minute expiry, preserving B, no automatic restart, group leave/deletion,
authenticated logout cleanup, external UID replacement, off-screen app lifecycle,
late permission results, delayed-timer reconciliation, stale/outsider filtering,
and unchanged foreground-only permissions. Timer tests advance the widget test's
fake clock; no test waits five real minutes. Root-zone cancellation futures are
flushed separately without advancing that simulated clock.

All 504 existing tests remain, including the previous two-user location/marker
regressions. The earlier tracking UI test retains its behavior checks with the
three new ON/OFF label expectations.

Verification results:

- `dart format lib test`: 149 files; final pass zero changes.
- `flutter analyze`: no issues; final run with resolved dependencies took 11.4s.
- `flutter test`: **519 tests passing** (504 existing + 15 new), exit code 0.
- Local Auth/Firestore emulators, `demo-heritagewalk`: **212 security assertions
  passing**, exit code 0. The security test file and rules are unchanged.
- `flutter build apk --debug`: **passed**, Flutter exit code 0; `assembleDebug`
  completed in 196.9s.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, **205,044,990 bytes**.
  SHA-256: `CD0E24A4C0C2A6A8250C62377E737D8FEBD7A8764F8B689700E16CB9B9A9D87C`.

No production data was touched by these tests. The demo emulator was cleaned up
after the successful run. There are no unresolved analysis, test, security-suite,
or APK-build errors. Nonfatal build warnings remain from Java/Gradle native access
and the existing firebase_auth/firebase_core Kotlin Gradle Plugin migration
notice. No unrelated dependency upgrades were made.

## Required physical two-phone test — not yet performed

1. **Phone A:** sign in as User A, join Group X, open Group Tracking, tap Start
   Sharing, and grant foreground location permission.
2. **Phone B:** sign in as a different User B, join the **same Group X**, open
   Group Tracking, and tap Start Sharing. Confirm both maps show A and B.
3. Verify both existing Firestore documents:
   `groups/{groupId}/locations/{A_UID}` and
   `groups/{groupId}/locations/{B_UID}`, each with matching `userId` and committed
   server `updatedAt`. Use real joined users, not demo members added by name.
4. **Phone A:** navigate from Group Tracking to Home without pressing Stop.
   Keep the app open/foreground; move/wait for the existing ten-second throttle.
   **Phone B:** remain on Group Tracking. Verify B continues receiving A's new
   position without refreshing. Repeat A visiting Explore.
5. Return A to Group Tracking **before five minutes**. Verify Sharing ON,
   the same original expiry, and no second GPS stream. Confirm both markers still
   appear, including when positions are close/identical.
6. Press Stop on A. A should immediately show OFF; only A's document/marker should
   disappear. B remains sharing and visible. Confirm no later A GPS update appears.
7. Explicitly Start A again; keep A foreground and navigate to Home. At five
   minutes from the successful first write, verify automatic OFF, A's document
   removed, and A absent on B. If B's independent session also expires, restart B
   later so it remains active while observing A's expiry.
8. Return A after expiry: OFF, no automatic restart. Another session requires Start.
9. Test A leaving Group X, group deletion, and logout while off-screen. Confirm
   publishing stops and own-document cleanup is attempted. Verify a different
   signed-in user cannot inherit A's session.
10. Background A: sharing should stop. Resume: OFF. Force-stop/relaunch: OFF; do
    not expect uninterrupted uploads or immediate cleanup while the process is
    killed. Check stale-marker fallback when disconnected.
11. Confirm a non-member cannot read Group X locations and a member cannot
    write/spoof another UID. Compare deployed rules with tested local rules if a
    physical client logs permission-denied; this task does not deploy rules.
