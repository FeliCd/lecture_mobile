# Báo cáo refactor phiên điểm danh theo buổi học — 11/10/2026

Phạm vi: thực hiện yêu cầu `REFACTOR ATTENDANCE SESSION FLOW` trên Mobile Flutter, backend Apps Script dùng chung và các điểm tương thích Desktop. Mã nguồn chính: `C:/PRM/lecture_mobile`; Desktop: `C:/PRM/FAP-Attendance-Desktop-System`. Không deploy production, không ghi/xóa dữ liệu Google Sheets thật, không thay cột production. Các thay đổi có sẵn trong working tree trước nhiệm vụ được giữ nguyên.

## 1. Audit và dependencies — PHASE 1

| Thành phần đã đọc | Luồng cũ / vấn đề tìm thấy | Xử lý |
|---|---|---|
| `classes.dart`, `desktop_session_dialog.dart` | Form nhập slot, giờ, tên phiên; nút tạo độc lập trong danh sách phiên | Dialog chỉ đọc thông tin buổi học, chỉ chọn duration; danh sách phiên dẫn sang Lịch của lớp |
| `today.dart`, `timetable_card.dart`, `class_timetable.dart`, `app.dart` | Today mở form; card lịch dẫn qua chi tiết lớp; lịch lớp bỏ buổi đã qua | Cùng gọi `openAttendanceForPeriod`; giữ buổi quá khứ để xem lịch sử |
| `timetable_domain.dart`, `domain.dart` | TeachingPeriod thiếu selector schedule/exception; so giờ trong ngày không xử lý overnight | Bổ sung selector vào model hiện có, tính khoảng tuyệt đối UTC+7; thông báo lỗi nghiệp vụ |
| `repository.dart`, `desktop_sync.dart` | Auth và snapshot đã có; mutation refresh toàn bộ snapshot | Tái sử dụng repository/sync, thêm action đọc occurrence không kích hoạt full snapshot |
| `Lab2Free.gs`, `Code.gs` | Mobile/Desk tạo theo dữ liệu giờ client; Desktop deadline 4 giờ; kiểm ngoại lệ chưa resolve đầy đủ | Dùng một resolver/server validation, giữ action cũ và khóa phiên cũ |
| `AttendanceSafety.gs`, `ClassTools.gs` | Có live/finalize/audit/frozen roster/reconciliation và ngoại lệ lịch | Tái sử dụng; trả hạn/thời lượng thực tế, kiểm xung đột lịch qua nửa đêm |
| Student Web và check-in handlers | Google identity, QR/secret, receipts, rate limit và khóa đã có; MSSV cũ được bảo vệ | Giữ action/envelope; regression auth/roster/deadline/secret/receipt |
| Desktop repository/model/attendance/QR | Ngày thiết bị; tự dựng expiry sau rotate; QR không nhận token/secret mới từ Mobile; OPEN hết hạn có thể tiếp tục hiển thị | UTC+7 selector, duration 10 phút; nhận server receipt, deadline không gia hạn, đọc lại trạng thái/QR chung |

Dependencies giữ nguyên: Firebase Auth của Mobile, Google identity của Desktop/Web, GoRouter/Riverpod, Apps Script V8/LockService, Advanced Google Sheets API, workbook chung, bảng Schedules/Classes/Enrollments/Sessions/Attendance và các bảng mở rộng đã có. Firestore chỉ phục vụ thư viện bài viết trong shared mode. Không thêm service/model cạnh tranh với repository hoặc TeachingPeriod hiện có; `ScheduleAttendance.gs` là helper backend chung.

Audit tất cả đường gọi liên quan:

- `createClassSession`: shared Mobile mới chỉ gọi trong `DesktopSessionDialog.submit` sau xác nhận.
- `getTeachingOccurrence`: dialog đọc trạng thái trước; không tạo session khi chọn slot.
- `openAttendanceSession`: API tương thích chỉ trả ID của phiên OPEN hợp lệ, không đổi thời gian. UI cũ chỉ còn cho Firebase emulator, được chặn trong shared mode.
- `getQrToken`, `rotateAttendanceQr`: Live Attendance dùng phiên thực tế; QR/secret không đổi closesAt.
- `closeAttendanceSession`: xác nhận và chốt trong Live; Desktop `closeSession` gọi cùng helper finalize.
- Desktop `createSession`, `resetSession`, `rotateToken`: vẫn tồn tại, dùng luật backend chung; không thể tạo ngoài lịch/cửa sổ hợp lệ.

