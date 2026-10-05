# Part 3: Discovery, planning and saved-content CRUD

This is the Part 3 implementation snapshot. Part 4 now connects full place details and Map/demo navigation. See [Part 4 documentation](part4_navigation_guide_crud.md) for those integrated flows.

Owner: A B K S I Sithuruwan (IT23839038), discovery_planning module.

**Part 3 currently uses in-memory application state. Persistent Firestore storage will be introduced during backend integration.**

## Favorites

- Create: the card heart or place-preview action adds the place by unique ID.
- Read: My Favorites reads the same FavoritesService used by Home and previews.
- Delete: removing a favorite immediately changes every view. My Favorites
  provides a SnackBar Undo action that restores it.
- No separate favorite Update operation or cloud persistence is claimed.

## Itineraries

- Create: a valid plan generates a draft. Save Itinerary saves that draft by ID.
  Repeated saving of that ID has no effect and the button becomes disabled.
- Read: My Itineraries lists saved journeys. View opens the same itinerary with
  its live title, plan summary and stops. Saved entries show their saved state.
- Update: Rename validates a non-empty title, trims it and updates the service.
- Delete: a confirmation dialog precedes removal. Cancellation retains the entry.
- Regenerate creates a new unsaved draft, changing the order or first stop where
  alternatives exist. The previously saved itinerary stays unchanged.
- Edit Plan preserves the destination, date, duration, interests and travel style.

## Demo data and generation limits

Eight landmarks are included. Existing place_placeholder.jpg is used for every
landmark and visibly labeled Placeholder image. Ratings and review counts are
illustrative and labeled demo reviews; they do not represent collected reviews.

Search matches name, city, district and category, case-insensitively. Search and
category filters combine. All resets the category. Nature has no matching entry
in the current small catalogue and intentionally shows an empty state.

The planner offers destinations supported by this catalogue, validates today or
future dates, duration, and at least one interest. It ranks local places by
interest and limits stop count for a half-day or relaxed plan. Sigiriya/Dambulla
share a small two-place pool; all other destinations currently have one stop.
Multi-day selections remain recorded but do not fabricate stops for every day.
A generated itinerary is a suggested starting point, not a complete schedule.
Visit estimates are illustrative. No travel-time, opening-hours or route
optimization claims are made. Single-stop regeneration explains the limited pool.

## Navigation and state lifetime

Normal login/registration now opens Home and clears unauthenticated history.
Home and Explore reuse the same screen; main tab switches replace the current
stack to avoid duplicates. Detail screens use normal pushes. Planner generation
and Edit Plan replace their route so repeated editing does not build a stack.
Profile My Trips opens My Itineraries; My Favorites opens Favorites. Other menu
items stay deferred. Map shows the Part 4 message. Sign-out confirmation clears
profile, discovery, favorites, itineraries and authenticated history. State is
also lost when the app restarts. Foundation and auth-success previews remain
available for development, outside the normal authentication flow.

## Description sources

Short, neutral descriptions were checked against:

- [UNESCO Sri Lanka listings](https://whc.unesco.org/en/statesparties/lk)
- [Sigiriya](https://whc.unesco.org/en/list/202)
- [Dambulla Cave Temple](https://whc.unesco.org/en/list/561/)
- [Polonnaruwa](https://whc.unesco.org/en/list/201)
- [Anuradhapura](https://whc.unesco.org/en/list/200/)
- [Sri Lanka Tourism cultural heritage](https://www.srilanka.travel/cultural_heritage)
- [Sri Lanka Tourism northern attractions](https://www.srilanka.travel/attractions/northern-sri-lanka)
- [Sri Lanka Tourism Development Authority Ella plan, Nine Arch Bridge](https://www.sltda.gov.lk/storage/common_media/ELLA_VOLUME_1_Part_B_compressed2395158019.pdf)

These sources informed static descriptions only. The app makes no web/API calls.

## Deferred

Firebase/authentication/Firestore/storage, backend and AI APIs, real landmark
photos and reviews, maps/GPS/routing, full heritage details and digital guides,
facilities, emergency, group tools, language/help implementations and admin UI.

## Verification

Run `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test`,
and `flutter build apk --debug`. Part 1 tests are retained; Part 2 authentication
assertions are adapted to Home. Part 3 includes widget flows and service tests.

