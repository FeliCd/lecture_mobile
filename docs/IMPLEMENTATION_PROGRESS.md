# Implementation progress — 08/10/2026

> Source Mobile hiện hành 11/10/2026: Google-only, 4 tab Hôm nay/Lịch dạy/Lớp học/Cập nhật, phiên từ lịch với duration 5/10/15/20/30 phút và phòng hiệu lực. Xem [MOBILE_UI_UX_REDESIGN_REPORT](MOBILE_UI_UX_REDESIGN_REPORT.md). Mô tả email/password, form phiên thủ công và deployment cũ trong tài liệu này là lịch sử, không chứng minh source mới đã được triển khai cloud.

User request: rebuild the existing mobile project following the supplied MD and ask for integration config when needed. The MD is a product/technical requirements reference, not a separate user or system message. Spec copy: LAB2_SPEC.md. No remote deployment, production user provisioning or changes to existing Apps Script/Sheets were performed.

### Phase 0 — Audit & plan
- DONE: audited root Flutter Android/iOS app, pubspec, existing auth/repository/domain/Apps Script/legacy tests, tooling and initial clean Git state. Current repo had no Firebase/News/Quiz/student mobile. Adapted root project instead of restructuring into apps/.
- MODIFIED FILES: docs/ARCHITECTURE.md, docs/LAB2_SPEC.md; old README/architecture preserved in LEGACY_*; main_legacy.dart retains former entry point.
- SECURITY DECISIONS: no alleged FAP API, no scraping, no direct live Sheets writes, no destructive git commands.
- TEST COMMANDS / RESULTS: installed Flutter/Dart, Node, Java, Firebase CLI found; Android SDK found. `flutter devices --machine` and `flutter emulators`: no Android device/AVD available.
- SCREENSHOTS/BUILD ARTIFACTS: Android debug APK generated later in Phase 6.
- BLOCKERS & REMAINING: external Desktop checkout not present at the historical audit paths; map Lab 1 fields from current source/reference docs, without claiming direct Desktop verification.
- NEXT PHASE: foundation.

### Phase 1 — Theme, auth, roles, classes
- DONE: one orange/white Material 3 theme, dark/light/system persisted settings, Vietnamese locale, shared buttons/cards/status/async widgets; Firebase bootstrap and emulator config; email/password auth, optional Firebase Google credential exchange when client ID configured; authoritative active role profile and GoRouter guards. Four destinations per role, home/classes/class detail, manual teaching session creation.
- MODIFIED FILES: lib/main.dart, lib/lab2/{app,theme,widgets,domain,repository,classes}.dart, pubspec.yaml/lock, config/lab2.*.json, scripts/seed.cjs.
- SECURITY DECISIONS: no self-registration/role selection; unknown/inactive profiles stay at login; profile revocation removes private navigator; role never inferred from email. Secrets stay off mobile. Theme persistence stores no credentials.
- TEST COMMANDS / RESULTS: unit/widget/navigation tests PASS; tests verify correct 4 tabs, theme retains tab selection and revoked profile returns login.
- SCREENSHOTS/BUILD ARTIFACTS: native screenshots still need device/AVD; widget tests run at small phone sizes and text scale 1.5.
- BLOCKERS & REMAINING: Firebase real config and Google provider/SHA/client ID not supplied yet. System sans-serif fallback; Inter font not bundled. Native Google sign-in not live tested.
- NEXT PHASE: attendance.

### Phase 2 — QR attendance
- DONE: create/open session, server signing/120s slots/version/expiry, student native scanner, live host counts/names, duplicate-resistant transaction, membership snapshot, late status, atomic absent finalization/retry, timeout record reconciliation. Camera permission declarations and emulator-only manual token entry.
- MODIFIED FILES: functions/src/{index,domain}.ts, firebase/firestore.rules, lib/lab2/attendance.dart, Android/iOS manifests.
- SECURITY DECISIONS: signing secret Secret Manager in production, explicit emulator-only test secret; no client attendance writes; deterministic IDs; server time and membership checks; rate limits. Emulator-only trusted clock hook avoids flaky real-time slot tests and is ignored in production.
- TEST COMMANDS / RESULTS: final Emulator integration PASS: lecturer wrong class rejected, student forbidden host token, outsider/tamper/expired rejected, simultaneous check-in creates one record, closing produces nine absences plus one attendance, close retry stable. Rules tests PASS.
- SCREENSHOTS/BUILD ARTIFACTS: APK; physical camera/two-phone scan pending.
- BLOCKERS & REMAINING: real Firebase deploy pending. Automatic scheduler is not executed by current emulator suite; manual close available and deadlines enforced server-side. Atomic finalization cap 400 students.
- NEXT PHASE: analytics.

