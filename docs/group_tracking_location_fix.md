# Group Tracking location sharing fix

## Confirmed causes and scope

The client faults were reproduced locally. Production snapshots, deployed rules,
and two physical devices have not been inspected, so this report does not claim
that the reported production session has been reproduced on real hardware.

1. **Camera visibility:** Group Tracking supplied all fresh member markers but
   left `HeritageMap.fitMarkers` false. A map opened at A's position kept that
   camera when B arrived; flutter_map culled B when B was outside the viewport.
   A regression reproduces B being absent under the old map configuration and
   both markers being visible with group fitting enabled.
2. **Listener lifecycle:** the session subscribed only at construction/retry.
   Membership arriving later, or returning after membership loss, never restarted
   a cancelled/missing subscription. The regression expecting B's location after
   membership restoration failed before the fix, then passed.
3. **Coincident coordinates:** markers used identical screen anchors. Nearby
   members could cover each other's icons and labels. Group Tracking now opts
   into deterministic screen-space separation for overlapping marker footprints
   at the current map zoom, including small differences caused by GPS accuracy;
   saved coordinates and marker geographic points remain unchanged.
4. **Device clock sensitivity:** the two-minute stale filter compared server
   timestamps with device wall time, and the upload throttle also used wall time.
   Sharing sessions now calibrate from their acknowledged own server write and
   measure subsequent age/throttling with monotonic elapsed time. Tests exercise
   devices ten minutes ahead/behind, a subsequent clock jump, and old records.

The existing whole-collection listener, UID schema, and local member-read rules
were already correct. They were not replaced with a different architecture.

## Files changed by this task

- `lib/features/group_support/services/group_location_service.dart`
- `lib/features/group_support/screens/group_tracking_screen.dart`
- `lib/features/navigation_guide/widgets/heritage_map.dart`
- `test/group_tracking_regression_test.dart` (new)
- `test/firestore_rules_test.cjs`
- `docs/group_tracking_location_fix.md` (new)

No packages were added. Existing unrelated working-tree changes were preserved.
The shared map's new overlap option defaults to false; navigation/facility screens
retain their existing behavior. Group Tracking enables group fitting, a group
Recenter action, and overlap separation. The own marker says `You`; other markers
show the member's display name. Existing member details remain below the map.

## Persistence, subscriptions, and privacy

The only write path remains `groups/{groupId}/locations/{Firebase_UID}`. Each
document contains exactly `userId`, `displayName`, `latitude`, `longitude`, and
`updatedAt`. Writes continue using `FieldValue.serverTimestamp()` and overwrite
the current position; no history or new storage path was added.

The feed remains `groups/{groupId}/locations.snapshots(includeMetadataChanges:
true)`, covering the entire permitted collection. It now reconnects when valid
membership becomes available, tracks the subscribed UID, and rejects callbacks
from cancelled generations. Losing membership hides all positions immediately.
Stopping sharing cancels that session's GPS/heartbeat and removes only its own
UID document, while leaving the member-to-member read feed active.

The authenticated profile ID, member ID, document ID, and stored `userId` must
match Firebase UIDs. A location whose stored UID differs from its document ID is
discarded. The session filters against current group membership, rather than
keeping only the authenticated user's position. Demo-member entries are not real
Firebase members; two real users must join using the existing invite flow.