## 2. Luồng mới — PHASE 2–4

```mermaid
sequenceDiagram
  participant L as Mobile giảng viên
  participant B as Apps Script
  participant S as Sheets chung
  participant W as Student Web
  L->>B: Chọn slot / getTeachingOccurrence + identity + selector
  B->>S: Resolve lịch + ngoại lệ + phiên hiện có trong lock
  B-->>L: Thông tin chỉ đọc / trạng thái / giờ server
  alt AVAILABLE và giảng viên xác nhận
    L->>B: createClassSession + selector + durationMinutes
    B->>S: Validate lại; một batch Sessions + Lab2SessionMeta
    B-->>L: sessionId thực tế + opensAt + closesAt + thời lượng hiệu lực
  else OPEN hoặc CLOSED
    L->>L: Tiếp tục / xem kết quả với sessionId server
  end
  L->>B: Live + QR của sessionId thực tế
  W->>B: Google identity + QR + secret nếu bật
  B->>S: Kiểm lại phiên/roster trong lock và ghi receipt
  L->>B: Xác nhận kết thúc
  B->>S: Một batch CLOSED + ABSENT còn thiếu
```

Ba điểm vào Hôm nay, Lịch dạy và Lớp → Lịch đều dùng một dialog/helper. Thông tin môn/lớp/ngày/slot/giờ/phòng chỉ đọc. Chọn 5, 10 mặc định, 15, 20 hoặc 30 phút. Không có input tên phiên/ngày/giờ/slot. Loading khóa nút và đóng dialog trong lúc submit; timer đọc lại trạng thái 15 giây, ngừng request khi app ở background, đọc lại lúc resume. Không có lịch thì hướng dẫn quản lý lịch/buổi bù, không dựng phiên giả.

Backend dùng Classes thuộc giảng viên + Schedules cùng giảng viên/học kỳ/môn/lớp. Hủy/dời loại buổi gốc; dời/bù dùng ngày/slot/giờ của ScheduleExceptions; đổi phòng/khôi phục áp dụng override. Occurrence ID là hash scheduleId, ngày, exceptionId; được tính từ dữ liệu thật, không thêm cột. Selector ngày client chỉ dùng tìm occurrence hợp lệ; không phải quyền tự tạo một buổi học. Thời gian/title giả do client gửi bị bỏ qua.

- `opensAt = serverNow`.
- `closesAt = min(serverNow + durationMinutes, scheduledEndAt)`.
- Chỉ tạo trong ngày của occurrence, từ `scheduledStartAt - 15 phút` đến trước `scheduledEndAt`, còn ít nhất 60 giây.
- 08:00–09:30: 07:44 bị từ chối, 07:45 được mở; 09:25 chọn 30 phút chỉ nhận 5 phút; 09:29:01 và 09:30 bị từ chối.
- UTC+7 là nguồn diễn giải ngày/giờ. End nhỏ hơn start nghĩa là kết thúc hôm sau; end bằng start bị từ chối. Buổi 23:30–00:30 vẫn giữ sessionDate gốc, mở lúc 00:25 được 5 phút. Slot ngày tương lai không mở ở ngày trước dù nằm trong khoảng 15 phút trước giờ.

| Trạng thái server | Giao diện / hành vi |
|---|---|
| AVAILABLE | Chọn duration và xác nhận; backend kiểm lại tại submit |
| NOT_YET | Chỉ xem, hiển thị thời điểm sớm nhất; không form tạo |
| ENDED | Buổi đã qua, không tạo mới |
| TOO_SHORT | Còn dưới 1 phút, không tạo mới |
| OPEN còn hiệu lực | Tiếp tục QR/live, giữ opensAt/closesAt/roster cũ |
| OPEN hết hạn | Reconcile trong lock, trả CLOSED; không gia hạn |
| CLOSED | Xem kết quả; sửa qua audit có lý do, không mở lại |
| RESET không có successor | Không tự tạo lại; yêu cầu xử lý reset từ Desktop |
| Nhiều phiên không RESET cùng khóa | Lỗi dữ liệu; không chọn bản đầu/xóa dữ liệu |

