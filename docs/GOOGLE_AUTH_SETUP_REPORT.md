# GOOGLE AUTH CONTINUATION REPORT

Updated 2026-10-06. Live deployment v1 and rejection of an invalid Google token verified. Real Google/lecturer login remains NOT TESTED.

## 1. Current Google Cloud Project

Account: phucvhla2@gmail.com. Project: FPT Lecturer Mobile, natural-nimbus-510805-v3 (391831771866). Verified: YES, in Cloud Console during setup. External / Testing. Test user: phucvhla2@gmail.com. Mobile scopes: openid, userinfo.email, userinfo.profile.

## 2. OAuth Clients

Android Client ID: `391831771866-qct1fos78auh2sqautn9steqifehkpgi.apps.googleusercontent.com`.
Package: `vn.edu.fpt.lecturer_companion`.
SHA-1: `82:C5:37:A8:8B:AB:43:E8:64:32:44:B7:89:D0:EB:70:3F:61:A8:69`.
Web/Server Client ID: `391831771866-i4vajc479qjuiflghp7ur325383nah5n.apps.googleusercontent.com`.
Same Google Cloud project: YES. No Web client secret is used in Flutter.

## 3. ID Token Audience

Flutter serverClientId and backend expected aud: Web/Server Client ID above.
Actual ID-token aud: NOT OBSERVED; no real user token captured. Installed google_sign_in_android 7.2.17 forwards serverClientId to the Android Google credential request. This establishes the expected audience, not a measured real-token result. Android client registers package/signature; its ID is not the server audience.

## 4. Apps Script Properties

GOOGLE_MOBILE_CLIENT_ID: Web/Server Client ID above. SET: YES, verified in live project settings.
GOOGLE_CLIENT_ID: same Web ID for this fresh backend; one unique allowed audience.
SCHOOL_DOMAINS: fpt.edu.vn,fe.edu.vn.
SPREADSHEET_ID: `1hLM3Lh6TpT_bl1HojpVBMW39CxMDVfgl9LFeh6d_cJs`.
GOOGLE_WEB_CLIENT_ID for the separate student website remains unset. No lecturer was automatically registered.

## 5. Apps Script Deployment

Script: FPT Lecturer Mobile Backend, owned by phucvhla2@gmail.com.
Script ID: `1IPaEgA6UieuZ3SyCVq6iKzT5bWv_WeBioMkG_K5VoV24dN6wMf_OqjVa`.
Deployment ID: `AKfycbz34PP5DgY6ibpIRRJe0a9Nz596cqsyMeJFGY7jgAvrpebxIhkyT2zlNJfNrJlv7mrI`.
URL: https://script.google.com/macros/s/AKfycbz34PP5DgY6ibpIRRJe0a9Nz596cqsyMeJFGY7jgAvrpebxIhkyT2zlNJfNrJlv7mrI/exec
Latest local Code.gs plus Setup.gs deployed: YES, version 1, 2026-10-06 13:57 local time.
Execute as owner; access Anyone, explicitly confirmed by user before deployment. This does not share the spreadsheet publicly.
Deployment URL changed: YES. Config previously referenced the old backend under the former setup. User requested a new spreadsheet under their sole account; this new project had no deployment, so its first deployment was created and config was updated.

## 6. Backend Verification

Invalid token: PASS against live /exec via anonymous POST profile. Response: ok=false, 'Phiên Google không hợp lệ. Đăng nhập lại.'
Valid Google identity: NOT TESTED.
Audience validation: PASS in local mocked tests; real-token live audience validation NOT TESTED.
email_verified: ENFORCED. Issuer and expiry: ENFORCED.
Allowed domains: exact fpt.edu.vn or fe.edu.vn.
Lecturer uniqueness: exactly one matching record required. Zero or duplicate records rejected.
Backend tests: 10/10 PASS, including upstream token rejection, audience, expiry, issuer, unverified email, Gmail, domain spoof and lecturer uniqueness.

## 7. Flutter

flutter analyze: PASS, no issues.
flutter test: PASS, 30/30.
Debug APK: PASS, built with new endpoint and Web serverClientId.
Android run: see final execution update below.
Google Account Chooser: NOT TESTED.
Run: `powershell -ExecutionPolicy Bypass -File scripts/run-android.ps1`.

## 8. phucvhla2@gmail.com

Google Authentication: NOT TESTED end to end.
Lecturer Authorization: EXPECTED FAIL, verified by local policy tests, not a live Gmail login.
Reason: Gmail is the administrator/test account, outside allowed lecturer domains. No lecturer bypass added.

## 9. FPT/FE Lecturer Account

NOT TESTED. Requires a real authorized school account and exactly one matching Lecturers row in the new spreadsheet.

## 10. Remaining Security Improvement

Application-owned JWT/session: NOT IMPLEMENTED. This should be the next authentication architecture task; it does not block the current Google OAuth configuration. Current app stores the Google ID token in secure storage and revalidates the profile; token expiry requires sign-in again.

## 11. iOS

Deferred: YES.

## 12. Release Signing

Deferred: YES. Debug signing only.

## 13. Files Changed

Continuation work: config/development.json (ignored local configuration); backend/apps_script/Code.gs; backend/apps_script/Setup.gs; backend/apps_script/appsscript.json; backend/test/auth.test.cjs; docs/GOOGLE_AUTH_SETUP_REPORT.md; docs/GOOGLE_ANDROID_SETUP.md. Evidence: artifacts/deployment-success.jpg.
Earlier setup changes retained: README.md; android/app/build.gradle.kts; lib/api/client.dart; lib/features/auth/auth.dart; test/client_test.dart. No unrelated changes reverted.

## 14. Remaining Blockers

Real Google account chooser and valid school lecturer login require interactive account testing and an authorized school lecturer record. New data spreadsheet has no lecturer/course data seeded.
The existing STUDENT_CHECKIN_URL still references the separate old student website; its backend integration has not been migrated to the new spreadsheet. Student check-in end to end is not established by this OAuth setup.
