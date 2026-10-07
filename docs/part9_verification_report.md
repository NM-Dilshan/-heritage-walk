# Part 9 verification report

Completed 5 October 2026. Parts 1–8.2 remain present; Part 10 has not started. The normal debug APK uses `lib/main.dart`, not the development smoke entrypoint. No production Firestore rules were deployed and no production test fixtures were written.

| Requested item | Result |
| --- | --- |
| 1. Files created | 16 files, listed below. |
| 2. Files modified | 84 task files, listed below. The user's pre-existing change to `docs/part8_2_home_explore_reviews.md` was preserved and excluded from this inventory. |
| 3. Packages and versions | `flutter_map 8.3.2`, `latlong2 0.10.1`, `geolocator 14.1.1`, `http 1.6.0`, `intl 0.20.3`, SDK `flutter_localizations`. Existing Firebase/Auth/Firestore/url_launcher packages remain. |
| 4. Map provider | OpenStreetMap standard tiles, `tile.openstreetmap.org`, with visible copyright attribution, valid application identity and native HTTP-aware tile caching. |
| 5. Routing provider | FOSSGIS public OSRM, separate car and foot endpoints, full GeoJSON route geometry. |
| 6. API key | No map/routing key is required. Existing FlutterFire configuration remains in place. |
| 7. Billing | No map billing account, credit card, Google Maps billing or new Blaze-only service is required. Public-service usage limits and existing Firebase free quotas still apply. |
| 8. GPS | Actual Geolocator fixes and foreground streams; direct Android LocationManager path with 25-metre filtering and ten-second interval. Test harnesses inject fakes or explicitly report unavailable GPS. |
| 9. Permissions | Fine/coarse only; denied, permanent denial, services off, unavailable and timeout states; settings-return retries. No background-location or CALL_PHONE permission added. |
| 10. Route implementation | Validated server polyline, current/destination markers, pan/zoom/recenter, walking/driving, retry, route preview and live GPS guidance. No fabricated straight-line route. |
| 11. Distance/ETA | OSRM distance metres and duration seconds, converted to kilometres and rounded-up minutes. Initial estimates, not traffic-aware live remaining metrics. |
| 12. Place Details | Home/Explore -> Details -> Navigate retains the exact selected model/ID/coordinates. Missing coordinates disable routing honestly. Existing chooser survives. |
| 13. Group tracking | Authenticated-member, explicit opt-in foreground sharing; server snapshots, throttled writes, fresh heartbeat, stale/member filtering and start/stop/lifecycle cleanup. No demo markers or fabricated movement. |
| 14. Group schema | `groups/{groupId}/locations/{uid}`: userId, displayName, latitude, longitude, server updatedAt. One latest snapshot; no history. |
| 15. Privacy/security | Member-only reads; own-UID/member-only writes; no administrator bypass; exact fields, safe name, bounded coordinates and server timestamp; owner cleanup allowed after leaving/deletion. Offline cleanup is best effort, with stale UI suppression after two minutes. |
| 16. English | Normal-user UI localized through the application delegate and standard Material/Widgets/Cupertino delegates. |
| 17. Sinhala | Same resource coverage and full application locale switching, including normal-user forms, permission/routing/group/review/support labels. Fluent-speaker review remains advisable. |
| 18. Tamil | Same resource coverage and full application locale switching, including normal-user forms, permission/routing/group/review/support labels. Fluent-speaker review remains advisable. |
| 19. Resources | 571 resources per locale; 1,713 values across en/si/ta. User/admin content and proper names remain verbatim. |
| 20. Rules changes | Only the new group-location helper/subcollection rules were added; existing Part 8.2 security remains. No index change required. |
| 21. Flutter tests added | 86 new tests covering GPS/errors, route decoding/metrics/caching, stale responses, settings/lifecycle cleanup, group consent/ownership/staleness, real UI flows, resource parity, compact translated layouts and persisted app-locale restoration. |
| 22. Total Flutter tests | **353 passed**: original 267 retained + 86 new. Existing assertions were adapted for real navigation, localization and star rendering; none deleted to hide failures. |
| 23. Security additions | **36** new group-location authorization/schema/privacy assertions. |
| 24. Total security assertions | **200 passed**: original 164 retained + 36 new, using only `demo-heritagewalk` emulators. |
| 25. Analysis | `flutter analyze`: **No issues found**. `dart format lib test` completed; Git whitespace check clean. |
| 26. APK | `flutter build apk --debug`: **success**. `build/app/outputs/flutter-apk/app-debug.apk`, 194,800,633 bytes. Normal production entrypoint confirmed in its compiled kernel. |
| 27. Manual tests required | Physical-phone permission/accuracy/offline/settings cases, full native-speaker UI review, restart persistence, two-user/two-device group movement and privacy checks. Detailed checklist in the architecture document. |
| 28. Limitations | Public maps/routes require Internet, have usage limits and no SLA. No full offline maps, spoken/turn-by-turn directions, live traffic, automatic rerouting or background tracking. New production group-location access remains blocked until reviewed rules deployment. Offline deletes may leave stored stale snapshots; no server TTL is configured. |
| 29. Deployment after review | `firebase deploy --only firestore:rules --project heritagewalk-sri-lanka` — **not executed**. |

