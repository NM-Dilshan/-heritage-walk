# Part 9.2 — Authentication upgrade

Verification date: 2026-10-07 (Asia/Colombo). This extends the existing Firebase account repository, ProfileService, auth gate and Parts 1–9.1 services. Part 10 is not started. No production Firebase deployment or account/data mutation was performed during verification.

## Implementation

Login and Register share `SocialAuthButtons` → `ProfileService.signInSocial` → the existing `FirebaseAccountRepository`, with an injectable `SocialCredentialSource` for the native account chooser. Email/password methods, validators, scopes, navigation, themes and Firebase auth-state restoration remain in place. The memory preview cannot open real social authentication or claim to send email.

Google uses installed `google_sign_in` 7.2.0: initialize the singleton once, `authenticate()`, read the synchronous `account.authentication.idToken`, create `GoogleAuthProvider.credential(idToken: ...)`, then `FirebaseAuth.signInWithCredential`. It requests no unrelated Google API scopes. Cancellation returns without Firebase exchange, profile writes or Home navigation.

Facebook uses installed `flutter_facebook_auth` 7.2.0: `login(permissions: ['email', 'public_profile'])`, inspect `LoginStatus`, read `accessToken.tokenString`, and exchange `FacebookAuthProvider.credential` with Firebase. Native setup is checked before attempting the provider. Missing configuration produces a localized setup message. **Facebook code is complete; real Meta/Firebase configuration and physical login are not verified.**

The Firebase repository ensures the existing `users/{uid}` schema using a read/create transaction. A new profile contains `id`, `uid`, `fullName`, `email`, `phone`, `bio`, `photoPath`, `role=user`, and server `createdAt`/`updatedAt`. Missing name/email become empty strings and missing photo is null. Provider identity never grants admin. An existing document is returned without writes, preserving its role, custom profile fields, timestamps, additional fields and all private subcollections/group/review data.

Profile photos reuse `photoPath`: HTTPS provider photos render through `Image.network`, asset photos retain `Image.asset`, and missing/broken images use existing initials or `?`. No provider information is translated. Image accessibility labels are localized.

Account/provider collisions show localized guidance to use the existing sign-in method. No UID merging, cross-UID copying, account deletion or automatic credential linking is implemented. Firebase may apply its own documented trusted-provider behavior; authorization still follows the resulting Firebase UID. Any future explicit linking must authenticate the existing user and use Firebase linking/reauthentication APIs.

The service blocks competing social, email/password and reset operations. Widgets disable competing buttons/fields and show the active provider's loading state. Cancellation/error/success reset controls. Home is entered only after Firebase credential exchange, profile retrieval and the existing session/data initialization. Profile initialization failure clears the partial Firebase session. Firebase auth-state restoration remains the source of truth; no extra persistent provider flags exist.

Logout captures the Firebase user's provider IDs, clears Firebase, then clears local Google/Facebook state. Google uses `signOut`, not `disconnect`; a restored Google session initializes the SDK before clearing its local credential state. Facebook uses `logOut`. Optional provider cleanup failure cannot retain the Firebase session or block local logout. Ordinary logout does not revoke the user's entire provider account authorization.

Forgot Password reuses the existing responsive dialog. Validation rejects empty/malformed email before Firebase; valid input is trimmed and passed to `sendPasswordResetEmail`. It prevents duplicate submits, disables dismissal during sending, shows friendly localized network/rate-limit/unexpected errors inline and allows retry/back to Login. Only success produces a neutral inbox/spam notice. Legacy `user-not-found` is deliberately normalized to the same privacy-preserving response; no account/provider enumeration is performed. Google/Facebook passwords must be recovered with those providers. Firebase handles action codes, reset links and new-password validation; no custom reset database/tokens/OTP exist.

## Google configuration checked