Cached snapshots are not presented as live positions. Pending local documents
and null/non-Timestamp values are excluded individually; a pending own write
does not suppress a confirmed peer. Metadata-only acknowledgement events allow
confirmed documents back into the feed. This follows the existing privacy policy
and [Firebase snapshot metadata guidance](https://firebase.google.com/docs/firestore/query-data/listen).
Timestamps are converted to UTC consistently.

After the first acknowledged own write, the session reads that own document with
`Source.server` to obtain a trusted time reference. This adds one document read
per successfully calibrated screen session, no additional writes. The clock
counts the entire write/read round trip, conservatively aging positions, then
advances monotonically. Receiving an old document never refreshes its age. The
two-minute expiry and future-timestamp rejection remain. Calibration failures
retry on a subsequent own write. A viewer who never shares has no acknowledged
own write to calibrate against and continues using device time; automatic device
date/time remains necessary in that viewing-only case or until calibration succeeds.

Debug-only, change-deduplicated diagnostics report authenticated UID, group ID,
member count, raw document count/UIDs, cache/pending metadata, parsed location
count, fresh marker count, and safe listener error codes. They omit credentials,
tokens, coordinates, and display names, and are disabled in release builds.

**firestore.rules changed by this task: NO.** Existing local rules permit group
members to read the collection, permit only own-UID writes with server timestamps,
reject spoofing and non-member/admin access, and permit own-document cleanup.
No Firebase rules or application changes were deployed to production.

## Automated verification

Twelve new Flutter regression tests cover metadata acknowledgement, late
membership, rejoining, old camera culling, both UID documents, bidirectional live
updates, independent stopping, unchanged B data when A updates, overlapping
markers, own/other labels, group Recenter, UID mismatch, outsiders, stale records,
UTC conversion, server-clock skew, monotonic expiry, and preservation of non-group
current-user recenter behavior. The real repository is
exercised with fake_cloud_firestore; metadata transitions use scoped SDK mocks.
These are automated client tests, not two authenticated physical devices.

The emulator suite preserves all 200 previous assertions and adds 12 checks:
both members querying both UID documents, A reading B's updated coordinate,
and A's stop/restart preserving B. Existing assertions cover non-member/admin
read rejection, UID spoofing, cross-member write/delete denial, malformed data,
server timestamps, departure, and group deletion.

Verification results:

- `dart format lib test`: 148 files, final pass zero changes.
- `flutter analyze`: no issues.
- `flutter test`: 504 passing (492 existing + 12 new).
- Local Auth/Firestore emulators, `demo-heritagewalk`: 212 assertions passing.
- `flutter build apk --debug`: passed; explicitly checked Flutter exit code 0.
  Final cached verification completed `assembleDebug` in 7.8 seconds.
  APK: `build/app/outputs/flutter-apk/app-debug.apk`, 205,021,764 bytes.
  SHA-256: `4515F55DC3C26C57A11BC446C045070FBB30CBF2C4395CFA1D8B471261CDFCDB`.

Nonfatal build warnings remain from Java/Gradle restricted native access and the
existing firebase_auth/firebase_core Kotlin Gradle Plugin migration notice.
No dependency/plugin upgrades were made as part of this tracking fix. The first
successful APK command's PowerShell wrapper reported warning output as an error;
the final build explicitly checked Flutter's native exit code and returned 0.
There are no unresolved analyzer, Flutter-test, security-test, or APK-build errors.

An initial emulator command was restarted after PowerShell argument handling;
its orphaned local demo process caused a port-8080 conflict on the first retry.
Only the verified task-owned demo emulator was stopped. The final emulator run
passed and its remaining task-owned process was cleaned up. No production data
was accessed or changed by these tests.

## Physical two-user checklist — still required

1. Device A: sign in as real user A. Device B: sign in as a different real user B.
   Confirm different authenticated UIDs in debug diagnostics.
2. A creates Group X; B joins using X's real invite code. Check both diagnostics
   show the **same group ID** and both UIDs are in membership. Do not substitute
   a demo member added by name for B's actual account.
3. Open Group Tracking on A and tap Start Sharing. Grant foreground location
   permission and keep the app foregrounded. Repeat on B in the same group.
4. In the Firebase console, verify both
   `groups/{groupId}/locations/{A_UID}` and
   `groups/{groupId}/locations/{B_UID}` exist with matching `userId`, valid
   coordinates, display names, and committed server `updatedAt` timestamps.
5. Verify both maps show A and B. Each device labels its own position `You`.
   Try both separated positions and identical/nearby positions. Pan away and
   use Recenter to restore the group view.
6. Move A with enough time for the ten-second upload throttle. B should receive
   A's new marker without refreshing. Repeat B moving while A observes.
7. Stop sharing on A: A's UID document should disappear and A's marker should
   disappear on B. B's document, marker, GPS stream, and consent remain active.
   A may continue seeing B as an authorized member without uploading itself.
8. Restart A, then leave the tracking screen/background the app; confirm A stops
   foreground sharing. No background location or trail should be stored.
9. Test a stale member record and device clock skew while both actively share.
   Confirm old positions expire rather than becoming fresh on receipt. Ensure
   viewing-only devices use automatic date/time as described above.
10. Use a third authenticated non-member: direct document and whole-collection
    reads must fail, including for a non-member admin. Member B must not be able
    to write/delete A's document or spoof A's UID.
11. If a physical client logs `permission-denied`, compare the **deployed** rules
    with the tested local rules and verify the actual group's `memberIds` and
    members map. Local emulator success does not establish that production rules
    match; any production deployment requires a separate authorized step.

Part 10 was not started. Unrelated authentication, routes, reviews, admin,
localization, and other Parts 1–9 functionality were not changed by this task.
