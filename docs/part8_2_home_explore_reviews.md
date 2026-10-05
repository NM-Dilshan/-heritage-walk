# Part 8.2: Home overview, Explore discovery and real reviews

Home and Explore now have separate responsibilities: Home helps users choose a next action and see a small overview; Explore owns the complete active-place catalog. The existing Material 3 theme, branding, Firebase project, authentication, admin role, Firestore repositories, packaged images and Parts 1?8.1 features remain. Part 9 has not started. No new packages, Storage, Maps/GPS, social sign-in, localization or paid infrastructure were introduced.

## Files created

- lib/features/discovery_planning/screens/explore_screen.dart
- lib/features/reviews/models/place_review.dart
- lib/features/reviews/services/review_repository.dart
- lib/features/reviews/services/review_controller.dart
- lib/features/reviews/widgets/review_widgets.dart
- lib/features/admin/screens/admin_reviews_screen.dart
- test/part82_home_explore_reviews_test.dart
- tool/part82_emulator_smoke.dart
- tool/run_part82_smoke.ps1
- docs/part8_2_home_explore_reviews.md

## Files modified

- lib/features/discovery_planning/screens/home_screen.dart: compact dashboard and featured selection.
- lib/features/discovery_planning/services/discovery_service.dart: inactive exclusion and zeroed legacy demo-rating fixture fields.
- lib/shared/widgets/main_bottom_navigation.dart: explicit Home-to-Explore query/category handoff using the existing tab replacement strategy.
- lib/core/routes/app_routes.dart: separate Explore builder and guarded review moderation route.
- lib/core/firebase/app_services.dart, lib/main.dart: injected ReviewRepository, session-aware controller, scope and disposal.
- lib/features/discovery_planning/widgets/place_card.dart, place_preview_sheet.dart: shared real RatingSummary.
- lib/features/navigation_guide/screens/place_details_screen.dart: real summary and review CRUD section in the existing Details screen.
- lib/features/admin/screens/admin_screens.dart: existing dashboard moderation shortcut.
- firestore.rules, test/firestore_rules_test.cjs: review ownership/schema rules and 43 additional assertions; all 121 previous checks retained.
- test/part3_discovery_planning_test.dart, test/part4_navigation_guide_test.dart: six obsolete Home/catalog/preview expectations now follow the separated UX; no tests deleted.
- README.md.

The workspace already contained changes from earlier parts; unrelated files were not reverted or committed.

## Home

The overview shows official branding, Explore Sri Lanka, a heritage subtitle, quick actions for Explore All Places, Plan a Tour, My Favorites, My Itineraries and Group Tours, plus shared saved-place/itinerary counts. It derives category shortcuts from active catalog records.

Featured Places contains at most **four** active records, ordered deterministically by isFeatured first, then name and ID. It does not depend on Explore's current search/filter. It is not labeled Most Popular and makes no analytics claim. Cards reuse the existing image, category/location and favorites components. Card taps open the existing Place Details screen directly. Loading/error/retry states are compact; an empty catalog does not disable quick actions.

## Explore and navigation

Explore Sri Lanka is a separate screen at the existing /explore route. It shows the entire active catalog with case-insensitive search across name/city/district/category and the existing category chips. States distinguish loading, backend failure/retry, no active catalog and no matches. Existing catalog subscriptions drive updates; no parallel places source or fabricated fixtures are used in production. Reload reconnects the existing catalog stream; pull-to-refresh is not added.

Home Explore All Places resets query and category to All and replaces the main stack with Explore. A Home category shortcut resets search and selects that category before replacing the tab. The five bottom-navigation tabs remain. The Explore tab preserves its current filters during ordinary tab navigation, while Home ignores them. Details and other secondary routes remain normal pushes; back returns to the originating tab. Main tab changes retain the existing stack replacement behavior and do not accumulate duplicate pages.

Home, Explore, Favorites, existing preview sheets and Details share the same FavoriteService and PlaceImage renderer. The 17 packaged JPGs, placeholder assets and legacy HTTPS read compatibility remain. Image selection never returns to Firebase Storage. Favorite changes notify shared state rather than creating a separate favorites implementation.

## Reviews schema and CRUD

Public review documents live at **places/{placeId}/reviews/{uid}**. The authenticated UID is the document ID, so a user has one current review per place.

| Field | Meaning |
| --- | --- |
| id / userId | Both equal the path UID |
| placeId | Equals the parent place ID |
| userDisplayName | Public display name, maximum 80 characters; empty/email-like names fall back to Traveler |
| rating | Integer 1?5 |
| comment | Trimmed, nonempty, maximum 1000 characters |
| createdAt / updatedAt | Server timestamps |

Place Details includes Reviews & Ratings, average/count/star representation, public display names, comments and dates. No email/private profile lookup is displayed. A missing profile does not prevent reading a stored public review. Malformed review records are excluded from aggregation rather than crashing the UI.

Write a Review opens a validated form. Creation uses a transaction that returns a duplicate-safe failure if the UID document exists. Edit Review prefills the user's own rating/comment, preserves createdAt, and updates changed content and updatedAt. Delete Review requires confirmation and updates the shared stream. The controller blocks concurrent duplicate operations and clears busy state after failure. Loading, no-review, backend error/retry and signed-out messages are explicit.

New and edited reviews require the parent place to exist and be active. Missing/inactive places still allow reading existing public reviews and deleting one's own review. Existing Details fallback behavior remains, and the review section explains that unavailable places cannot receive new/edited reviews.

## Real rating aggregation

ReviewController subscribes to each active place's readable reviews using the injected repository. ReviewFeed calculates **reviewCount = valid reviews.length** and **averageRating = sum(ratings) / reviewCount**, with zero for an empty feed. The same live feed drives Home, Explore, Details and legacy preview sheets. Edits/deletions automatically recalculate values from snapshots; no denormalized rating field is written.

