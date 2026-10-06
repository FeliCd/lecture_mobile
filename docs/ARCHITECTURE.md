# FPT LECTURER MOBILE ARCHITECTURE PLAN

This plan was stated before implementation in the conversation after the reference audit.

Selected technology: Flutter and Dart. This preserves the existing UI ecosystem, http transport, secure-storage package, qr_flutter renderer, model terminology and server contracts. Native Android/iOS hosts replace Windows. The standalone package is `lecturer_companion`; Android identifier `vn.edu.fpt.lecturer_companion`; iOS `vn.edu.fpt.lecturerCompanion`.

```text
Mobile screens → LecturerRepository → ApplicationApi / AppsScriptApi
                                    → HTTPS Apps Script → existing Google Sheets
Native Google Sign-In → ID token → backend identity/lecturer verification
Secure vault → short-lived ID token; no plaintext cache or password
```

## File-by-file ownership

| Files | Responsibility |
|---|---|
| lib/main.dart | Composition and configured production client |
| lib/app/app.dart | Auth boundary and login; navigator recreated on logout |
| lib/app/shell.dart | Home, today/week schedule, class index, report index, profile; five bottom destinations |
| lib/features/auth/auth.dart | Native identity adapter, secure vault, backend-verified auth state |
| lib/features/classes/class_screen.dart | Class details, roster search, saved summary, student class history |
| lib/features/sessions/session_screen.dart | Date confirmation and session detail |
| lib/features/attendance/attendance_view.dart | Search/filter, server-confirmed corrections, completion/retry, report view |
| lib/features/attendance/qr_screen.dart | QR expiry, regeneration, secret mode, foreground polling |
| lib/api/client.dart | Strict HTTPS endpoint, token body, redirect policy, timeouts, safe error mapping |
| lib/api/repository.dart | Actual action contracts, owner filtering, duplicate guards, write acknowledgments |
| lib/models/domain.dart | Compatible DTOs, mapping key, campus time/date helpers |
| lib/core/* | Environment, exceptions, Material theme, loading/error/empty components |
| config/*.example.json | Separate development/production build configuration without credentials |
| android/, ios/ | Independent platform projects, signing and native configuration |
| test/ | Contract, business-flow, auth and phone-layout tests; fixtures never imported by production |
| docs/ | Audit, architecture, acceptance and known deployment gaps |

State strategy: AuthController is ChangeNotifier; async loaders hold server snapshots; widget state holds selected tab, semester, filters and forms. No extra state library. Mutation completion reloads server data; returned child routes refresh parents. No offline write queue. Secure vault stores only the ID token and never authorizes by its decoded claims; backend profile verification is required on restart. Expiry requires sign-in again; native SDK manages its own credentials, no copied desktop refresh-token exchange or client secret.

Attendance belongs to a server session and enrolled student. CLOSED corrections are permitted by the reference. EXCUSED cannot be submitted. RESET cannot be edited. Finalization closes first and then marks missing enrolled records absent; partial failure has an explicit retry action. Reports are derived from exactly these records. Session reports label inferred missing-row absences; class summaries show saved counts only, avoiding unsupported historical rates.

QR retains the existing student website and security protocol. No phone-side student login, camera scanning, scraping or bypass. Rotate only after lecturer action; expiry hides the code until regeneration. Poll every 15 seconds only while foreground, without overlapping requests; hide QR on network uncertainty. Secret is displayed separately and never embedded in the URL.

Design: Material 3, dark orange controls from the reference palette, cream background, cards instead of tables, safe areas, 48+ dp actions, search, status text plus color, pull-to-refresh, keyboard-aware correction sheet. Network screens have explicit loading/error/retry/empty content. Campus time is UTC+7 in one utility; date-only strings never undergo local timezone conversion.

Future: reliable reminders after dated schedule metadata exists; push only with a justified backend; notes isolated from attendance; remote Excel export; aggregate metrics once backend definitions exist. Offline attendance needs a separately designed queue, idempotency keys, conflict policy, enrollment checks and session-state reconciliation. It is not silently enabled.

Reference-only files and source evidence are catalogued in REFERENCE_AUDIT.md. All files in the reference remain read-only. There are no runtime filesystem imports, copies of desktop integrations or symlinks to that project.
