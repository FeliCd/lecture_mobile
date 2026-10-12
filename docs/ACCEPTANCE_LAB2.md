# Acceptance matrix — Lab 2

| Spec area | Implemented and verified | Outstanding verification/limitations |
|---|---|---|
| 0.1 Android build | Debug APK build PASS; Pixel_7 install and native lecturer/student attendance integration PASS | Physical camera scan/manual visual QA and release signing pending; owner chose local backend |
| Auth/role | 2 roles, active profile, guards, 4 tabs/role; widget revocation PASS; emulator auth/rules PASS | Real Firebase and native Google setup pending |
| QR | backend signed slots/version/expiry, membership, duplicate transaction, finalization; integration PASS | Camera scan with two devices and permission denial manual QA |
| Analytics | finalized-only, eligible snapshot, excused/late formula, charts/drilldown/filters/safe CSV | Excel device export/manual QA; aggregate reads tailored to Lab class sizes |
| News | two sources, keywords/date/sort/page/cache/share/resources; live metadata smoke with supplied OpenAlex key PASS | RSS optional omitted; offline phone cannot call server cache |
| Quiz/Poll | private answers, single response, deadlines, live stats, reveal-after-close; integration PASS | Join by class implemented; join-code entry not implemented; fixed reveal policy |
| Rules | default deny/server-only writes/assigned vs unrelated/self vs other/disabled/anonymous; emulator PASS; cloud Rules/index deploy PASS | Cloud Functions await Blaze; owner selected local Emulator instead |
| Import/export | CSV preview/validation/pending mapping via operator tool; safe Flutter export | CSV apply emulator-only; production operator workflow and Sheets integration pending |
| UI | one orange-white theme, Vietnamese locale, dark/light, responsive reusable widgets/navigation tests | Device visual QA, 360/393/430 screens with all full feature data, contrast/device scanner QA not all exercised |
| Seed/docs | synthetic users/classes/history/quiz/poll/resources/open QR fixtures, setup/demo/mapping/test logs | Real operator provisioning and real two-device recording |

Known optional features not implemented: Google Sheets live import/export, notifications, audited attendance correction, bookmarks, schedule week view, iOS release, multi-question quizzes/AI. No FAP API synchronization or full LMS expansion.

Do not treat legacy documents or legacy tests as verification of Firebase Lab 2. See TEST_REPORT.md for split evidence.