Cards show a real summary such as ? 3.5 (2), No reviews, Ratings loading or Ratings unavailable. Legacy rating/reviewCount place fields remain readable for saved-model compatibility but are never a display or aggregation source. Local catalog fixture values are zero; all demo-review text and invented ratings were removed from display. Tests deliberately supply a legacy count of 999 and confirm it is ignored.

This client aggregation is appropriate for the current academic dataset and compatible with the existing Firebase services. It is not a large-catalog optimization: loading all reviews for each active place increases read/listener usage, and retained Details feeds live until session/role change or app disposal. Admin moderation loads the complete reviews collection group and filters/sorts client-side. Larger datasets should add pagination and a trusted aggregate strategy after measuring usage; no Cloud Function, background job or billing upgrade is introduced here.

## Security and admin moderation

Existing Parts 7?8.1 rules are preserved. Review reads require authentication. Create requires the path UID and all identity fields to match request.auth.uid, a valid active parent, bounded integer rating/comment/name and server audit times. Updates require the existing owner, immutable identity/createdAt and only rating/comment/public name/updatedAt changes. Deletes allow the owner or the existing protected Firestore admin role. Admins can moderate by deletion but cannot edit another user's review. Review records cannot contain a spoofed aggregate or arbitrary extra fields.

Admin Panel ? Review Moderation uses the same AdminGuard and server-confirmed role. It shows associated place, public reviewer name, rating, comment and date; search covers those fields and a place filter is provided. Deletion requires confirmation. The admin-only collection-group read rule finds reviews even when a parent place has been deleted, displaying Unavailable place. Deleting a place does not cascade-delete review subcollections; owners/admins can remove retained reviews explicitly. No separate admin login exists.

The collection name reviews is reserved for this public-review feature. Normal users can query each place's reviews; only admins can enumerate the global reviews collection group. All writes still require the exact places/{placeId}/reviews/{uid} path. Existing private user collections remain isolated. [Firebase collection-group rule guidance](https://firebase.google.com/docs/firestore/security/rules-query) explains the version-2 recursive read rule used for moderation.

No new composite index is needed: reviews are fetched without server ordering/filters and ordered/filtered in memory. Existing firestore.indexes.json stays unchanged. Required production deployment, from this directory:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project heritagewalk-sri-lanka
```

No production deployment or production sample reviews were performed. Review features require the reviewed rules to be deployed. No Storage deployment is required.

## Verification

Before Part 8.2: 227 Flutter tests and 121 Firestore assertions. Added 40 Flutter tests covering Home limits/navigation/states, full active discovery/search/filtering, favorites, live catalog updates, models/validation, one-review identity, CRUD/ownership, count/mean changes, audit preservation, duplicate submission, logout/revocation, deleted places, Details form/confirmation/moderation and small-screen large-text layouts. Six existing UX tests were updated to the new intended navigation; none were deleted. Final verified total: **267 Flutter tests passed**. `flutter pub get` succeeded; `dart format lib test` formatted 132 files; `flutter analyze` reported **no issues**.

Security emulator: **164 assertions passed (121 existing +43 review assertions)**. Tests include anonymous denial, impersonation, field spoofing, invalid ratings/comments, forbidden aggregate fields, collection-group access, immutable audit/ownership, owner edit/delete, deletion-only moderation and inactive/deleted parents. Command:

```powershell
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "node test/firestore_rules_test.cjs"
```

Actual Android Firebase SDK smoke verification also passed against the local demo emulators: registration/sign-in, trusted role, live catalog and place CRUD, review create/edit/delete/server audit/live mean/count/moderation, Emergency Contact CRUD/active filtering, favorites/itineraries, sign-out and restored state. All fixtures are local synthetic test data. Reproduce with an Android emulator at emulator-5554:

```powershell
firebase emulators:exec --project demo-heritagewalk --only auth,firestore "powershell -ExecutionPolicy Bypass -File tool/run_part82_smoke.ps1"
```

The development smoke entry point uses a named Firebase app and explicit demo project/emulator endpoints. It is not the shipped main.dart entry point. Rebuild the normal debug APK afterwards.

Requested checks: flutter pub get, dart format lib test, flutter analyze, flutter test, flutter build apk --debug. Final APK should be build/app/outputs/flutter-apk/app-debug.apk built from normal lib/main.dart.

## Manual acceptance and limitations

- Sign in normally: Home has only a four-place overview, categories/quick actions work, and Explore shows the complete active catalog. Check selected navigation state and back from Details.
- Search by name/city/district/category; check no matches, slow network/error/retry and empty catalogs. Admin-created active places should appear live; deactivate and confirm disappearance.
- Favorite/unfavorite between Explore, Home, Details and Favorites; check the saved counts and existing itinerary flows.
- Write/edit/delete a real personal review; verify review count/mean and server dates change. Cancel deletion; switch accounts and confirm another user's edit/delete are unavailable and denied.
- Admin moderation: search/filter and delete an inappropriate review, including an orphaned review; role revocation removes access. Check normal users cannot open this route.
- Verify all packaged/placeholder images and an existing HTTPS reference, long comments/public names, larger text, keyboard and a physical Android phone. The unit/widget tests do not replace production deployment/device acceptance.
- Emergency Support/dialer, Digital Guide, demo navigation, groups, language preference and support/About remain; no Part 9 behavior is introduced.

Dependency resolution may report four newer incompatible versions. Current Gradle/Java native-access and Firebase Auth/Core Built-in Kotlin compatibility warnings remain tooling concerns. Emulator startup can be slow on this machine; leftover demo port processes must be identified before stopping them. No production data should be touched to resolve local test issues.
