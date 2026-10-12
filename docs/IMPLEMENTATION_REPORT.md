# Refactor implementation report — 11/10/2026

> Thiết kế giao diện, Google-only Mobile, phòng học và kiểm thử mới: [MOBILE_UI_UX_REDESIGN_REPORT.md](MOBILE_UI_UX_REDESIGN_REPORT.md). Báo cáo đó thay thế các mô tả UI/auth Mobile cũ bên dưới.

> Cập nhật tiếp theo: [ATTENDANCE_SLOT_REFACTOR_REPORT.md](ATTENDANCE_SLOT_REFACTOR_REPORT.md) thay thế mô tả form tạo phiên, duration Mobile tối đa 240 phút và deadline Desktop 4 giờ trong báo cáo này. Báo cáo dưới đây giữ nguyên bằng chứng của đợt refactor trước.

This report describes local implementation against [the supplied blueprint](REFACTOR_BLUEPRINT.md). The previous report is preserved in [IMPLEMENTATION_REPORT_LEGACY.md](IMPLEMENTATION_REPORT_LEGACY.md). Cloud deployment and real-account E2E are separate acceptance gates; no historical deployment report is evidence for this refactor.

## Phase 0 — Audit

| Area | Present | Missing / mismatch / risk | Decision |
|---|---|---|---|
| Mobile entry | main.dart → lab2/app.dart; lecturer guard, Riverpod/GoRouter | README advertises student/quiz; quiz disabled | Keep lecturer-only; correct docs |
| Authoritative data | Apps Script + Sheets; Desktop repository in ../FAP-Attendance-Desktop-System | Multiple writers use different paths | Preserve action names, columns and envelope; share mutation helpers |
| Authentication | Firebase token verified through Google; email/domain/roster ownership | Student code bypass; web switch exposes it | Default deny legacy code; verified identity required even when opt-in |
| Session | Frozen roster on mobile, lock + batch writes, expiry check | Desktop creates lack frozen roster; expiry settlement only on snapshot | Add metadata at Desktop creation, installable reconciliation trigger |
| Corrections | Reason and updatedBy | No immutable audit; Desktop cell writes non-atomic | Add AttendanceAudit; atomic record+audit |
| Statistics | Closed-only, CSV escaping, 15%/20% thresholds | LATE/EXCUSED collapsed; policy unknown | Preserve raw status, withhold ambiguous rates until admin config |
| Live attendance | Full snapshot every 30 sec | No focused polling/freshness | Session endpoint; foreground-only bounded polling |
| Timetable/import | OCR local ML Kit; Excel/CSV preview + validation; recurring timetable | No dated exception table | Additive occurrence model in later phase |
| Content | OpenAlex/Crossref metadata, cache, private Firestore library | Research only; no RSS/subject configuration/bookmark delete | Subject Insights pipeline and compatible library extension |
| Rules | Owner UID + verified email; strict article keys | New content fields/deletion require rules migration | Add optional validated fields; keep old records readable |
| Tests | Unit/widget, Apps Script VM, portal jsdom, emulator Functions/rules, native smoke sources | Real cloud concurrency/E2E unverified | Keep test layers distinct; no simulated throughput claims |

Baseline evidence: preceding audit Flutter 74/74; rerun backend/web 35/35; flutter analyze --no-pub completed with No issues found (59.7s). Source Desktop read to identify createSession/rotateToken/resetSession/closeSession/updateAttendance/markAbsent consumers. Existing working tree contained extensive uncommitted work before this request; preserved it, no reset/clean performed.

## Phase 1 — P0: an toàn danh tính và quyết toán

### Đã kiểm tra

`Code.gs` có các writer Desktop/Web khác với `Lab2Free.gs`: MSSV thuần có thể bypass identity, Desktop chưa chụp roster, sửa điểm danh chưa có audit nguyên tử. LATE/EXCUSED bị gộp trên Mobile. QR token và thời hạn phiên cần hai giá trị riêng.

