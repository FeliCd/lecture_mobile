# FAP ATTENDANCE REFERENCE AUDIT

Audited 2026-10-05 before implementation. Reference path: `C:\Users\ADMIN\Desktop\FAP-Attendance-Desktop-System`.
Mobile workspace: `C:\Users\ADMIN\Desktop\FPT-Lecturer-Mobile-App`; it is a sibling, not a child of the reference. Initial `git status --porcelain`: empty. Only source reads and Git status/metadata reads were performed there; no installs, tests, formatting, builds, or migrations were run there.

## Actual architecture

| Area | Evidence in reference repository | Findings |
|---|---|---|
| Languages, dependencies | `pubspec.yaml`, `pubspec.lock` | Dart SDK >=3.8; Flutter; Pub; http, crypto, secure storage, URL launcher, uuid, archive, xml, qr_flutter, file_picker |
| Frontend/desktop | `lib/main.dart`, `windows/`, `lib/features/*` | Flutter Material Windows app; Flutter tooling and Windows CMake; feature screens and repository interfaces |
| Backend | `backend/apps_script/Code.gs`, `appsscript.json` | Apps Script V8 JavaScript, SpreadsheetApp, Advanced Sheets service; HTTPS ContentService action endpoint |
| Database/ORM | `SCHEMA`, `read_`, `handle_` in `Code.gs` | Google Sheets is authoritative; no SQL database or ORM. Schema headers are checked; duplicate/empty IDs rejected |
| HTTP/DTOs | `lib/services/google_sheet_service.dart`, `docs/API_CONTRACT.md` | POST JSON action requests, Google ID token in body; `{ok:true,data}` / `{ok:false,error}`; 302/303 result redirect to Google ContentService |
| Auth | `lib/services/google_oauth_service.dart`, `lib/features/auth/auth_controller.dart`, `authenticate_` | Desktop browser OAuth, loopback callback, refresh token in secure storage; Google signature verification via tokeninfo; aud/iss/exp/email_verified/domain and unique lecturer record validated. No app-issued JWT or password system |
| Authorization | `authenticate_`, `rosterTarget_`, `handleSession_` | Identity comes from token; backend overwrites audit identity. Classes/rosters/sessions owned by lecturer. No client role switch or role field |
| Lecturer | `lib/models/lecturer.dart`, `SCHEMA.Lecturers` | lecturerId, lecturerCode, fullName, email, department |
| Course/Class | `lib/models/class_model.dart`, `SCHEMA.Classes`, `class_mapping_service.dart` | Subject fields represent course; Classes have classId and owner. Mapping uses normalized semester_subjectCode_classCode; require unique match |
| Student/roster | `lib/models/roster.dart`, `SCHEMA.Students`, `SCHEMA.Enrollments`, `handleRoster_` | Shared student identity via studentId/studentCode; schoolEmail; enrollment links class/student. `getRoster` uses semester, subjectCode, classCode |
| Schedule | `lib/models/schedule.dart`, `schedule_repository.dart`, `validateSchedule_` | Recurring ISO weekday 1–7, slot 1–12, HH:mm start < end, source IMAGE/MANUAL; uppercase codes. No semester start/end dates or holiday exceptions |
| Session | `lib/models/session_model.dart`, `handleSession_` | sessionId, classId, date, slot, times, status, currentToken, tokenExpiredAt, createdBy. OPEN/CLOSED/RESET; create reuses class/date/slot non-reset identity |
| Attendance | `lib/models/attendance_record.dart`, `attendance_repository.dart`, `handleSession_` | One student/session record; PRESENT/LATE/ABSENT mutations only. EXCUSED appears in Dart comment but is not accepted by backend. Manual correction allowed for owned OPEN/CLOSED sessions; preserves check-in timestamp |
| QR | `session_qr_widget.dart`, `student_checkin_url.dart`, `sessionView_`, `handleStudentCheckIn_` | 24-byte random token; 120s expiry; optional six-digit secret stored as token#secret. URL sessionId/token/mode/v=2; existing hosted check-in page. Server checks student Google identity, enrollment, expiry, presence confirmation, matching token/secret, duplicate record under ScriptLock |
| Reports | `lib/features/reports/attendance_report_screen.dart` | Derived from session attendance plus roster; missing rows displayed ABSENT. PRESENT/LATE/ABSENT separate. No Report table, server percentage formula, or aggregate report DTO |
| Excel | `excel_export_service.dart`, `markbook_reader.dart`, extension `shared/attendanceWorkbook.js` | Local OOXML XLSX generation and archive/XML parsing in Dart; SheetJS in extension. No network export action |
| Extension | `fap-attendance-extension/manifest.json`, `background/serviceWorker.js`, content scripts | Chrome MV3; DOM reading/writing stays in extension, transport to `http://127.0.0.1:8765` |
| Local-only | `integration_server.dart`, `google_oauth_service.dart`, `ocr_service.dart`, `assets/ocr_windows.ps1` | Loopback integration server, desktop OAuth callback, Windows OCR and file-picker save paths cannot be transplanted into mobile |
| Network accessible | `Code.gs`, `web_hosting/public/checkin.js` | Apps Script HTTPS and student web page are usable from phones with correct deployed configuration; actual live deployment not verified |
| Theme | `lib/core/theme/app_palette.dart`, `app_theme.dart` | Warm orange #E65C00, dark orange #AA4100, canvas #FFF9F5, Material styling |
| Errors/validation/logging | `AppException`, `validateSchedule_`, `importRoster_`, `doPost`, `SyncLogs` | Backend validation and safe wrapper needed because error strings travel in HTTP 200; ScriptLock for concurrency; backend Stackdriver configured |
| Date/time | `schedule_clock.dart`, `read_`, `appsscript.json` | Explicit UTC+7 campus clock; session dd/MM/yyyy normalized to yyyy-MM-dd; QR expiry UTC ISO; HH:mm strings retained |
| Tests | `test/*_test.dart`, `backend/test/*.test.cjs`, extension tests | flutter_test/flutter_lints, Node built-in tests. No reference tests executed to avoid generated files there |