Khóa chống trùng vẫn là `classId + sessionDate + slot`, kể cả lịch sử chưa có occurrenceId. Retry sau mất phản hồi nhận cùng ID/receipt, không cần clientRequestId mới. Trong Desktop, reset là thao tác riêng có xác nhận, chỉ thực hiện trong cửa sổ của occurrence; ghi phiên cũ RESET, phiên mới và metadata trong cùng batch, giữ bản ghi điểm danh lịch sử. Retry reset cũ dùng successor duy nhất.

## 3. Snapshot, QR và tính toàn vẹn

Chụp student IDs từ Enrollments tại mở phiên, cap 400 người. Roster thêm sau mở không đi vào phiên cũ. Google/Firebase verified email phải khớp đúng một Students row; ownership/enrollment được kiểm phía server. Check-in kiểm OPEN, token, deadline, snapshot và secret nếu bật. Đúng tại closesAt bị từ chối. Gửi lặp hợp lệ trả receipt gốc; bản giảng viên đã chỉnh không bị ghi đè; duplicate attendance rows gây lỗi.

MSSV cũ mặc định tắt. Nếu owner bật `ALLOW_VERIFIED_STUDENT_CODE`, vẫn cần identity đã xác minh và MSSV thuộc identity đó. Không bật cờ này trong nhiệm vụ.

Check-in, create, reset, close, rotate, correction và reconciliation sử dụng script lock. Verify identity qua mạng trước write lock; reread phiên/roster trong lock. Một Advanced Sheets `batchUpdate` chứa cả Sessions và Lab2SessionMeta lúc tạo/reset; close chứa CLOSED và ABSENT còn thiếu; correction chứa Attendance và AttendanceAudit. Không coi các lần setValues độc lập là transaction có rollback. Khi request ghi đã commit nhưng response mất, retry đối chiếu dữ liệu có sẵn.

PENDING là trạng thái suy ra từ snapshot khi chưa có record và phiên chưa chốt. PRESENT/LATE/ABSENT/EXCUSED và audit giữ nguyên. Check-in mặc định PRESENT theo policy hiện có; nhiệm vụ không tự đặt mốc LATE hoặc đổi quy định tính tỷ lệ. Chốt không ghi đè LATE/EXCUSED hay trạng thái giảng viên đã chỉnh. Dialog kết thúc hiện đã điểm danh và còn chờ. Live lấy hạn từ server và tính countdown với server offset.

Trigger `reconcileExpiredSessions` mỗi phút giữ nguyên; fallback khi đọc occurrence/live/snapshot và Desktop list giúp chốt dù trigger trễ. Trigger xử lý tối đa 25 phiên mỗi lượt. Phiên legacy thiếu metadata không được tự chụp lại roster lịch sử; fallback giữ hạn lịch và các record đã có. Không rewrite dữ liệu cũ để giả định thời điểm mở thật.

## 4. API và đồng bộ

| API | Contract hiện tại |
|---|---|
| `lab2Call/getTeachingOccurrence` mới | Input classId, sessionDate (hoặc date), slot và optional scheduleId/exceptionId/occurrenceId/sessionId. Output thông tin authoritative, state, serverTime epoch, earliestOpenAt, remainingMinutes; receipt nếu có |
| `lab2Call/createClassSession` | Endpoint giữ nguyên. Input selector + durationMinutes thuộc 5 giá trị. Output sessionId/classSessionId/attendanceSessionId thực tế, status, opensAt, closesAt, effectiveDurationMinutes, occurrenceId, reused |
| Desktop `createSession` | Input date/classId/slot/token/secret/expiry cũ vẫn nhận; durationMinutes optional mặc định 10. Giờ client không dùng để quyết định. Giữ Session fields, thêm server time bounds/duration |
| Desktop `getSessionsByClass` | Giữ list và Session fields; reconcile expired OPEN, thêm receipt bounds/duration |
| Desktop `resetSession` | Giữ Session response, bổ sung receipt; lịch sử RESET không xóa; validation lịch/thời gian dùng chung |
| `getAttendanceSessionLive` | Giữ fields cũ, bổ sung opensAt/closesAt/effectiveDurationMinutes. serverTime của live vẫn là ISO, không nhầm với epoch của occurrence |
| `openAttendanceSession` | Chỉ resume OPEN hợp lệ, không đổi hạn |
| QR/close/Web actions | Giữ tên/envelope; dùng cùng deadline/frozen snapshot |
| `lab2Health` | Version giữ `lab2-shared-sheets-v2` vì schema không đổi; thêm capability `scheduleDrivenSessions` |

