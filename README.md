# FPT Lecturer Companion

A standalone Flutter mobile app for FPT lecturers: today's teaching, weekly schedule, classes, student rosters, session attendance, QR check-in, reports and profile.

## Chạy nhanh trên máy Windows này

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1
```

Script tự mở máy ảo `Pixel_10_Pro_XL` nếu chưa có thiết bị Android, cài dependencies và chạy app. Có thể chỉ định điện thoại bằng `-DeviceId <id>` hoặc máy ảo khác bằng `-EmulatorId <id>`. Trong terminal Flutter: `r` để hot reload, `R` để restart, `q` để dừng. VS Code có cấu hình F5 trong `.vscode/launch.json`; chọn thiết bị Android trước khi chạy.

Nếu cấu hình API/OAuth còn trống, app hiện **Setup required**. Điền `config/development.json` để đăng nhập thật; không cần điền cấu hình chỉ để mở app.

**This repository does not modify or depend on the FAP Attendance Desktop repository at runtime.** It talks to the existing Apps Script application API. No FAP API, FAP cookies, browser scraping, desktop localhost, direct spreadsheet credentials or separate attendance database is used.

## Readiness

The app and compatible API client are implemented. A build without configuration shows **Setup required**, never invented production data. Live sign-in needs a configured deployment and compatible native OAuth audience; these were not supplied. The backend currently verifies one lecturer OAuth audience. See [reference audit](docs/REFERENCE_AUDIT.md) before provisioning mobile access so desktop sign-in remains compatible.

## Technology and architecture

Flutter/Dart, Material 3, `http`, `google_sign_in` 7.2, `flutter_secure_storage` 9.2.4 (same major as the reference), and `qr_flutter`. Dependency versions are locked in `pubspec.lock`. No extra backend, Firebase SDK, state-management library or database is added.

Screens → LecturerRepository → AppsScriptApi → existing Apps Script → existing Google Sheets. Auth is a ChangeNotifier; server snapshots live in async loaders; filters/forms remain local widget state. See [architecture](docs/ARCHITECTURE.md) and [API/action inventory](docs/REFERENCE_AUDIT.md).

## Prerequisites and installation

- Flutter 3.47.3 / Dart 3.13.3 were used for validation (Dart >=3.10 required).
- Android SDK and JDK supported by this Flutter version. Android minimum SDK 24. A device/emulator is needed for interactive native testing.
- For iOS: macOS, Xcode, iOS 15+, Apple signing team, and platform plugin tooling.
- An Apps Script deployment with the audited attendance/roster actions, existing Sheets schema, registered lecturer, and OAuth clients.

From this repository:

```powershell
flutter pub get
Copy-Item config/development.example.json config/development.json
```

Fill `config/development.json`:

| Key | Value |
|---|---|
| APP_ENV | development or production |
| APPS_SCRIPT_URL | HTTPS `https://script.google.com/macros/s/<deployment-id>/exec`; no query/token |
| GOOGLE_SERVER_CLIENT_ID | Web/server OAuth client ID accepted by lecturer backend validation |
| GOOGLE_IOS_CLIENT_ID | iOS OAuth client ID (for iOS builds) |
| STUDENT_CHECKIN_URL | Existing deployed HTTPS student check-in page, without query/fragment; same backend/data source |

OAuth client IDs and public URLs are configuration, not secrets. **Never put a Google client secret, password, service-account key, or spreadsheet credential into this app.** Environment JSON files are ignored. Production has its own `production.example.json`.

## Authentication setup

1. Register Android package `vn.edu.fpt.lecturer_companion` and the appropriate debug/release SHA fingerprints with Google OAuth. Use a web/server client for the token audience.
2. The reference `authenticate_` accepts `GOOGLE_CLIENT_ID` only. Verify that this is a suitable server audience, or arrange a separately reviewed backend allowed-audience change. Do not replace the desktop audience blindly. The mobile repository does not modify that backend.
3. Native Google Sign-In obtains an ID token. `profile` verifies it against Google and the Lecturers sheet. No local email/role determines access.
4. After verification, the short-lived ID token is saved using platform secure storage (Android encrypted preferences/KeyStore, iOS Keychain). Restart restores only an unexpired token **and re-verifies the profile**. Expiry requests sign-in again; this MVP does not implement its own refresh-token exchange.
5. Logout clears app credentials and native Google sign-in. HTTP 401 and recognized backend session-expiry errors remove all private routes. Failed secure deletion displays a retry message.

