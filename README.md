# HeritageWalk Sri Lanka

Parts 1, 2 and 3: Android Flutter foundation, Material 3 theme, existing assets,
reusable widgets, future route constants, the account/profile UI, and discovery/planning/saved-content modules.

## Module ownership

| Module | Student | Student ID | Responsibility |
| --- | --- | --- | --- |
| auth_profile | W A N M Dilshan | IT23839410 | Account Authentication & Profile Management |
| discovery_planning | A B K S I Sithuruwan | IT23839038 | Tour Discovery, Planning & Saved Content |
| navigation_guide | N M S H Premarathna | IT23825550 | Navigation, Digital Guide, Facilities & Safety |
| group_support | R D I H Rajapaksha | IT23841772 | Group Tour, Language & Support Features |

Navigation/guide and group/support directories, plus shared models/services, are reserved
for later work. Placeholder files preserve reserved directories in version control. No backend or other member module implementations are included.
Startup: Splash -> Login/Register -> Home. Authentication and profile state are session demos.
See [Part 2 CRUD documentation](docs/part2_auth_profile_crud.md) and [Part 3 CRUD documentation](docs/part3_discovery_planning_crud.md).
FoundationPreviewScreen is preserved at the development route '/'.

## Run

From this project directory with an Android emulator or device connected:

```powershell
flutter pub get
flutter run
```

Validate with `flutter analyze` and `flutter test`.
Build an APK later with `flutter build apk` (requires configured Android SDK).
The Android launcher icon remains the generated Flutter default; the preview
uses the official existing logo. All asset constants use relative paths.





