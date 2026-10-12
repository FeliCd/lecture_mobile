# Lab 2 test report — 08/10/2026

Environment: Windows, Flutter 3.47.4 stable, Dart 3.13.3, Node 24.13.0, Java 21, Firebase CLI 15.30.1. Functions deployment engine configured Node 22. Firebase project used for all writes/tests: `demo-fap-lab2` Emulator. No real user/student data, no cloud deploy or production key verification.

| Command / test | Actual result | Scope / limits |
|---|---|---|
| `flutter analyze --no-pub` | PASS final rerun: `No issues found!` (~38s) | Entire app, integration smoke source, tests and retained legacy code. Test-only brace lint repaired. |
| `flutter test --no-pub` | PASS final suite: `+39: All tests passed!` (~10s) | 30 retained legacy tests + 9 new domain/UI/navigation/analytics tests. Does not prove native SDK/camera or real Firebase login. |
| `flutter test --no-pub test/lab2_analytics_test.dart` | PASS: `+1: All tests passed!` | Analytics widget uses marked fixture repository, verifies finalized/open/cancelled and 66.7% excused denominator; included in final 39. |
| `cd functions; npm test` | PASS: 5 tests / 5 pass / 0 fail | QR HMAC/expiry/slots/tamper; attendance formula; metadata URL/DOI/dedup; 429 retry; CSV parse/row errors. No live API required. |
| `firebase emulators:exec --project demo-fap-lab2 --only auth,firestore,functions "node scripts/seed.cjs && cd functions && node --test test/emulator.cjs"` | PASS: 4 tests / 4 pass / 0 fail; script exited 0 | Real emulator Auth + Firestore Rules + Admin transactions + callable protocol. Last deterministic run took ~99s after emulators started. |
| `cd functions; node --test test/news-live.cjs` with running seeded emulators | PASS: 1 test / 1 pass / 0 fail | Actual metadata from both external sources; keyless public OpenAlex access, not user's key. External smoke opt-in, network/quota dependent. |
| `flutter build apk --debug --no-pub --dart-define-from-file=config/lab2.emulator.json` | PASS: `Built build\app\outputs\flutter-apk\app-debug.apk` | Final successful build after manifest fix; incremental run ~58s. No installation/device run. |
| `git diff --check` | PASS exit 0 | CRLF conversion warnings only. |
| `flutter devices --machine`; `flutter emulators` | BLOCKED native execution | Windows/Chrome/Edge found, no Android device; `No emulators available.` |
| `flutter test integration_test/lab2_smoke_test.dart -d <android-device-id> --dart-define-from-file=config/lab2.emulator.json` | BLOCKED / not run | No Android device/AVD. Source supplied for actual Firebase SDK two-role flow on device. |
| Real Firebase Google auth, Rules/index deploy, signing/App Check/cloud scheduled job | BLOCKED / not run | Owner project config/access/billing/provider/SHA/key not supplied; no production verification claimed. |
| iOS build/camera/physical two-phone QA/Excel export/video | BLOCKED / not run | Windows host/no physical test devices. |

## Emulator coverage

- Positive/negative Rules: assigned lecturer vs class of another lecturer, student own record vs classmate, private answer denial for both roles, server-only writes, no role upgrade, outsider/anonymous/disabled rejection, correct class-scoped queries.
- Attendance: class ownership, deterministic session open anti-duplicate, student cannot fetch host token, outsider/tampered/expired QR rejected, parallel valid calls create exactly one record, finalize gives 10 records (1 attended + 9 absent), retry does not duplicate, closed session rejects check-in.
- Quiz: lecturer assignment, no answer in public quiz doc, membership, two submits create one response and stats, no stats/results/private answer exposure before publish, reveal only after close, result count/correct count exactly one, expired poll rejected, poll has no correct answer.
- Share: unrelated/wrong-subject class denied, assigned same-subject share readable by member, outsider denied.

## Actual external source output

```text
{"source":"Crossref","count":20,"cached":false,"sampleTitle":"Hello Flutter","sampleUrl":"https://doi.org/10.1007/978-1-4842-5181-2_1"}
{"source":"OpenAlex","count":14,"cached":false,"sampleTitle":"Google Flutter Mobile Development Quick Start Guide","sampleUrl":"https://openlibrary.org/books/OL28386490M/Google_Flutter_Mobile_Development_Quick_Start_Guide"}
live scholarly sources through authenticated callable (no fixtures): PASS
```

Counts are observations of that one request, not stable provider guarantees or feed completeness. Articles without title/HTTPS URL are discarded. Production key/quota not tested.