### Phase 3 — Analytics & CSV
- DONE: finalized-only statistics, late attended/excused excluded, N/A for no eligibility, risk threshold >=3 eligible sessions and <80%; absence today/total, semantic stacked bars + legends, session/student drilldown, date/status/student filters, sorting, BOM/CRLF/escaped safe CSV export. CLI roster preview/import with row errors, duplicate validation and pending UID mapping.
- MODIFIED FILES: classes.dart, widgets.dart, domain.dart, scripts/import-roster.cjs, functions/test/csv.test.cjs, test/lab2_analytics_test.dart.
- SECURITY DECISIONS: class-scoped + UID-scoped student reads; one shared roster stream for lecturer names; no peer attendance data in student UI; import is trusted operator-only and emulator apply refuses cloud.
- TEST COMMANDS / RESULTS: formulas/CSV tests PASS. Finalization integration verifies record count/integrity. Analytics UI fixture test checks cancelled/open exclusion and excused denominator; result in TEST_REPORT.md.
- SCREENSHOTS/BUILD ARTIFACTS: CSV generated through platform share API; Excel native opening needs device/manual QA.
- BLOCKERS & REMAINING: production roster import requires reviewed operator process; no mobile Admin/import screen intended. Data queries suit Lab-sized classes/kỳ, not unbounded production history.
- NEXT PHASE: news.