Mobile/Desk/Web cùng workbook và deployment URL. Desktop mặc định 10 phút, gửi ngày UTC+7, nhận server deadline, không tự kéo hạn khi rotate; poll cập nhật CLOSED và QR/secret nếu Mobile đã đổi. UI hướng dẫn Google email trường thay MSSV. Calendar Desktop cũ chưa render ngoại lệ theo ngày: xử lý bù/dời và mở occurrence ngoại lệ từ Mobile, hoặc cập nhật lịch chọn đúng target; backend vẫn từ chối đường vòng. Client Mobile cũ thiếu ngày/selector phải nâng cấp; không fallback tạo thủ công. Student Web không cần đổi action hoặc rebuild cho task này.

## 5. File thay đổi và dọn code — PHASE 6

Trong `C:/PRM/lecture_mobile`:

- Backend: `backend/apps_script/ScheduleAttendance.gs` mới; `Code.gs`, `Lab2Free.gs`, `AttendanceSafety.gs`, `ClassTools.gs`.
- Mobile: `lib/lab2/desktop_session_dialog.dart`, `today.dart`, `timetable_card.dart`, `class_timetable.dart`, `timetable_domain.dart`, `classes.dart`, `app.dart`, `domain.dart`, `repository.dart`, `desktop_sync.dart`, `live_attendance.dart`, `data_import.dart`.
- Kiểm thử: `backend/test/lab2-free.test.cjs`, `test/attendance_slot_flow_test.dart` mới, `test/timetable_test.dart`, `test/ocr_and_class_schedule_test.dart`, `test/lecturer_workflows_test.dart`.
- Docs/probe: báo cáo này, `README.md`, `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION_REPORT.md`, `scripts/probe-shared-backend.cjs`.

Trong `C:/PRM/FAP-Attendance-Desktop-System`:

- `lib/repositories/attendance_repository.dart`, `lib/models/session_model.dart`.
- `lib/features/attendance/attendance_screen.dart`, `session_qr_widget.dart`.
- `test/schedule_attendance_compat_test.dart` mới; `test/extension_workflow_test.dart` sửa chờ async write/flush khi xuất Excel trên Windows.
- `README.md` ghi rõ dùng bộ backend shared từ repo Mobile; không upload Code.gs độc lập cũ lên deployment chung.

Đã bỏ form nhập manual trong shared dialog, nút tạo độc lập, helper `askText`, `lab2AssertOccurrence_` và `lab2DesktopMeta_` không còn caller. Giữ dialog Firebase emulator cũ có gate vì Functions/emulator dùng contract riêng; không nằm trong shared Mobile production. Không đổi module bài viết/quiz hoặc cấu trúc repo.

## 6. Kiểm thử đã thực sự chạy — PHASE 5

Log ở thư mục `C:/PRM/lecture_mobile/artifacts` (local, ignored). Kết quả dưới đây là các lượt cuối đã kết thúc. Các PHASE 1–6 đã hoàn tất tại mã nguồn local.

| Lệnh | Kết quả |
|---|---|
| `flutter test` tại Mobile | PASS 92/92, `slot-flutter.log` |
| `flutter analyze --no-pub` tại Mobile | PASS, No issues found, `slot-analyze.log` |
| `node --test backend/test/*.cjs web_checkin/test/*.cjs` | PASS 65/65, `slot-backend.log` |
| `npm --prefix functions test` | PASS 5/5 và TypeScript build, `slot-functions.log` |
| `scripts/start-lab2-backend.ps1 -Test -SkipInstall` | PASS 7/7 trên Auth/Firestore/Functions emulator, exit 0, `slot-emulator.log` |
| `flutter build apk --debug --dart-define-from-file=config/lab2.free.json` | PASS, `build/app/outputs/flutter-apk/app-debug.apk`, `slot-apk.log` |
| Desktop `node --test backend/test/core.test.cjs` | PASS 5/5 cho backend độc lập legacy, `slot-desktop-backend.log`; quy tắc shared được test trong bộ 65 phía trên |
| Desktop `flutter test --no-pub` | PASS 46/46, `slot-desktop-flutter.log` |
| Desktop `flutter analyze --no-pub` | PASS, No issues found, `slot-desktop-analyze.log` |