### Đã triển khai

- `backend/apps_script/Code.gs`: Google/Firebase verified email ánh xạ duy nhất vào Students; xác minh identity trước write lock, đọc lại session/token/roster trong lock. Retry PRESENT/LATE trả receipt gốc, không ghi trùng. CLOSED/expired không báo thành công giả.
- `backend/apps_script/AttendanceSafety.gs`: reconciliation idempotent, tối đa 25 phiên/lần; trigger mỗi phút; correction record + audit trong cùng Sheets batch. Actor server-derived, có before/after/reason/time; retry cùng trạng thái và lý do không thêm audit.
- Desktop create/reset chụp roster tối đa 400 người; close chung helper; rotate không kéo dài phiên. Desktop QR TTL giữ riêng; phiên mới có giới hạn 4 giờ từ lúc tạo/reset. Mobile dùng thời lượng đã chọn, tối đa 240 phút. Phiên cũ không chụp roster không được tự suy diễn roster lịch sử.
- `web_checkin/public/checkin.js`: luôn dùng Google kể cả QR URL cũ; bỏ nút chuyển sang MSSV.
- `domain.dart`, `widgets.dart`, `classes.dart`, `class_attendance_overview.dart`: giữ 4 trạng thái riêng trong UI, filter, thống kê và export. PENDING phiên OPEN không tính vắng. Không tự dựng LATE từ thời gian lịch sử.

### API/Schema

Giữ nguyên action/envelope và cột Sessions/Attendance/Students của Desktop. Thêm `AttendanceAudit`; giữ `Lab2SessionMeta`. `ALLOW_VERIFIED_STUDENT_CODE` mặc định OFF; bật `true` vẫn bắt buộc identity Google khớp đúng MSSV. Hai Script Properties `ATTENDANCE_LATE_COUNTS_PRESENT` và `ATTENDANCE_EXCUSED_IN_DENOMINATOR` chấp nhận `true`/`false`; chưa đặt là unknown. Khi dữ liệu có trạng thái liên quan và thiếu policy, Mobile hiển thị đếm riêng và chưa tính tỷ lệ. Ngưỡng cảnh báo 15%, giới hạn >20% giữ nguyên.

### Kiểm thử

Backend/Web phase 1: 39/39 (`artifacts/refactor-phase1-backend.log`); Flutter phase 1: 74/74 (`artifacts/refactor-phase1-flutter.log`). Bao gồm raw MSSV default-off, giả danh, token rotate/expiry, frozen roster, audit atomic, batch lỗi/retry và reconciliation không cần snapshot. Test 50 writer là mô phỏng tuần tự deterministic, không chứng minh throughput Apps Script thật.

### Rủi ro / bước tiếp theo

Trigger và scope mới cần owner cài trong deployment thật. Spreadsheet editor có thể sửa Sheet trực tiếp; append-only ở cấp API không thay quyền quản trị workbook. Desktop hiện có bridge FAP chỉ ánh xạ PRESENT/LATE/ABSENT và từ chối EXCUSED; cần quyết định nghiệp vụ khi đồng bộ EXCUSED sang FAP, không tự gộp thành ABSENT. Đọc/ghi shared Sheets và Student Google Web vẫn giữ contract. Không chỉnh nguồn Desktop trong đợt này.

## Phase 2 — P1: Mobile giảng viên

### Đã kiểm tra

Navigation cũ đặt các công cụ và thao tác lớp trên nhiều màn; host dùng snapshot lớn 30 giây. Lịch định kỳ và nhập OCR/Excel/CSV đã có, giữ lại.

### Đã triển khai

