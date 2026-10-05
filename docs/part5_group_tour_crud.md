# Part 5: Group tours, management and demo tracking

Owner: R D I H Rajapaksha (IT23841772), group_support module.

Two assigned main screens: Group Tours and Group Tracking. Create New Group
and Group Management are supporting child screens, not additional assigned UIs.

## Group CRUD

- Create: validates a non-empty name (maximum 60 characters) and a destination
  selected from DiscoveryService. The current ProfileService user becomes the
  leader and first member. Unique session IDs and HW-prefixed invite codes are
  allocated by a monotonic sequence, without randomness or a backend.
- Read: My Groups lists groups containing the current user. Open Group shows the
  live shared record, invite code, leader, destination and members.
- Update: leaders can rename the group and change its destination. Group cards,
  management and tracking read the same service, so changes appear immediately.
- Delete: leaders confirm removal from the current session; the list refreshes,
  the deleted group and code become unavailable, and success feedback appears.

GroupTourService is the single source of truth. Ownership checks apply in the
service as well as the UI. Members cannot rename/delete groups, change their
landing destination or manage other members. Profile edits synchronize the
current user's member/leader name through the existing ProfileService listener.

## Member operations

- Add: the leader enters a validated name to add a local demo member, without
  sending a real invitation. IDs remain unique even when names match.
- Read: member cards show initials, leader status, online/offline demo status,
  sharing state and a timestamp labeled as a demo update.
- Update: current users toggle only their own demo sharing state. Current users
  start with sharing off; the UI does not request permissions or access GPS.
- Remove: leaders confirm removal of non-leader members. The service rejects
  removal of the leader through the normal remove operation.

## Invite codes

Join with Code validates the input and resolves a code in the running service.
Codes are trimmed and case-insensitive. Invalid codes show an error. Joining
adds the current profile once, identified by profile ID; repeated joining does
not duplicate membership. Copy uses Flutter's built-in Clipboard API.

Codes work only inside the current running app session. There is no cross-device
synchronization, messaging, persistent invitation database or real user discovery.
The UI initially has no groups. Demo groups can be created using the same normal
flow; no hard-coded person is substituted for the current user.

## Demo group tracking

GroupMapPlaceholder shows destination, leader and member symbols on a schematic
map background. Only sharing members have markers. relativeX/relativeY are
normalized UI positions, not latitude/longitude or real geographic locations.
Refresh changes sharing-member positions by deterministic bounded increments
and updates timestamps. Members with sharing off stay hidden and stationary.
There are no continuous timers, background updates, live GPS, real coordinates,
location permissions or Google Maps dependencies.

View Destination passes the existing HeritagePlace to Part 4 Place Details.
Navigate passes it to the existing Part 4 demo Navigation screen. Neither place
data nor navigation implementation is duplicated.

## Navigation and lifetime

Home has a small Group Tours quick action; Profile has a Group Tours menu entry.
The five-item bottom navigation is unchanged. Routes are /group-tours,
/create-group, /group-details and /group-tracking. The older /group-tour constant
remains a working alias. Group detail/tracking routes accept an ID or TourGroup
and resolve the live service record; missing/deleted/non-member groups show a
safe unavailable state. Creation replaces the child form with management.

Group/member models have map serialization and immutable member lists without
Firebase imports. All group state is in memory, is cleared on logout, and is lost
on app restart. Firebase, persistent real-time integration and cross-device
joining are deferred. Existing favorites, itineraries, guides and routes are
preserved.

## Verification

Part 5 widget tests cover empty/create/leader flows, invite validation and joins,
rename, destination changes, member management, clipboard, tracking controls,
refresh, cross-module links, delete, Home/Profile entry points, safe missing
routes, small-phone/keyboard layouts and logout. Service tests cover permissions,
unique codes, immutable models, serialization and profile synchronization.
Parts 1-4 tests are retained.

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`,
and `flutter build apk --debug` from the project root.

## Deferred / Part 6 boundary

Language Selection, Help & Support and About remain deferred. No Firebase,
Firestore, storage, messaging, maps, GPS, background location, real invitations,
real-time member tracking or additional packages are introduced in Part 5.