## Source of truth and reuse

Students, classes, enrollment, sessions and attendance live in the remote Google Sheets workbook behind Apps Script. Schedules are also remote. Desktop repositories have explicit in-memory demo implementations, which are not production persistence. Mobile does not read spreadsheets directly, run a local attendance database, import desktop Dart paths, or contact desktop localhost.

Flutter can run on mobile: **YES**. Dart/models/contracts/validation concepts can be reused: **YES**. Desktop UI layouts, OAuth callback server, browser extension APIs, PowerShell OCR, filesystem save dialogs: **NO**. Native authentication preserves server verification semantics but needs compatible OAuth audiences and platform registration.

## Actual API audit

Every row below uses **POST `{APPS_SCRIPT_URL}`**, the deployed `/macros/s/{deployment}/exec` endpoint. These are action values, not invented REST routes. All lecturer actions include `idToken` in the JSON body.

| Area/action | Payload beyond action/token | Desktop use | Mobile reuse/change |
|---|---|---|---|
| Auth / `profile` | none | Lecturer profile after Google login | Reused; native OAuth audience provisioning required |
| Lecturer / `getRows` | sheet=Lecturers | Lecturer-owned rows | Profile is sufficient for MVP |
| Classes / `getRows` | sheet=Classes | Class selection/mapping | Reused |
| Classes / `getLecturerClasses` | optional lecturerId ignored server-side | Report fallback | Exists; mobile uses getRows |
| Schedule / `getRows` | sheet=Schedules | Weekly timetable | Reused |
| Schedule / appendRow/updateRow/deleteRow/batchUpdate | sheet=Schedules, row/id/rows | Schedule editing | Exists; mobile MVP is read-only schedule |
| Students / `getRoster` | semester, subjectCode, classCode | Enrolled roster | Reused |
| Students / `importRoster` | roster target, students | Desktop/extension import | Stays separate; not called by mobile |
| Sessions / `getRows` | sheet=Sessions | Owner-filtered sessions | Reused; excludes RESET locally |
| Sessions / `getSessionsByClass` | classId | Report fallback | Not used: code permits empty createdBy rows |
| Sessions / `createSession` | classId,date,slot,startTime,endTime,currentToken,currentSecretCode,tokenExpiredAt | Start or resume | Reused |
| Sessions / `closeSession` | sessionId | Close attendance | Reused; expects closed=true |
| Sessions / `resetSession` | sessionId | Reset and successor session | Exists; destructive reset excluded from MVP |
| Attendance / `getSessionAttendance` | sessionId | Joined attendance/student data | Reused |
| Attendance / `updateAttendance` | attendanceId,sessionId,studentCode,status,note | Manual correction/upsert | Reused; server chooses updatedBy and updatedAt |
| Attendance / `markAbsent` | sessionId,studentCodes | Missing attendance finalization | Reused after close; expects saved=true |
| Reports / `getClassHistory` | classId | History records | Reused; excludes reset sessions server-side |
| QR / `rotateToken` | sessionId,currentToken,currentSecretCode,tokenExpiredAt | QR rotation | Reused |
| Student web / `studentSessionInfo` | sessionId, student idToken | Existing web check-in | Not called by lecturer app |
| Student web / `studentCheckIn` | sessionId,student idToken,confirmPresent,token/secretCode/useSecret | Existing web check-in | Existing hosted page retains this responsibility |
| Export | **No action exists** | Desktop builds XLSX locally | Pending remote export; not faked |