Các lượt đầu gặp lỗi compile/fixture widget và chờ I/O Excel; đã sửa và chạy lại. Chỉ các kết quả cuối trong bảng là bằng chứng PASS. Emulator kiểm regression Functions cũ và security rules; không phải E2E schedule resolver Apps Script trên cloud.

| # | Ca yêu cầu | Bằng chứng automated |
|---|---|---|
| 1 | Slot hiện tại tạo thành công | Backend schedule opening + widget 3 entry points |
| 2–3 | Quá khứ/tương lai không tạo | Backend past/future/fabricated + widget ENDED/NOT_YET |
| 4–7 | Trước 15/16 phút, trong/sau giờ | Backend fixed server clock 07:44,07:45,07:50,08:15,09:30,09:35 |
| 8–9 | 30 phút còn 5; dưới 1 phút | Backend cap/09:29:01 và widget cap shown/TOO_SHORT |
| 10–11 | OPEN reuse/CLOSED không mở lại | Backend receipt/metadata không đổi + expired reconcile; widget state |
| 12 | Double tap | Widget pending Completer giữ một create request |
| 13 | Hai create tranh chấp | VM reentrant request trong commit bị lock từ chối; retry chỉ một session/meta |
| 14 | Retry mất phản hồi/mạng | Widget retry cùng selector; backend lost-response retry cùng ID |
| 15 | Check-in ở closesAt | Fixed clock + QR boundary test |
| 16 | Check-in và close | VM lock tranh chấp cả hai thứ tự, PRESENT hoặc ABSENT đúng, không duplicate |
| 17–18 | Hủy/dời/bù | Backend cancellation chặn Mobile/Desk; resolver reschedule/makeup; Flutter dated overrides |
| 19 | Không sở hữu lớp | Backend ownership và regression lecturer access |
| 20 | Desktop/Web | Shared Desktop creation/receipt/reset/list, Web Google/secret/receipt; Desktop regression/UI |
| 21 | Reconciliation lặp | Backend trigger + read fallback idempotency/ABSENT một lần |
| 22 | Ghi Sheets lỗi | Mock batch reject không có nửa session/meta; finalization failure rồi retry; audit batch tests |

Bổ sung: overnight/server campus date, xung đột lịch liền ngày, selector giả/ambiguous, duplicate session key, RESET-only, roster freeze, secret rotation, background/resume, kích thước màn hình/dark/text scale của các màn hình và APK compile.

## 7. Cập nhật Apps Script khi triển khai

Task này KHÔNG triển khai cloud. Source mới trên máy không thay deployment hiện đang chạy.

1. Dùng đúng Apps Script project nối workbook Desktop/Mobile chung. Backup version hiện hành và workbook trước khi operator triển khai.
2. Upload đầy đủ 6 file từ `C:/PRM/lecture_mobile/backend/apps_script`: **Code.gs, Lab2Free.gs, AttendanceSafety.gs, SubjectInsights.gs, ClassTools.gs, ScheduleAttendance.gs**. Không trộn với Code.gs standalone cũ trong repo Desktop, không bỏ helper mới.
3. Manifest `appsscript.json` hiện có cần V8, timezone `Asia/Ho_Chi_Minh`, Advanced Sheets v4 và scope cho trigger. Giữ các Script Properties hiện hành: workbook ID, Firebase Auth, Google audiences/domains, URL Web; không đưa private keys lên client.
4. Không có schema migration riêng của slot refactor. Schedules/Sessions/Attendance/Lab2SessionMeta/ScheduleExceptions dùng cột sẵn có. Nếu project chưa có các bảng mở rộng của đợt refactor trước, làm initializer owner và quy trình ở IMPLEMENTATION_REPORT trước; không đổi cột thủ công hoặc xóa row để bỏ lỗi. `diagnoseLab2Sheets` hỗ trợ tìm dữ liệu lỗi; không tự sửa attendance.
5. Nếu trigger chưa có, owner chạy `installAttendanceReconciliation`; nếu có, giữ trigger. Không expose initializer/trigger installer qua dispatcher.
6. Tạo version mới và cập nhật deployment Web app trên URL `/exec` hiện hành để cả ba client dùng cùng code. Nâng cấp APK Mobile và source/build Desktop liên quan cùng đợt rollout.
7. Kiểm tra `lab2Health.capabilities` có `scheduleDrivenSessions`; `scripts/probe-shared-backend.cjs` nay yêu cầu capability này. Probe chưa chạy với deployment mới vì chưa deploy. Health version v2 đơn thuần chưa đủ chứng minh có luồng slot.
8. Kiểm thử có tài khoản thật trên một lớp thử trước rollout rộng. Rollback về version Apps Script trước chỉ sau kiểm tra các phiên đang mở; giữ dữ liệu đã ghi, không xóa lịch sử/metadata.