- `app.dart`, `today.dart`: 4 tab Hôm nay / Lịch dạy / Lớp học / Cập nhật; Avatar mở tài khoản/công cụ. Home lấy lịch và phiên thật, chọn học kỳ nếu không rõ, mở lại phiên một chạm hoặc mở form đã điền rồi xác nhận tạo phiên.
- `classes.dart`: 4 tab Sinh viên / Điểm danh / Buổi học / Thống kê; giữ import roster, export CSV, tìm kiếm và drilldown.
- `live_attendance.dart`: QR lớn, countdown theo offset giờ server, counts 4 trạng thái + pending, tìm MSSV/tên, lọc, sửa có lý do, rotate, close. Poll endpoint riêng mỗi 8 giây foreground; lỗi backoff đến 60 giây; pause background, dừng khi CLOSED; giữ dữ liệu cũ có nhãn stale khi mất mạng. Lỗi auth/ownership xóa dữ liệu riêng tư và dừng poll.
- `desktop_sync.dart`: live/content/QR read không kéo thêm full snapshot. Mutation vẫn refresh nguồn dùng chung; snapshot thông thường 30 giây.

### API/Schema

`lab2Call(name=getAttendanceSessionLive, input={sessionId})`: ownership server; response session summary, roster cần thiết, counts, `serverTime`, `expiresAt`, `lastUpdatedAt`, `revision`. Không trả QR token/secret trong endpoint roster. Đây là polling, không tuyên bố realtime push.

### Kiểm thử

11/11 bài chọn lọc phase 2 (`artifacts/refactor-phase2-flutter.log`): pause/resume, stale failure, stop CLOSED, home không tự tạo phiên, điều hướng và lịch. Kiểm thử tổng thể bên dưới bao gồm layout 360px, dark và chữ lớn 1.8x.

### Rủi ro / bước tiếp theo

Endpoint chỉ trả session đang xem nhưng Sheets vẫn đọc bảng để tra cứu; cần đo độ trễ với workbook thật. Không quảng cáo 8 giây như SLA. Hôm nay đổi ngày khi màn được rebuild; chưa có notification nền.

## Phase 3 — P1: Subject Insights

### Đã kiểm tra

Discover research trước đây yêu cầu search và chỉ có OpenAlex/Crossref; thư viện Firestore cá nhân đã có schema và ownership. Không dùng fixture trong production.

### Đã triển khai

- `SubjectInsights.gs`: môn lấy từ Classes authoritative và gộp theo subjectCode; kiểm quyền trước cache/network. Owner cấu hình keywords/exclusions/sourceIds trong Sheet. Seed PRM393/PRN212/WDP301 chỉ khi môn có thật, không overwrite cấu hình.
- NEWS từ RSS/Atom Android Developers / .NET Blog / web.dev; RESEARCH Crossref hoặc OpenAlex. URL nguồn phải khớp exact allowlist; key chỉ Script Properties. Title/excerpt sanitize, không full-text/AI; nguồn không có excerpt hiển thị chưa có mô tả. DTD/entity XML bị từ chối.
- Cache NEWS 6h / RESEARCH 24h, cooldown 120s kể cả nguồn lỗi, tối đa 2 nguồn/lượt, 24 item/feed, <=45.000 ký tự/feed, <=400 cache rows; maintenance xóa tối đa 100 cache rows đã hết hạn >7 ngày. Timeout upstream 10s/nguồn; request keyword giới hạn 4 x 80 ký tự. Network nằm ngoài write lock.
- Dedupe DOI/canonical HTTPS URL; cursor ràng buộc bộ lọc và feed version; query/date/source/latest/relevance. Nguồn lỗi trả partial/cache và nhãn stale kèm thời điểm fetch thật.
- `subject_updates.dart`: tự tải môn đầu tiên không bắt nhập từ khóa; NEWS / RESEARCH / Đã lưu; filters, load-more, provenance và link gốc.
- `article_library.dart` và hai Firestore rulefiles: save, sửa ghi chú, bỏ lưu owner UID + verified email; thêm optional contentType; bookmark cũ vẫn đọc được.

### API/Schema