## Verification evidence

- `flutter pub get`: success. Twelve unrelated packages report newer versions outside current constraints; no unnecessary broad upgrade was performed.
- `dart format lib test`: completed; development smoke Dart also formatted.
- `flutter analyze`: no issues, final run 16.9 seconds.
- `flutter test`: all 353 passed, final run 56 seconds. Tests use fakes/mock HTTP; no automated suite relies on a public routing server.
- Firebase Auth/Firestore emulator execution: 200 assertions passed, exit code 0. No production data touched.
- Normal debug build: successful, final Gradle build 72.5 seconds. SHA-256: `B8A8B75C5AD1E771A5F24A226D3B91F79D2C5EA3533E3EB0DA989FF08B64976E`.
- Android API 35 emulator smoke: actual plugin received emulator-provided GPS `6.032, 80.218`; one real OSRM road route returned **47 vertices, 965.8 metres, 158.0 seconds**. The direct-provider rapid stream start/cancel test left Android GPS and fused providers `OFF`. This is emulator SDK evidence, not a claim of physical-device GPS testing.
- An emulator Android system restart interrupted one attempt; an initial post-recovery stale fix timed out. Repeating fresh test fixes after listener startup passed. This was kept separate from unit-test results.
- The normal APK was restored on the emulator and its Login screen rendered successfully. A System UI not-responding overlay was dismissed with Wait. Authenticated production UI flows were not exercised with invented credentials or production test writes.
- Installed APK permissions were inspected: fine/coarse foreground location present; background-location, foreground-service location and CALL_PHONE absent. All 17 packaged place JPGs remain unchanged; HTTPS images, real reviews/aggregates/moderation and active/verified emergency dialer behavior remain covered by retained tests.

Build warnings: upstream Geolocator Android Java source/target 8 obsolescence and deprecated API notes; plugin Kotlin Gradle compatibility notice for future Flutter versions; Java/Gradle native-access warning during the first build. The requested build succeeds. SDK Platform 35 and CMake 3.22.1 were installed by the normal Android build to satisfy dependencies. Firebase CLI emitted an optional missing VS Code notification-endpoint notice; its tests succeeded.

Provider limits, required attribution, GPS/group privacy, localization maintenance and the physical-device checklist are in [Part 9 architecture](part9_maps_gps_groups_localization.md), with links to the providers' current policies.

## Created files

- `assets/l10n/en.json`
- `assets/l10n/si.json`
- `assets/l10n/ta.json`
- `docs/part9_maps_gps_groups_localization.md`
- `docs/part9_verification_report.md`
- `lib/core/localization/app_localizations.dart`
- `lib/core/localization/messages.g.dart`
- `lib/features/group_support/services/group_location_service.dart`
- `lib/features/navigation_guide/services/location_service.dart`
- `lib/features/navigation_guide/services/routing_service.dart`
- `lib/features/navigation_guide/widgets/heritage_map.dart`
- `test/part9_maps_groups_localization_test.dart`
- `test/support/part9_fakes.dart`
- `tool/part9_build_locales.cjs`
- `tool/part9_device_smoke.dart`
- `tool/part9_translations.tsv`

## Modified files