### Phase 4 — Subject News/Research
- DONE: OpenAlex/Crossref backend adapters, subject taxonomy, debounce, source/date/sort/page controls, DOI/URL normalization, cache 6h, bounded retry/timeout and stale fallback, metadata details/external links, assigned same-subject class sharing and student resources. Seed docs fixtures marked [DEMO FIXTURE] and excluded from live feed.
- MODIFIED FILES: functions/src/news.ts, lib/lab2/news.dart, article/share collections, seed fixtures.
- SECURITY DECISIONS: fixed external endpoints, HTTPS URLs, no WebView HTML/full-text scraping, API key backend-only, class ownership/subject checks for sharing, article budgets per UID.
- TEST COMMANDS / RESULTS: adapter unit PASS, share authorization integration PASS, opt-in live smoke PASS: Crossref 20 metadata results, OpenAlex 14 valid results (unauthenticated-key public access during emulator test, not verification of user's key).
- SCREENSHOTS/BUILD ARTIFACTS: API output sample recorded in TEST_REPORT.md.
- BLOCKERS & REMAINING: user said an OpenAlex key exists but has not configured it here. RSS optional not implemented. Total device offline cannot invoke backend feed cache; existing resources may use Firestore local cache. No fabricated article fallback.
- NEXT PHASE: interaction.

### Phase 5 — Live Quiz/Poll
- DONE: create one-question quiz/poll, 2–5 choices, private correct option, scheduled/open/published transitions, 1–15min, one student response transaction, stats stream, option distributions, manual close/reveal and student own chosen option. Reconcile lost response against server document.
- MODIFIED FILES: lib/lab2/quiz.dart, functions/src/index.ts, quiz Rules/tests.
- SECURITY DECISIONS: quizPrivate denied even for lecturer client; correct answer only in server-published result after close; stats private to host before reveal; unique UID response IDs; deadline/membership/options enforced by server. Stable stream subscriptions survive countdown/theme changes.
- TEST COMMANDS / RESULTS: Emulator PASS: unauthorized teacher/outside student rejected, parallel submit accepts once, result unavailable before publish, counts/correctCount match response, deadline rejects, poll contains no correct answer. Widget validation/navigation tests PASS.
- SCREENSHOTS/BUILD ARTIFACTS: APK; no real device video recorded.
- BLOCKERS & REMAINING: P0 joins from class activity list; no join-code input. Reveal policy fixed to after closing. Activity edit/delete and multi-question are not included in this prototype.
- NEXT PHASE: hardening/documentation.

### Phase 6 — Hardening & handoff
- DONE: retained legacy code/tests, localized known errors, dark/large-text widget tests, setup/env templates, Emulator-only seed/operator helpers, source docs/mapping, demo guide, Android integration smoke source, debug APK build. Actual final test outputs/status in TEST_REPORT.md.
- MODIFIED FILES: README.md, docs/{SETUP,ARCHITECTURE,DATA_DICTIONARY,DEMO,TEST_REPORT,IMPLEMENTATION_PROGRESS}.md, scripts/start-lab2-backend.ps1, scripts/run-android.ps1, .vscode/launch.json, integration_test/.
- SECURITY DECISIONS: no cloud deploy without target config; no secrets tracked; no default production credentials; release keeps HTTPS and signing requirement; App Check optional and not claimed configured.
- TEST COMMANDS / RESULTS: final `flutter analyze --no-pub` PASS (No issues found); full Flutter suite PASS 39 including analytics UI test; `npm test` PASS 5; Emulator suite PASS 4; live API smoke PASS 1; Android debug APK PASS. Actual results in TEST_REPORT.
- SCREENSHOTS/BUILD ARTIFACTS: build/app/outputs/flutter-apk/app-debug.apk. No screenshots/video fabricated.
- BLOCKERS & REMAINING: real Firebase config/billing/provisioning, Google's native flow/SHA, App Check activation, Android camera/device smoke, iOS build, scheduler deployment/manual poor-network QA. Google Sheets live sync, notifications, audited corrections/bookmarks remain P1, not implemented.
- NEXT PHASE: connect supplied project and perform native two-user demo once configuration/device is available. P0 implementation is available for emulator-backed testing; full production/device Definition of Done is NOT marked complete.

### Owner integration update — 08/10/2026
- DONE: verified Firebase Android project/app/package, generated ignored real project config, saved provided OpenAlex key backend-only, direct authenticated OpenAlex HTTP 200, added VS Code launch target for real Firebase project.
- BLOCKERS: Auth CONFIGURATION_NOT_FOUND; Firestore API disabled/uninitialized (403); CLI account inventory has only old project, so deploy access is unverified. Billing status still needs confirmation. Cloud Secret Manager/backend/Rules/profiles not deployed. Google OAuth client absent from supplied JSON.
- NEXT: owner enables Auth email/password and Firestore, confirms Blaze, authenticates CLI with correct project access; then deploy secured backend/Rules and provision real approved users/classes (never seed emulator accounts into production).
- RECHECK: after owner created services, Auth configuration is reachable; Firestore error changed to caller permission denied. CLI still lists only the old project. Backend smoke with supplied OpenAlex key PASS (1 test; OpenAlex 14, Crossref 20 items). Await correct CLI login/provider/billing confirmation before cloud deploy.
- BUILD: debug APK targeting supplied Firebase project PASS; saved to ignored `artifacts/lab2-firebase-debug.apk`. Emulator APK retained at `artifacts/lab2-emulator-debug.apk`. Build success does not imply cloud deployment or a working real-account login.
- CLOUD UPDATE: correct CLI access verified; Firestore database available (`nam5`). Backend TypeScript build PASS. Firestore Rules and declared indexes deployment PASS. Secret creation rejected because Firebase reports project is not on Blaze; Functions/scheduler/secrets await active billing. Real user/class provisioning still pending; no production demo accounts created.
- EMULATOR CHOICE: owner selected free Firebase Emulator and Android Studio AVD. Startup now auto-seeds and holds the local demo; optional `-NoSeed`/`-SkipInstall`. Android launcher automatically handles USB port forwarding for physical phones. Pixel_7 booted and emulator APK installed successfully. Android SDK integration verification in progress.
- EMULATOR VERIFIED: native Android lecturer/student attendance test PASS (22s); emulator-only callable HTTP transport avoids Android Firebase Installations dependency on real configuration. Auth/Firestore retain native SDKs. Flutter suite PASS 39; final analysis PASS; main emulator APK rebuilt PASS and saved to `artifacts/lab2-emulator-debug.apk`. Optical camera scanning and manual full-screen QA remain outstanding.
### Owner change: free shared Desktop data — 09/10/2026

- DONE: shared Sheets source through existing Apps Script, Firebase verified-email Auth, mapped roles/ownership, QR/atomic attendance writes, fixed server deadlines and frozen membership, OpenAlex/Crossref metadata/cache/sharing, no Firebase paid backend dependency. Quiz hidden in this mode, Emulator retained.
- LIVE: Apps Script version 25 on existing endpoint, four new Lab2 tabs, empty Attendance header initialized without records. Existing 12 classes/223 students/672 enrollment links/2 sessions verified; both news providers return 20 results. Original cloud Code preserved except routing hook.
- VERIFIED: Flutter 42 tests; free UI/transport 6; backend 18; Desktop legacy 21; native free Android smoke 1; deployed health/auth rejection probe. Details in TEST_REPORT.
- HANDOFF: run `scripts/run-android.ps1` with default `config/lab2.free.json`; email must match Desktop and be verified in Firebase. Owner completes personal sign-in. Free means within service quotas; Sheets data is not mirrored into Firestore. Camera/iOS remain unverified.