Không cần deploy Firebase Functions cho luồng shared slot này. Firebase Auth vẫn dùng cấu hình hiện hành; Student Web vẫn trỏ backend chung. APK debug chỉ là artifact để thử, chưa phải bản ký release.

## 8. Kiểm thử thủ công trên điện thoại và giới hạn còn lại

Dùng lớp thử thuộc giảng viên, roster email trường thật và lịch/ngoại lệ được tạo bằng công cụ quản lý lịch; không sửa giờ server hay sửa Sheets production để giả lập.

1. Đăng nhập lecturer, chọn học kỳ. Nhấn buổi học tại Hôm nay, Lịch và Lớp → Lịch; cùng thông tin chỉ đọc, default 10 phút, không có ngày/slot/giờ/tên nhập tay. Đóng dialog không tạo Sessions row.
2. Với buổi hiện tại, chọn duration và double tap xác nhận: một phiên/metadata, đúng sessionId, QR và countdown server. Mở gần cuối giờ: hiển thị duration bị cap.
3. Chọn ngày trước/ngày sau, trước mốc -15 phút, tại hết giờ và còn dưới phút: không có form tạo. Kiểm ở mốc -15 phút và overnight theo lịch thử phù hợp.
4. Mở lại OPEN trên Mobile/Desktop: cùng ID/hạn. Sau deadline, mở lại nhận CLOSED và danh sách ABSENT, không phiên mới. CLOSED mở kết quả và sửa có reason/audit; RESET không tự recreate.
5. Student Web Google đúng email roster check-in; email ngoài lớp, token cũ/sai, secret sai, roster thêm sau mở và check-in lúc hết hạn bị từ chối. Lặp hợp lệ nhận receipt cũ, không duplicate.
6. Mobile đổi QR/secret, Desktop refresh nhận mã mới; Desktop đổi mã, Mobile refresh nhận mã mới; closesAt không tăng. Đóng phiên cạnh thời điểm Student gửi: kết quả PRESENT hoặc ABSENT tùy request lấy lock, không ghi sau CLOSED.
7. Ngắt mạng khi create trả phản hồi, khôi phục và retry: cùng phiên. Cho app background rồi resume: request dừng khi background, đồng bộ trạng thái server khi quay lại. Kiểm text lớn, màn hình nhỏ và bàn phím không cần xuất hiện trong dialog.
8. Hủy/dời/bù trong công cụ lịch; buổi gốc bị chặn, occurrence bù hợp lệ mở đúng ngày/slot/hạn. Lịch tuần định kỳ không bị rewrite. Thử buổi đã có phiên: quản lý ngoại lệ phải từ chối đổi lịch.

Các giới hạn được ghi rõ:

- Chưa chạy cloud Apps Script E2E bằng tài khoản thật, tải đồng thời 50 người trên Google, camera thật hoặc iOS. Lock/race/atomic batch trong VM là mô phỏng, không phải đo quota/độ trễ cloud. Cần acceptance thủ công sau deployment.
- Calendar Desktop chưa hiển thị đầy đủ ScheduleExceptions. Backend từ chối occurrence không hợp lệ; Mobile hỗ trợ ngoại lệ.
- Phiên lịch sử thiếu snapshot/meta không thể phục hồi chính xác roster/thời điểm mở từ dữ liệu không có; không giả tạo lịch sử.
- Advanced Sheets batch giữ nhóm ghi trong một request; timeout ở đường truyền vẫn có trạng thái commit không biết trước, xử lý bằng retry đối chiếu. Sheet bị chỉnh tay/trùng khóa được báo lỗi, không tự xóa để sửa.
- Functions/emulator cũ giữ form/contract riêng phục vụ regression và không phải production shared; task không chuyển nghiệp vụ điểm danh sang Firestore.
- APK build có cảnh báo Java native access/Kotlin Gradle plugin tương thích tương lai; build hiện tại thành công. Không nâng dependency ngoài phạm vi nghiệp vụ.