Native setup follows the official [Google Sign-In package](https://pub.dev/packages/google_sign_in), [Android implementation](https://pub.dev/packages/google_sign_in_android), and [iOS implementation](https://pub.dev/packages/google_sign_in_ios). Secure vault setup follows [flutter_secure_storage 9.2.4](https://pub.dev/packages/flutter_secure_storage/versions/9.2.4).

## Run Android / development

```powershell
flutter devices
flutter run --dart-define-from-file=config/development.json
flutter build apk --debug --dart-define-from-file=config/development.json
```

Select an Android device when prompted, or append `-d <device-id>`. The unconfigured setup screen can be launched with `flutter run` alone. This is a native Android/iOS app; web/Windows production auth targets are not configured.

Debug output: `build/app/outputs/flutter-apk/app-debug.apk`. The debug APK is a development artifact, not a production release.

## Release Android

Copy `android/key.properties.example` to `android/key.properties` and supply your release keystore and passwords. The release build intentionally fails without signing configuration; it never silently uses the debug signing key.

```powershell
Copy-Item config/production.example.json config/production.json
# Fill production configuration and signing properties first.
flutter build appbundle --release --dart-define-from-file=config/production.json
```

The package and release fingerprint must be registered with Google. Review backend audience support and test the live flow before distribution.

## Run/build iOS (on macOS)

```sh
flutter pub get
cp config/development.example.json config/development.json
cp ios/Flutter/Google.example.xcconfig ios/Flutter/Google.local.xcconfig
# Fill JSON and the reversed iOS OAuth client ID in the local xcconfig.
open ios/Runner.xcodeproj
flutter run -d <ios-device-id> --dart-define-from-file=config/development.json
flutter build ipa --release --dart-define-from-file=config/production.json
```

Set the Apple team and signing in Xcode. Bundle ID is `vn.edu.fpt.lecturerCompanion`. Info.plist uses `GOOGLE_REVERSED_CLIENT_ID` for the OAuth callback scheme, and Keychain entitlements are included. If Flutter generates a CocoaPods workspace, open `ios/Runner.xcworkspace` instead. iOS compilation and device behavior cannot be verified on Windows.

## Attendance and reports

Home/Schedule → confirm the date → create/resume the server session → attendance roster → manual correction or QR → finish → report. The server determines ownership, enrollment, duplicate prevention and mutation permission. Manual statuses are PRESENT/LATE/ABSENT; CLOSED sessions can be corrected; RESET sessions are unavailable.

Finishing calls `closeSession` then `markAbsent`. If finalization fails, the screen refreshes and offers **Finalize missing attendance**. No automatic mutation retries hide an ambiguous result. Reports reload the same source. Missing roster students count as absent in a session report, matching the desktop, with an explicit “no saved record” label. Class summaries show saved record counts; no unsupported attendance-rate formula is invented.

QR displays the existing `sessionId/token/mode/v=2` URL. Regeneration uses a secure random 24-byte token, 120-second expiry and optional six-digit secret. Students authenticate on the existing website. Expired/uncertain QR codes are hidden. Attendance refreshes every 15 seconds in the foreground; refresh requests do not overlap. No camera permission is needed.

## Tests and project structure

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

`test/fixtures.dart` is exclusively test data and is never imported into the application. UI tests generate review captures in ignored `artifacts/ui/`. They use an optional host font on Windows for readable captures; assertions are portable.

```text
lib/app/                 Application/auth boundary and five-tab shell
lib/features/auth/      Native Google identity and secure token vault
lib/features/classes/   Class detail, roster and student history
lib/features/sessions/  Session creation/detail
lib/features/attendance/Corrections, report view and QR
lib/api/                HTTP client, server contracts and domain repository
lib/models/             Compatible DTOs and campus clock
lib/core/               Theme, configuration, states and error messages
android/, ios/          Standalone native hosts
config/                 Environment examples
docs/                   Audit, plan and acceptance checklist
test/                   Network, domain, authentication and mobile UI tests
```

## Known limitations

- Live OAuth and API end-to-end verification await institution configuration; no deployment or real student data was accessed.
- Native sign-in and secure storage require device validation; automated tests inject adapters.
- No term date ranges/holiday exceptions in the source API. Select a semester and confirm dates before attendance; all teaching times use UTC+7.
- No remote Excel export endpoint, notification pipeline, or defined attendance-rate aggregate. These are explicitly deferred.
- No offline writes. Network timeouts require refresh before retrying.
- API responses are not paginated. Lists use lazy rendering for rosters/attendance, recent reports are limited to 50, but backend scalability needs server work.
- Close/finalize is not atomic server-side. The UI provides recovery; no new backend was invented.
- Student history is class-scoped. No enrollment effective dates exist for authoritative historical absence rates.

See [verification checklist](docs/ACCEPTANCE.md) for automated vs. live-device acceptance boundaries.
