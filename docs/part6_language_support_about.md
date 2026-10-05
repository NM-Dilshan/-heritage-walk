# Part 6: Language, Help & Support, About

The group_support module adds the three remaining main screens for this part.
Existing Parts 1–5, assets, logo and bottom navigation are preserved.

## Language

LanguageService holds a single English (en), Sinhala (si) or Tamil (ta)
preference. Selection immediately updates the check indicator and translated
“Explore Sri Lanka” preview and survives navigation. This is a preference and
preview, not complete app localization. System fonts render native scripts.
Language remains selected across demo logout within the running app session;
restarting the app resets it to English. No storage package is used.

## Support request CRUD

SupportService owns immutable SupportRequest records and notifies the shared
SupportScope. Create validates category, nonblank subject (100 characters)
and message (1000 characters), assigns a unique local ID and Open status.
Read shows newest requests first with category, creation date, status and message.
Edit prefills the form and updates category, subject and message, preserving ID
and creation time. Mark Resolved and Reopen update real service status.
Delete requires confirmation and immediately removes the record.
Model serialization uses enum names and ISO timestamps with no Firebase imports.

Requests survive navigation, clear on logout like other user-specific state,
and are lost on restart. IDs are not reused after clearing. This is local demo
CRUD: no support team receives or responds to requests.

FAQ search checks question, answer and category, case-insensitively. Category
chips combine with search and include All. Expandable answers accurately describe
current local groups, invite codes and demo navigation. No matches shows an
empty state. The emergency action reuses Part 4's existing route and screen.

## About and navigation

About uses the existing official AppAssets.logo, explains purpose, six features,
the generic university HCI project context, Version 1.0.0 and a concise demo data
notice. It links to Help & Support, Language and Home. No personal student data,
fake social links or formal privacy policy is introduced.
Profile opens Group Tours, Language, Help & Support and About using real routes.
New screen routes are /language, /help-support and /about; /help remains an alias.
LanguageScope and SupportScope wrap the app alongside all existing scopes.

## Verification and boundaries

Part 6 tests cover language state/preview, FAQ search and categories, form
validation and all CRUD operations, navigation and official logo, logout,
serialization, service validation and compact layouts with increased text scale.
Run flutter pub get, dart format lib test, flutter analyze, flutter test and
flutter build apk --debug. Existing Parts 1–5 tests remain unchanged.

Firebase persistence, cloud support requests, email, push notifications,
complete localization, live maps/GPS, real-time tracking, Admin and external
APIs are deferred. No packages added. Part 7 is not started.