The user's updated root `google-services.json` matched `heritagewalk-sri-lanka` and `lk.heritagewalk.heritage_walk`, and contained Android (type 1) and web/server (type 3) OAuth clients. The Android build's previous `android/app/google-services.json` contained no OAuth clients; the supplied updated file was copied there. FlutterFire Android app identity remains unchanged; `firebase_options.dart` and `main.dart` required no modification.

The actual local debug keystore certificate SHA-1 is `38:4D:C1:4F:7D:94:95:E4:B3:EF:A6:49:63:7E:5A:47:11:D7:59:C4`. It matches the Android OAuth certificate hash in the supplied JSON. The user reports Google enabled and SHA-1 added in Firebase Console; console settings and a physical account chooser/login have not been independently verified. Register the actual release/Play app-signing SHA-1/SHA-256 separately when using those signing certificates; do not assume this debug fingerprint applies to them. Re-download configuration after any OAuth client change.

## Required Meta/Firebase manual configuration

1. In [Meta for Developers](https://developers.facebook.com/), create/select the application's real Meta app and configure the **Facebook Login / authenticate users** use case/product available for that app. Complete required app details, privacy policy/data deletion settings and permissions/review before public use. Development-mode login generally needs an app-role/test account; do not claim all public users can log in until Meta's live/review requirements are met.
2. Add the Android platform. Package: `lk.heritagewalk.heritage_walk`. Activity: `lk.heritagewalk.heritage_walk.MainActivity`. Use the application's actual package/platform settings; do not invent a Play Store listing.
3. Add the signing key hashes in Meta Android settings. The **computed local debug key hash** is `OE3BT32UleSz76ZJY35aRxHXWcQ=`. It is Base64(SHA-1(actual X.509 debug signing certificate)), not a sample value. For release/Play signing, export that actual certificate and compute its own hash. SHA-1 hex and Base64 key hash are different encodings, so do not paste the colon-separated fingerprint into Meta's key-hash field.
4. Obtain the real Meta App ID and client token from the app dashboard/settings. Client token is client configuration; **App Secret is a server-side secret and must never enter this repo, APK, Dart, manifest, generated strings or `google-services.json`.**
5. In Firebase Console → Authentication → Sign-in method → Facebook, enable the provider using the real App ID and App Secret **only in Firebase Console**. Copy the **exact OAuth redirect URI displayed by Firebase**, then add that URI to the Meta Facebook Login product's valid OAuth redirect URIs. No guessed redirect URI is inserted by this implementation.
6. Append these two keys to the existing ignored `android/local.properties`, preserving existing Flutter/SDK settings, and fill them with the real values:

   ```properties
   heritagewalk.facebook.appId=
   heritagewalk.facebook.clientToken=
   ```

   Leaving either blank keeps Facebook unavailable. Do not fill them with example/fake credentials. Do not add an App Secret property. `android/.gitignore` already excludes this file.

7. `android/app/build.gradle.kts` validates a numeric nonempty App ID and nonempty client token, generates `facebook_app_id`, `facebook_client_token`, `facebook_login_protocol_scheme=fb<real App ID>` and `facebook_configured`. The existing manifest uses these resources for SDK metadata, FacebookActivity and CustomTabActivity. The native configuration channel reads the same generated boolean, so Dart and Android cannot disagree through a separate `--dart-define`. Automatic app-event logging and advertiser-ID collection are disabled. No extra SDK dependency should be manually added: the installed plugin provides the Android Facebook SDK.
8. Rebuild `flutter build apk --debug`, install the new APK, and perform the physical Facebook checks below. A rebuild is required after native configuration changes; hot reload cannot apply resource/manifest settings.

These steps follow the installed package's [7.x Android configuration](https://facebook.meedu.app/docs/7.x.x/android/) and [Firebase federated-authentication guidance](https://firebase.google.com/docs/auth/flutter/federated-auth). Current Google API details are in the official [google_sign_in package](https://pub.dev/packages/google_sign_in) and [migration guide](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md). Account reset privacy follows [Google's enumeration-protection guidance](https://docs.cloud.google.com/identity-platform/docs/admin/email-enumeration-protection). Enable/retain enumeration protection in the console; this task does not change production security settings.

## Manual physical-device acceptance

**Forgot Password:** install the latest APK; open Login → Forgot Password; use a real Email/Password account; submit once; confirm neutral success; inspect inbox/spam; open Firebase's email action link; set a new password; return and log in with it. Also verify empty/malformed email, airplane mode/network failure, rate-limit messaging if encountered, repeated submit/back behavior and both localized layouts. Do not use this flow to reset Google/Facebook passwords. Email delivery and changing a real password are not performed by automated tests.

**Google:** on a physical Android phone with Google Play services, tap Google; cancel once and verify Login remains; retry/select account; confirm Firebase Auth user and Home; inspect `users/{uid}` (`role=user` for a new UID); confirm Profile data/photo/fallback; save a favorite/note/itinerary; restart and confirm Firebase session restoration; logout; sign in again and confirm the same UID/data. Test a verified existing admin without changing its role, a provider collision, offline/failure/retry, and account chooser after logout. Automated tests use mock SDKs and cannot verify OAuth consent/console configuration.

**Facebook:** only after completing the real Meta/Firebase setup, confirm Facebook is visible and Apple absent; cancel once, then complete a permitted Meta-account login; confirm Firebase Auth user, Home, profile and `users/{uid}` with `role=user`; save private data; restart; verify restoration; logout; sign in again and verify the same UID/data. Test missing email/photo, failure/offline/retry, existing admin preservation and provider collision. Physical Facebook success remains unverified until these steps pass.

## Verification report

| Required report item | Result |
| --- | --- |
| 1. Files created | Seven files: `lib/core/firebase/social_auth.dart`, `lib/features/auth_profile/widgets/social_auth_buttons.dart`, `test/part92_auth_upgrade_test.dart`, `assets/branding/google_sign_in.png`, `assets/branding/facebook_sign_in.png`, `tool/part92_translations.tsv`, this report. |
| 2. Files modified | 22 files listed below. Existing unrelated Part 1–9.1 changes remain intact. The user's root Google JSON is retained untouched as the source configuration. |
| 3. Packages added | Runtime: `google_sign_in` **7.2.0**, `flutter_facebook_auth` **7.2.0**. Test-only: `mocktail` **1.0.5**, `fake_cloud_firestore` **4.3.0**. Compatible transitive dependencies are listed below and locked. Existing Firebase Core/Auth/Firestore versions remain unchanged. |
| 4. Email/Password status | Existing Firebase login and validation retained; regression tests pass. |
| 5. Forgot Password | Firebase reset API, email validation, concurrency protection, inline friendly failures, neutral privacy notice, inbox/spam guidance, provider recovery scope, retry/back behavior implemented. |
| 6. Google | Current initialize/authenticate/ID-token API → Firebase credential → existing profile/session flow implemented and mocked end to end. |
| 7. Facebook | Current LoginStatus/tokenString API → Firebase credential → existing profile/session flow implemented. Real setup remains required; missing config is gated safely. |
| 8. Apple | Placeholder button and deferred-social helper removed. Unused Apple/old Google-registration/deferred-social resources retired. No Apple-specific dependency existed to remove. |
| 9. Architecture | Existing AccountRepository/ProfileService preserved; optional social repository capability and injectable native SDK source added. Login/Register use the same shared provider methods/widget. |
| 10. First social login | Atomic existing-schema read/create transaction after Firebase authentication. Available provider fields used; missing fields tolerated. |
| 11. New role | Always `user`; no name/domain/provider-based role condition. |
| 12. Admin protection | Existing profile never rewritten; `admin` role preserved. Existing trusted role controller and Firestore authorization remain in force. |
| 13. Data preservation | Existing profile fields/timestamps/extras and per-UID data are not replaced. Private subcollection preservation, repeat-login behavior and existing regression persistence tests pass. |
| 14. Collisions | Friendly existing-method/secure-verification guidance. No manual merging, UID copying, deletion or insecure auto-linking. |
| 15. Images | Optional HTTPS photo, asset support, initials/unknown-user fallback, image-failure fallback; tests pass. |
| 16. Restoration | Existing Firebase listener/ready/auth gate retained; fresh-service social-session restoration tests pass. |
| 17. Logout | Firebase first, then local provider cleanup; no Google disconnect or Facebook authorization revoke. Restored Google-session cleanup is tested without a chooser. |
| 18. Localization | **16 new resources**, three unused resources retired; **595 resources per locale**, English/Sinhala/Tamil parity. Compact localized Login/Register/reset tests pass. |
| 19. Tests added | **73** new tests covering the production Firebase repository with fake Firestore, mocked native provider SDKs, reset dialogs, failures/cancellation, concurrency, missing info, roles/data, restoration/logout, avatars and localization. The old Part 2 test was adapted to the new preview/reset messages, not deleted. |
| 20. Total Flutter tests | **490 passed = all 417 existing + 73 new**, zero failures. |
| 21. Security assertions | **200 passed** on only local `demo-heritagewalk` Auth/Firestore emulators, exit 0. No production deployment/data access. |
| 22. Analysis | `flutter analyze --no-pub`: **No issues found**, exit 0. |
| 23. APK | Final normal-main debug build **successful**, exit 0; final Gradle assembly 904.6 seconds under host resource pressure. |
| 24. APK path | `build/app/outputs/flutter-apk/app-debug.apk` (**205,012,183 bytes**). SHA-256: `F52C7F18AFE8DBD9C1677CB9736D0D3D33F22C5106806A4FB4340CC4E267C0FE`. |
| 25. Rules changed | **NO Part 9.2 rule modifications.** Pre-existing Part 9 rules remain unchanged by this task. No rule deployment. |
| 26. Google manual setup | Updated matching Android/server OAuth JSON installed in the Android app folder; actual debug SHA-1 matches. Provider enabled/SHA added are user-reported console actions. Physical chooser/login still pending. |
| 27. Facebook setup remaining | Real Meta app/use case, Android platform/key hashes, real App ID/client token in ignored local properties, Firebase Facebook App ID/App Secret, exact console redirect URI in Meta, review/live/test-user settings, rebuild/install. Detailed steps above. |
| 28. Reset physical test | Real email delivery, inbox action link and new-password login **pending**. No real reset emails sent in automation. |
| 29. Google physical test | Real chooser/consent, Firebase account/profile, persistence/restart/logout/re-login **pending**. |
| 30. Facebook physical test | Real setup and login/profile/persistence/restart/logout/re-login **pending**. Code-level mocks do not verify Meta console or a real token. |
| 31. Limitations | Social adapters currently target the configured Android app. Other platforms need their own Firebase/provider config/flows. Explicit linking/account deletion are outside scope. Optional provider cleanup is best-effort, with Firebase logout authoritative. No new Google Maps/paid maps introduced. |

Modified files (Part 9.2 only):

```text
README.md
android/app/build.gradle.kts
android/app/google-services.json
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/lk/heritagewalk/heritage_walk/MainActivity.kt
assets/l10n/en.json
assets/l10n/si.json
assets/l10n/ta.json
lib/core/firebase/account_repository.dart
lib/core/firebase/backend_error.dart
lib/core/localization/messages.g.dart
lib/features/auth_profile/screens/login_screen.dart
lib/features/auth_profile/screens/register_screen.dart
lib/features/auth_profile/services/profile_service.dart
lib/features/auth_profile/widgets/auth_form_layout.dart
lib/features/auth_profile/widgets/password_reset_dialog.dart
lib/features/auth_profile/widgets/profile_avatar.dart
pubspec.yaml
pubspec.lock
test/part2_auth_profile_test.dart
tool/part9_build_locales.cjs
tool/part9_translations.tsv
```

New transitive packages locked by the resolver: `facebook_auth_desktop` 2.1.3; `flutter_facebook_auth_platform_interface` 6.1.2; `flutter_facebook_auth_web` 6.1.2; `flutter_secure_storage` 10.3.4; `flutter_secure_storage_darwin` 0.3.2; `flutter_secure_storage_linux` 3.0.3; `flutter_secure_storage_platform_interface` 2.1.1; `flutter_secure_storage_web` 2.1.1; `flutter_secure_storage_windows` 4.2.2; `google_identity_services_web` 0.3.3+1; `google_sign_in_android` 7.2.17; `google_sign_in_ios` 6.3.6; `google_sign_in_platform_interface` 3.1.0; `google_sign_in_web` 1.1.3; `antlr4` 4.13.2; `cel` 0.6.0; `equatable` 2.1.0; `fake_firebase_security_rules` 0.6.0; `logger` 2.8.0; `mock_exceptions` 0.8.2; `more` 4.7.0; `rx` 0.5.0; `rxdart` 0.28.0. Native Facebook Android SDK comes from the installed plugin (`facebook-login` 18.1.3), not a separate manually added Flutter package.

Commands completed:

```powershell
flutter pub get
dart format lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 --reporter expanded
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
flutter build apk --debug --no-pub
```

The final suite completed in 21 minutes 28 seconds under resource pressure. No existing tests were removed. Initial verification caught and corrected two Gradle setup issues (Properties import and enabling generated resources), lint findings, and mock event-loop timing/stale-kernel issues during development. Final commands above all exit 0. Avoid concurrent source edits during test compilation; the final passing run used settled code.

Nonfatal warnings: existing Firebase Auth/Core plugins apply Kotlin Gradle Plugin and need upstream migration for future Flutter versions; Java native-access warnings, transitive Java 8/deprecation notices and a Firestore unchecked-operation notice appeared in the first build. Pub reports 16 newer versions outside compatible constraints; no unrelated upgrade was made. Firebase CLI reported its optional missing VS Code SQL Connect notification endpoint; all 200 assertions succeeded.

Native emulator smoke: the final APK was installed successfully on the existing API 35 Pixel_8 emulator. APK and installed package metadata both resolve `lk.heritagewalk.heritage_walk.MainActivity`. The app process remained alive and restored the existing Firebase-authenticated Home with previously saved content, without a new provider login, logout, reset email or data edit. The existing session's provider type was not inferred; this is not a real Google/Facebook acceptance test.

Because real Meta values are absent, Android's generated registrant logged a **nonfatal Facebook SDK-not-initialized registration diagnostic**. Its per-plugin exception handling continued registering other plugins, and Firebase initialization/session restoration and Home remained usable. The native configuration gate prevents attempting Facebook login in this state. Supplying the real settings and rebuilding is necessary for native Facebook SDK registration/login. The missing-configuration gate, localized resources and shared auth-error UI have automated coverage; the authenticated emulator session was preserved, so the setup notice was not claimed as a native UI acceptance result.

The emulator also experienced slow boot/package registration and an OS-level “System UI isn't responding” dialog. Selecting Wait allowed inspection of the running app. Early pre-boot install/activity attempts were retried after Android services became ready; these were emulator readiness issues, not a failing final build. Physical-device acceptance remains necessary.

Brand assets come from the providers' published resources: [Google sign-in branding](https://developers.google.com/identity/branding-guidelines), Google's hosted `identity/images/g-logo.png`, and Facebook's hosted `images/fb_icon_325x325.png`. They are bundled locally and are not fetched by authentication widgets at runtime.

Email/password login and registration remain functional under regression verification. Forgot Password and Google sign-in are implemented. Facebook is implemented at code level with an honest manual setup boundary. Apple is removed. New social users default to `role=user`; existing admin roles and user data are preserved; no admin escalation was introduced. Parts 1–9.1 regression tests remain passing, map/GPS/OSRM architecture is retained, no paid/Google map service was introduced, and **Part 10 was NOT started**.