Thêm `getSubjectTopics`, `getSubjectUpdates`; không có public force-refresh bỏ cooldown. Bảng `SubjectContentConfig`, `ContentSourceRegistry`, `SubjectContentCache`. Mặc định không có config thì trả empty rõ ràng. Preferences cá nhân tùy chọn chưa bổ sung; cấu hình hiện thuộc owner và filter màn hình.

### Kiểm thử

Backend/Web phase 3: 44/44 (`artifacts/refactor-phase3-backend.log`). Firestore Emulator kiểm cả `articles.rules` và `firestore.rules`: 2/2, CRUD owner / deny user khác / deny unverified / legacy schema (`artifacts/refactor-rules.log`). Probe HTTP nguồn thật: Android 25 entries, .NET 10, web.dev 10, tất cả có ngày parse được (`artifacts/refactor-source-probe.log`). Public HTTP probe không chứng minh Apps Script deployment hoặc relevance với lớp thật. Widget test xác minh auto load, filters, stale/provenance, không bịa mô tả.

Primary references: [UrlFetchApp timeoutSeconds](https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app), [ScriptApp scopes/triggers](https://developers.google.com/apps-script/reference/script/script-app), [Crossref REST](https://www.crossref.org/documentation/retrieve-metadata/rest-api/), [OpenAlex search](https://help.openalex.org/api/searching/). Upstream cold fetch tối đa hai nguồn x 10s; còn authentication/Sheet latency, vì vậy phải đo tổng trên Apps Script thật.

## Phase 4 — P2: công cụ lớp, lịch và tích hợp

### Đã triển khai

- `ClassTools.gs`: exception CANCELLED/RESCHEDULED/MAKEUP/ROOM_CHANGED/RESTORED theo schedule + date; validate owner/lớp/môn/học kỳ, date/time/slot, lý do, overlap. Không sửa buổi đã có session; guard tại cả Mobile và Desktop create/reset. Không thay recurring Schedules.
- `class_tools.dart`: form thao tác theo ngày và sửa tên/email sinh viên có lý do, MSSV bất biến. Hồ sơ Students toàn cục có enrollment của lecturer khác bị từ chối và yêu cầu admin xử lý; email trùng/domain sai bị từ chối. Students + RosterAudit commit cùng batch; retry idempotent.
- `timetable_domain.dart`, `today.dart`, `timetable.dart`, `class_timetable.dart`: overlay ngoại lệ vào lịch Mobile, dời sang đúng target day, lịch gốc tuần sau giữ nguyên. Session thực tế override slot định kỳ. Snapshot trả ScheduleExceptions theo quyền lớp.
- README và architecture thay mô tả lịch sử bằng luồng hiện hành. Hướng dẫn deployment/rollback và kiểm thử thật ở dưới.

### API/Schema

Thêm `saveScheduleException` và `updateClassStudent`. Bảng `ScheduleExceptions`, `RosterAudit`; không đổi keys/cột bảng Desktop. Desktop cũ chưa render calendar exceptions; backend chặn mở buổi đã hủy/dời dù client hiển thị lịch định kỳ cũ. Cần dùng lịch Mobile để chọn occurrence mới hoặc cập nhật Desktop calendar trong một đợt riêng.

### Kiểm thử tổng thể tại máy

| Lệnh / lớp kiểm thử | Kết quả | Bằng chứng |
|---|---|---|
| `flutter test` Mobile | 80/80 PASSED; có kiểm thử auth ownership | artifacts/refactor-final-flutter.log |
| `flutter analyze --no-pub` | No issues found (8.6s, final rerun) | artifacts/refactor-final-analyze.log |
| `node --test backend/test/*.cjs web_checkin/test/*.cjs` | 48/48 PASSED | artifacts/refactor-phase4-backend.log |
| `npm --prefix functions test` | 5/5 | artifacts/refactor-functions.log |
| `scripts/start-lab2-backend.ps1 -Test -SkipInstall` | 7/7 Emulator integration; đã shutdown | artifacts/refactor-final-emulator.log |
| Firestore articles rules Emulator | 2/2 | artifacts/refactor-rules.log |
| `flutter build apk --debug --dart-define-from-file=config/lab2.free.json` | PASSED, plugin KGP/native-access warnings | artifacts/refactor-final-apk.log |
| Desktop `flutter test` | 44/44 PASSED ở full rerun; vòng 1 có 1 pumpAndSettle timeout, isolated test 1/1 pass | artifacts/refactor-desktop-flutter.log, refactor-desktop-isolated.log, refactor-desktop-rerun.log |

Emulator Functions là regression của chế độ cũ, không phải kiểm chứng Apps Script/Sheets thật. Node host 24 khác deployment Functions Node 22; CLI đã cảnh báo. Không nâng SDK/plugin trong phạm vi refactor này.

## Migration và triển khai

### Bổ sung xử lý lỗi initializer INVALID_SHEET_IDS

Log người vận hành cho thấy verifyLab2Free hoạt động nhưng setupLab2Free dừng tại lab2Read_. Chưa biết bảng chính xác từ stack cũ. Source initializer trước đó đọc strict cả Lab2Feeds/Lab2ArticleCache trong khi runtime đã cho phép cache rebuildable có dòng ID lỗi/trùng; đã đồng nhất setup với cache reader hiện hành. Attendance/meta/audit/config vẫn strict. Thêm diagnoseLab2Sheets() owner-only read-only và log setupError kèm bảng/số dòng ID thiếu/trùng; không log ID/email/token hoặc sửa/xóa dữ liệu. Cập nhật Lab2Free.gs, save, chạy diagnoseLab2Sheets rồi setupLab2Free. Nếu bảng nghiệp vụ lỗi, đối chiếu backup và tham chiếu trước khi sửa; không tự sinh UUID hoặc xóa dòng. Regression backend/Web: 49/49 PASSED (artifacts/refactor-sheet-setup-fix.log).

Kiểm tra read-only sau phản hồi về lỗi backend: URL trong `config/lab2.free.json` hiện trả HTTP 200, `lab2-shared-sheets-v2`, đủ 4 capabilities, authConfigured=true. `node scripts/probe-shared-backend.cjs` PASSED và xác minh request không xác thực bị từ chối. Đây là bằng chứng deployment đang phục vụ v2; chưa xác minh header/bảng Sheet, trigger hoặc luồng với account thật. Agent không thực hiện cloud mutation trong lần kiểm tra này. Nếu vẫn thấy SHARED_BACKEND_SETUP_REQUIRED, owner chạy setupLab2Free để kiểm bảng; đồng thời kiểm app được build bằng config free.

1. Backup workbook toàn bộ và source/version Apps Script hiện tại; ghi deployment ID và URL đang dùng Desktop/Mobile/Web. Đối chiếu header/ID trùng trước khi làm; không chạy dữ liệu test trên workbook nghiệp vụ.
2. Cập nhật cùng một Apps Script project: `Code.gs`, `Lab2Free.gs`, `AttendanceSafety.gs`, `SubjectInsights.gs`, `ClassTools.gs` và `appsscript.json`. Giữ Advanced Sheets service và timezone Asia/Ho_Chi_Minh. Manifest bổ sung `script.scriptapp` cho trigger; owner cần authorize lại. Không tạo project/backend song song.
3. Owner chạy `setupLab2Free()`: thêm bảng/header thiếu, validate bảng có sẵn; không reorder/overwrite header đang có. Nếu schema mismatch thì dừng và đối chiếu backup. Không backfill roster lịch sử từ lớp hiện tại.
4. Xác nhận Script Properties hiện hữu cho workbook/Firebase/OAuth/Web URL. Để raw-code OFF. Chốt policy hai booleans với người phụ trách trước khi tính rate LATE/EXCUSED. OpenAlex key optional server-only; Crossref không cần private key.
5. Owner chạy `seedSubjectInsights()`; kiểm config nguồn/keywords môn thực tế. Registry chỉ cho phép nguồn đã allowlist trong code, sửa Sheet tùy ý không tạo SSRF. Có thể owner chạy `pruneSubjectContentCache()` định kỳ; không public action.
6. Owner chạy `installAttendanceReconciliation()`; kiểm chỉ một trigger, lần chạy thành công và quyền. Deploy version mới trên deployment cũ để URL giữ nguyên. `lab2Health` phải trả `lab2-shared-sheets-v2` với capabilities mới.
7. Deploy Firestore library rules phù hợp project hiện hành: bản free dùng `firebase.articles.json`; không deploy Functions chỉ để chạy shared mode. Deploy Student Web bằng `firebase.checkin.json`, giữ public runtime config đúng URL/Firebase; cấu hình Google provider/authorized domains như trước.
8. Build APK với config ignored hiện hữu rồi cài thiết bị test. Chạy checklist thật bên dưới trước phát hành. Đợt này không cập nhật cloud, không claim deployment v29 cũ đã có refactor này.

## Rollback

- App/UI: có thể quay APK trước nếu lỗi giao diện; backend mới vẫn giữ actions/cột/envelopes cũ. Giữ metadata/audit/exception và rules optional contentType để không mất record mới.
- Feed: đặt SubjectContentConfig.enabled=false để tắt feed lỗi; attendance độc lập. Cache rebuildable được prune, không xóa bookmark hay attendance.
- Trigger lỗi: owner tạm tắt trigger và theo dõi/chốt phiên bằng backend an toàn; hết hạn vẫn chặn check-in. Không revert sang raw MSSV hoặc writer thiếu audit/ownership chỉ để khôi phục UI.
- Exception: trước khi rollback logic calendar, khôi phục occurrence hợp lệ bằng RESTORED khi chưa có session; giữ lịch sử/bảng mới. Không xóa Sheet exception vì Desktop client cũ chưa hiểu.
- Backend: giữ bản security patch Phase 1 tối thiểu khi rollback Phase 2–4. Nếu buộc rollback schema/API, xuất audit/metadata và kiểm các phiên OPEN trước; không khôi phục toàn bộ workbook backup đè lên check-in sau backup.

## Acceptance còn cần trên môi trường thật

- [ ] Lecturer Google thật → home → tạo/resume phiên → Student Google Web thật → live phản ánh → close → Mobile thống kê/CSV → Desktop reload/export. Đối chiếu row và cùng sessionId.
- [ ] Student sai email, outsider, giả MSSV, token rotate, QR expiry, CLOSED/reset đều bị chặn; web không có raw-code fallback.
- [ ] 50 student accounts test riêng gửi gần đồng thời, retry mất response và close xen kẽ. Đo p50/p95, số lỗi LOCK_BUSY/RATE_LIMITED, retry outcomes và unique (sessionId,studentId). Không dùng một token giả làm 50 người; không chỉ đếm HTTP 200 vì Apps Script trả lỗi trong JSON envelope.
- [ ] Cho phiên hết hạn, đóng Mobile hoàn toàn; trigger vẫn chốt đúng roster snapshot. Không mất/trùng khi close/check-in tranh chấp trên Sheets thật.
- [ ] Tin tức/research qua Apps Script thật đúng môn, source outage/cache, quota và cold fetch; bookmark save/edit/delete với hai Firebase accounts thật.
- [ ] Ngoại lệ lịch xuất hiện đúng Mobile; Desktop create guard; Student web đang mở bị chặn nếu session đóng. Quyết định chính thức EXCUSED khi gửi FAP và Desktop policy/report.
- [ ] Camera/QR và lifecycle trên Android thật; Windows Desktop tương tác thật; iOS build/device chưa kiểm tra.

Đã hoàn thiện triển khai và kiểm thử local theo các phase. Những acceptance trên chưa có tài khoản/phiên test riêng và bằng chứng chạy deployment thật, nên không đánh dấu production ready.