## Limitations and recommended backend work (not performed)

1. **Lecturer OAuth audiences:** `authenticate_` accepts only `cfg.audience` = GOOGLE_CLIENT_ID. Native Google Sign-In needs a web/server client audience. Provision native app OAuth clients and either verify the existing configured audience is suitable, or add an explicit allowed lecturer audience list in a separately authorized backend task. Preserve the existing desktop audience; never turn off audience checks. No new auth endpoint is necessary. Expected response remains Lecturer DTO.
2. **Export:** propose an authenticated `exportSessionReport` action with sessionId; return `{downloadUrl, expiresAt, fileName}` only after ownership checks. Generate from the same roster/attendance semantics, short-lived URL and formula-safe XLSX cells. This is a proposal, never called by mobile.
3. **Schedule reliability:** add authoritative term boundaries and dated exceptions before automatic reminders, cancellation status, or cross-term current/next inference. Proposed schedule metadata: semester, startDate, endDate, campusTimezone, exceptions; enforce lecturer ownership.
4. **Scale:** existing getRows/getClassHistory responses have no pagination. Propose owner-filtered cursor/page-size support and aggregated class reports. Mobile makes batch calls, not one call per student, but cannot add real server pagination itself.
5. **Finalization:** closeSession and markAbsent are separate, non-atomic operations. Mobile exposes safe retry for missing absences. A future server action could close and finalize under one lock/transaction.
6. **Security hardening:** fix getSessionsByClass's empty-owner fallback; validate session date/time/token expiry limits server-side; use structured error codes. Client checks cannot replace these backend controls.
7. **History:** no enrollment effective dates, so missing historical attendance cannot reliably distinguish a late enrollment from absence. Mobile does not invent class-wide rates or implicit historical enrollment.

Can implement now: compatible client, native auth plumbing, mobile screens, server mutations, QR contract, report views, states and tests. Requires deployment/backend work: actual mobile OAuth authorization and configured live endpoints; remote export; notifications; date exceptions; pagination. No FAP APIs or credentials are accessed.