## Issues found and repaired during implementation

- Initial seed path used a package subpath as a filesystem require; fixed with createRequire from functions/package.json.
- Initial student history query lacked classId and Rules correctly rejected it; client now loads each enrolled class separately and query tests pass.
- Missing-response document was denied before quiz submit; Rules now permit only absent deterministic own response get, while existing response ownership/class checks remain.
- QR integration test straddled a real 120s slot boundary; trusted emulator-only deterministic clock added. Production continues using actual server clock.
- Debug cleartext manifest initially conflicted with main HTTPS policy; tools:replace applied to debug overlay. APK build passed after repair.
- Parser/ConsumerWidget signatures/lint issues repaired; legacy tests stayed passing.

Build warnings retained from upstream plugins: Kotlin Gradle Plugin application compatibility warning with future Flutter releases; Java source/target 8 obsolete warning and unchecked Firestore library operations. Current debug build succeeds. Do not upgrade unrelated SDKs to suppress warnings without compatibility tests.

## Remaining QA

360/393/430dp full-feature native screens, text scale 1.3–1.5 across every route, camera grant/deny and brightness/QR scanning, background/resume, airplane mode, request loss/reconciliation, scheduler deployment, real Google/Firebase account setup, CSV sharing/Excel, iOS. Automated widget tests currently cover shared UI at 360dp/scale1.5 and role navigation at 393dp, plus analytics fixture correctness. No screenshots/video fabricated.

## Final verification after all source changes

- `flutter analyze --no-pub`: PASS, no issues.
- `flutter test --no-pub`: PASS, 39 tests.
- `npm test`: PASS, 5 tests.
- Combined emulator + live source run: `firebase emulators:exec --project demo-fap-lab2 --only auth,firestore,functions "node scripts/seed.cjs && cd functions && node --test test/emulator.cjs test/news-live.cjs"`: PASS, 5 tests, 0 failures, script exit 0 (~85s of tests). Uses latest full seed fixtures and emulator public-access sentinel; no Secret Manager access errors in this run.
- Latest APK rebuild: PASS (~38s), `build/app/outputs/flutter-apk/app-debug.apk`, 230920293 bytes. Built with USE_EMULATORS=true and debug signing; not a production package.
- `git diff --check`: PASS. Secrets/local production configuration untracked/ignored. No cloud changes or deployment performed.

## Owner configuration received — 08/10/2026

- Parsed supplied google-services.json and verified project, app ID and Android package all match. Wrote ignored `config/lab2.production.json`; API key not repeated in this report.
- Saved supplied OpenAlex key only in ignored backend `.secret.local`. Direct request with Bearer header: HTTP 200, one actual metadata result. No key in Dart/mobile config/tracked source.
- Firebase Auth public configuration probe: HTTP 400 `CONFIGURATION_NOT_FOUND`; Authentication initialization/provider setup pending.
- Firestore databases list: HTTP 403 API has not been used or is disabled for `fap-attendance-88920`; database/API activation pending.
- Firebase CLI project inventory lists only `fap-attendance-cba45`; deploy access to owner project has not been established. No deployment attempted, no fallback to old project.
- Supplied Android config has no OAuth clients; native Google sign-in remains unconfigured. Email/password is the intended first login provider.

### Recheck after owner created Firebase services

- Authentication configuration probe now succeeds. This confirms Auth initialization, not an actual email/password login or provider enablement.
- Firestore list now returns HTTP 403 `The caller does not have permission`, replacing the earlier disabled-API error. CLI still lists only the old project; access to the supplied project remains blocked.
- Backend live-source smoke using the supplied OpenAlex key: PASS, 1 test, 0 failures, emulator script exit 0. Authenticated callable returned 14 OpenAlex and 20 Crossref items in this run. Cloud Secret Manager and cloud functions have not been deployed.
- Android debug build with `config/lab2.production.json`: PASS (`assembleDebug`, 451.9s). Copied to ignored `artifacts/lab2-firebase-debug.apk`; this targets the real project but cloud backend/access/provider/provisioning setup remains incomplete. Emulator APK preserved separately as `artifacts/lab2-emulator-debug.apk`.

### Cloud deployment update — 08/10/2026

