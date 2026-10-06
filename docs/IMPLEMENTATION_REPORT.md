# FPT Lecturer Mobile — Implementation Report

## 1. Reference Project Analysis

The reference uses Flutter/Dart for Windows, a Google Apps Script JavaScript backend and Google Sheets as the shared source of truth. Chrome MV3 extension integration and Windows OCR are separate components. See [detailed source audit and API matrix](REFERENCE_AUDIT.md).

## 2. Mobile Technology Decision

Flutter/Dart preserves the existing language, UI ecosystem, contracts and attendance concepts. Android/iOS hosts and native Google Sign-In replace Windows-specific parts.

## 3. Architecture

Feature screens → shared LecturerRepository → AppsScriptApi → existing application backend. Lightweight notifier auth, async server snapshots and local UI state. No second database or offline attendance store. See [architecture](ARCHITECTURE.md).

## 4. Project Structure

`lib/app`, `lib/features/{auth,classes,sessions,attendance}`, `lib/api`, `lib/models`, `lib/core`; standalone Android/iOS projects; config examples; original icon assets and generator; tests; audit and setup documentation.

## 5. Features Implemented

Login/setup UI, Home current/next-today teaching, today/week schedule with semester selection, class search/detail, roster/student history, session creation/detail, attendance search/status filters, manual corrections with notes, session completion/finalization recovery, QR display/expiry/regeneration/secret mode, session reports, class saved-record summaries, profile and logout. Loading, retry, empty, permission and network states are explicit.

## 6. Existing Concepts Reused

Class mapping by normalized semester/subject/class; student IDs and enrollments; session identity and OPEN/CLOSED/RESET states; PRESENT/LATE/ABSENT mutations; duplicate guards; server-owned audit identity; 120-second QR expiry; roster-complete session report absences; UTC+7 campus clock.

## 7. API Integration

Actual POST actions reused: profile, getRows (Classes/Schedules/Sessions), getRoster, createSession, getSessionAttendance, updateAttendance, closeSession, markAbsent, rotateToken, getClassHistory. No invented REST endpoints. Redirect response retrieval does not forward credentials.

## 8. Missing Backend Capabilities

Native lecturer OAuth audience support/configuration must be confirmed. Remote Excel export, date-bound timetable exceptions, push notifications, pagination, canonical attendance-rate metrics and atomic session finalization are unavailable in the audited backend. Proposals are documented, not called as if they exist.

## 9. Authentication

Native Google Sign-In → Google ID token → existing profile verification → secure storage. Only server-verified lecturer profiles unlock the app. Unexpired restored tokens are reverified. Expiry requires sign-in again. Live login has not been verified without institution configuration.

## 10. Attendance

Home/Schedule → confirm teaching date → create/resume server session → roster → manual update or QR → close → mark missing enrolled students absent → reload → report. Manual CLOSED-session corrections match existing rules. An interrupted finalization exposes a safe retry.

## 11. QR

Existing student website URL uses sessionId, token, mode and v=2. Secure random 24-byte tokens expire after 120 seconds; optional six-digit secret stays out of the URL. Foreground polling updates attendance every 15 seconds. Expired or uncertain codes are hidden; lecturers explicitly regenerate. Existing student Google/enrollment/duplicate validation remains on the server.

## 12. Reports

Reports reuse attendance records from the same repository. Missing roster records are explicitly identified and counted absent in session reports, matching desktop semantics. Class totals are saved-record counts; no unsupported percentage formula or historical enrollment assumption is introduced. Excel export is clearly pending.

## 13. Security

Platform secure storage; no plaintext token cache, client secrets, FAP credentials, direct DB credentials or client-controlled role. Strict HTTPS API configuration, safe error mapping, token-free result redirect, private-route removal on logout, Android backup disabled, iOS Keychain setup and explicit release signing. Device verification remains necessary.

## 14. Run Instructions

Run `flutter pub get`; copy `config/development.example.json` to `config/development.json`, fill endpoint/OAuth/check-in URL; then `flutter run --dart-define-from-file=config/development.json`. An unconfigured launch shows Setup required. See the [README](../README.md) for complete commands.

## 15. Android

`flutter build apk --debug` succeeded. APK: `build/app/outputs/flutter-apk/app-debug.apk`. Minimum SDK 24. Release requires `android/key.properties` and the production environment, then `flutter build appbundle --release --dart-define-from-file=config/production.json`.

## 16. iOS

Native project, callback URL configuration and Keychain entitlements are included. Configure iOS OAuth, reversed client ID, Apple team/signing on macOS. Run `flutter build ipa --release --dart-define-from-file=config/production.json`. Not built on this Windows host.

## 17. Testing

Formatting passed, `flutter analyze` reports no issues, `flutter test` passes 27 tests, Android debug APK builds independently. Phone widget renders were reviewed; small-screen/large-text navigation and a manual correction through refreshed report were tested. See [TC01–TC24 matrix](ACCEPTANCE.md).

## 18. Known Limitations

Configured live-service and real-device acceptance remain unverified. No automatic token refresh exchange, offline writes, notifications or mobile Excel export. Backend has no pagination, schedule term boundaries or canonical attendance rates. Class student history is scoped to the selected class. App is not claimed production-ready before these deployment checks.

## 19. Recommended Next Phase

Provision compatible mobile OAuth audiences without breaking desktop authentication; configure actual API/check-in URLs; test a complete real lecturer/student QR flow on Android; verify iOS on macOS. Then prioritize backend finalization atomicity and dated schedule metadata.

## 20. Reference Repository Safety

Initial and final reference Git status are clean. No source edits, installs, builds or migrations ran there. The mobile Git repository is independent and has no commit/push yet.

**FAP-Attendance-Desktop-System modifications introduced by this task: ZERO.**
