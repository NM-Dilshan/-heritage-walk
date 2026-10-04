# Part 2: Account authentication and profile CRUD

This is the Part 2 implementation snapshot. Part 3 now connects normal login/registration to Home, and connects profile saved-content menus. See [Part 3 documentation](part3_discovery_planning_crud.md) for the current integrated navigation.

Owner: W A N M Dilshan (IT23839410), auth_profile module.

**Part 2 uses local in-memory state. Persistent Firebase CRUD will be connected during backend integration.**

## Working operations

- Create: valid registration creates a temporary session profile with a session ID,
  full name and email. Passwords are validated in the form and never stored.
- Read: the authenticated placeholder links to My Profile. ProfileService exposes
  the session profile; Edit Profile reads and pre-fills its fields.
- Update: Save Changes validates and updates name, email, phone and bio, then
  returns to My Profile. Name/email refresh immediately through ProfileScope.
- Photo removal: Remove Photo changes the editor draft; Save Changes commits
  removal. Cancel/back leaves the stored profile unchanged. Initials are the fallback.
- Logout: confirmation clears the authenticated navigation stack and resets the
  in-memory profile to demo defaults. This is not a persistent account deletion.

## Demo authentication

Startup is Splash -> Login after two seconds. Valid email and a password of six
or more characters simulate sign-in; credentials are not verified against an
account database. Login updates the session email. Registration creates a fresh
profile. Both clear the unauthenticated history and open the temporary success
screen. Sign-out clears authenticated history. All data is lost on app restart.

Password reset validates an email and simulates a request; no email is sent.
Social buttons show a backend-integration message. Gallery/camera show a device-
integration message; no device access or filesystem paths are created.

## Validation and UX

Forms have labeled fields, password visibility, loading/disabled actions and
scrolling with keyboard resizing. Phone is optional and accepts common spacing,
parentheses, hyphens and a leading plus (7-15 digits). Bio is limited to 150
characters with a count. Invalid entries show field errors. Async actions check
mounted state and splash cancels its timer on disposal.

## Deferred

Persistent account creation/read/update/delete, actual authentication, password
reset emails, Firebase/Firestore/Storage, social providers, and camera/gallery.
Other members' modules remain unimplemented. Profile menus and bottom navigation
for those modules display a later-module message. The foundation preview remains
available at `/` for development; normal startup uses `/splash`.

## Verification

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`,
and `flutter build apk --debug` from the project directory.