- CLI now lists the correct project `fap-attendance-88920`; permission blocker resolved. Default Firestore database is available (location `nam5`).
- `npm run build`: PASS.
- `firebase deploy --only firestore --project fap-attendance-88920 --non-interactive`: PASS, exit 0. Rules compiled and released; both declared composite indexes deployed. Index creation may continue asynchronously.
- OpenAlex Secret Manager creation attempt rejected by Firebase because project is not on Blaze and `secretmanager.googleapis.com` cannot be enabled. No secret value printed; temporary input file removed.
- Functions, scheduler and cloud secrets remain undeployed pending active billing. Real approved Auth accounts, role profiles, subjects/classes/members are still required; emulator seed has not been run against cloud.

### Free Emulator / Android Studio run — 08/10/2026

- Owner selected local Firebase Emulator and Android Studio AVD. Pixel_7 booted; emulator APK installed successfully.
- Startup helper now automatically seeds synthetic data and holds the demo running; `--ui` enables the dashboard. Android launcher automatically reverse-forwards emulator ports for physical USB phones.
- Native test exposed Android callable SDK Firebase Installations requirements. Emulator-only adapter now calls the documented callable HTTP protocol with local Auth ID token; production retains native SDK. Auth/Firestore use their native SDKs, server permission/QR logic is unchanged.
- Final native integration: `flutter test integration_test/lab2_smoke_test.dart -d emulator-5554 --no-pub --dart-define-from-file=config/lab2.emulator.json`: PASS, 1 test, 22s. Validates lecturer login/navigation, create session/open attendance/get signed token, student login/check-in, server Firestore record, lecturer close, logout. Does not exercise optical camera scanning.
- `flutter test --no-pub`: PASS, 39 tests after local transport changes. Main APK rebuild and final analysis are recorded below when complete.
- Final `flutter analyze --no-pub`: PASS, no issues (35.5s).
- Main emulator debug APK rebuild: PASS (98.2s), copied to `artifacts/lab2-emulator-debug.apk`. This is the main app, not the integration-test entrypoint.
- Final runtime: fresh seeded Auth/Firestore/Functions backend running with UI HTTP 200 at `http://127.0.0.1:4000`; main APK installed and launched on Pixel_7 (`emulator-5554`). `git diff --check` PASS. Services are local processes and require restarting after shutdown.
### Shared Desktop free deployment — 09/10/2026

- Owner changed scope to real Desktop sync with no billing dependency; Quiz hidden. Firebase Auth stays real, Sheets is authoritative, no Firestore mirror.
- Apps Script existing deployment updated to version 25 with the same URL/access settings. Original cloud Code preserved except the three-action routing hook; original backup in ignored `artifacts/apps-script-original.gs`. Deployment screenshot: `artifacts/apps-script-deployment.jpg`.
- `setupLab2Free`: PASS on cloud. Attendance was completely empty; existing initializer created its schema header. No attendance rows or demo accounts created in production.
- Owner-only `verifyLab2Free`: PASS. Existing 4 lecturers, 12 classes, 223 students, 672 enrollments, 2 sessions; Attendance 0. OpenAlex 20/Crossref 20 real articles, stale false. Article caches populated only, no personal data printed.
- `node scripts/probe-shared-backend.cjs`: PASS on deployed endpoint; health correct and authenticated-only snapshot rejects absent ID token. Legacy login authentication guard still present.
- `node --test backend/test/*.test.cjs`: PASS 18 (10 existing auth tests + 8 shared backend tests: role isolation, atomic/idempotent create, QR duplicate/secret checks, fixed deadlines/frozen membership, Google token lookup validation, legacy route compatibility, fixed-window rate limit).
- Desktop `node --test backend/test/*.test.cjs`: PASS 21 existing tests. User's existing working-tree changes preserved.
- `flutter test`: PASS 42. Free configuration navigation/transport tests PASS 6; revoked profile, three destinations and private redirect handling checked.
- Native `flutter test integration_test/lab2_free_smoke_test.dart -d emulator-5554 --dart-define-from-file=config/lab2.free.json`: PASS 1 (10s after build/install); verifies real Firebase project, no Quiz, actual Android HTTPS Apps Script health, free login/registration UI. Signs out old synthetic emulator credentials; creates no accounts/attendance.
- Debug APK built for free real-data config, main APK at `artifacts/lab2-free-debug.apk`. SDK plugin warnings remain non-fatal. Real-account login and optical QR require the owner's email verification/login; personal passwords were not requested or used. Firestore/Functions are not called by the free data path.


- Final verification: flutter analyze PASS no issues (25.5s); free navigation PASS 3; main free APK build PASS (63.8s), copied to artifacts/lab2-free-debug.apk (230941788 bytes), installed/launched on Pixel_7. git diff --check PASS. Temporary local source-transfer server stopped; credentials/config and backups remain Git ignored.