- README.md
- android/app/src/main/AndroidManifest.xml
- firestore.rules
- lib/core/firebase/app_services.dart
- lib/core/firebase/cloud_status.dart
- lib/core/routes/app_routes.dart
- lib/features/admin/screens/admin_reviews_screen.dart
- lib/features/admin/screens/admin_screens.dart
- lib/features/admin/screens/emergency_admin_screens.dart
- lib/features/admin/widgets/place_image_selector.dart
- lib/features/auth_profile/screens/auth_success_placeholder_screen.dart
- lib/features/auth_profile/screens/edit_profile_screen.dart
- lib/features/auth_profile/screens/login_screen.dart
- lib/features/auth_profile/screens/profile_screen.dart
- lib/features/auth_profile/screens/register_screen.dart
- lib/features/auth_profile/screens/splash_screen.dart
- lib/features/auth_profile/widgets/auth_form_layout.dart
- lib/features/auth_profile/widgets/password_reset_dialog.dart
- lib/features/auth_profile/widgets/sign_out.dart
- lib/features/discovery_planning/screens/explore_screen.dart
- lib/features/discovery_planning/screens/favorites_screen.dart
- lib/features/discovery_planning/screens/generated_itinerary_screen.dart
- lib/features/discovery_planning/screens/home_screen.dart
- lib/features/discovery_planning/screens/my_itineraries_screen.dart
- lib/features/discovery_planning/screens/plan_tour_screen.dart
- lib/features/discovery_planning/widgets/category_chip.dart
- lib/features/discovery_planning/widgets/discovery_layout.dart
- lib/features/discovery_planning/widgets/itinerary_card.dart
- lib/features/discovery_planning/widgets/place_card.dart
- lib/features/discovery_planning/widgets/section_header.dart
- lib/features/foundation/screens/foundation_preview_screen.dart
- lib/features/group_support/screens/about_screen.dart
- lib/features/group_support/screens/create_group_screen.dart
- lib/features/group_support/screens/group_details_screen.dart
- lib/features/group_support/screens/group_tour_screen.dart
- lib/features/group_support/screens/group_tracking_screen.dart
- lib/features/group_support/screens/help_support_screen.dart
- lib/features/group_support/screens/language_selection_screen.dart
- lib/features/group_support/services/group_tour_service.dart
- lib/features/group_support/widgets/about_feature_card.dart
- lib/features/group_support/widgets/faq_tile.dart
- lib/features/group_support/widgets/group_card.dart
- lib/features/group_support/widgets/group_dialogs.dart
- lib/features/group_support/widgets/group_map_placeholder.dart
- lib/features/group_support/widgets/invite_code_card.dart
- lib/features/group_support/widgets/language_option_card.dart
- lib/features/group_support/widgets/member_card.dart
- lib/features/group_support/widgets/member_status_chip.dart
- lib/features/group_support/widgets/support_request_card.dart
- lib/features/group_support/widgets/support_request_form.dart
- lib/features/navigation_guide/models/guide_content.dart
- lib/features/navigation_guide/models/route_info.dart
- lib/features/navigation_guide/screens/digital_guide_screen.dart
- lib/features/navigation_guide/screens/emergency_support_screen.dart
- lib/features/navigation_guide/screens/navigation_screen.dart
- lib/features/navigation_guide/screens/nearby_facilities_screen.dart
- lib/features/navigation_guide/screens/place_details_screen.dart
- lib/features/navigation_guide/services/emergency_service.dart
- lib/features/navigation_guide/services/navigation_guide_scope.dart
- lib/features/navigation_guide/services/navigation_service.dart
- lib/features/navigation_guide/widgets/demo_audio_guide.dart
- lib/features/navigation_guide/widgets/emergency_contact_card.dart
- lib/features/navigation_guide/widgets/facility_card.dart
- lib/features/navigation_guide/widgets/guide_note_dialog.dart
- lib/features/navigation_guide/widgets/guide_section_card.dart
- lib/features/navigation_guide/widgets/map_placeholder.dart
- lib/features/navigation_guide/widgets/place_destination_chooser.dart
- lib/features/navigation_guide/widgets/route_summary_card.dart
- lib/features/reviews/widgets/review_widgets.dart
- lib/main.dart
- lib/shared/widgets/heritage_app_bar.dart
- lib/shared/widgets/heritage_bottom_navigation.dart
- lib/shared/widgets/heritage_button.dart
- lib/shared/widgets/heritage_text_field.dart
- pubspec.lock
- pubspec.yaml
- test/firestore_rules_test.cjs
- test/part4_navigation_guide_test.dart
- test/part4_services_test.dart
- test/part5_group_tour_test.dart
- test/part5_services_test.dart
- test/part6_language_support_about_test.dart
- test/part7_auth_widgets_test.dart
- test/part82_home_explore_reviews_test.dart
