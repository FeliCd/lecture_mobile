# Hỗ trợ giảng viên điểm danh — F01 + F02

Nhánh `feature/attendance-assist`, ngày 19/10/2026. Căn cứ: `LECTURER_ATTENDANCE_FEATURE_HANDOFF.md` (mốc bàn giao đầu tiên F01 + F02). F03–F05 chưa làm.

## Đã làm

### F01 — Điểm danh nhanh theo ngoại lệ

| Thành phần | File | Ghi chú |
|---|---|---|
| Bản nháp thuần (không gọi mạng) | `lib/lab2/quick_attendance_draft.dart` | Mặc định Có mặt, đổi từng người, Hoàn tác, lọc Tất cả / Ngoại lệ, tìm tên/MSSV, payload "mặc định + ngoại lệ", lưu/khôi phục |
| Màn hình | `lib/lab2/quick_attendance.dart`, route `/quick?classId&sessionDate&slot&scheduleId&exceptionId` | Xem lại → Xác nhận và lưu; khóa gửi lặp; lỗi giữ bản nháp; xung đột → Tải lại và đối soát; buổi đã hoàn tất chỉ xem, sửa từng người kèm lý do |
| Điểm vào | `desktop_session_dialog.dart` | Nút **Điểm danh nhanh** khi buổi AVAILABLE hoặc OPEN; dùng chung cho Hôm nay, Lịch dạy, Lớp → Lịch |
| Backend đọc | `getQuickAttendanceContext` (`AttendanceSafety.gs`) | Trả buổi, roster hợp lệ, kết quả hiện có, `revision`, `editable`. **Không tạo phiên, không ghi gì** |
| Backend ghi | `submitQuickAttendance` (`AttendanceSafety.gs`, dispatcher `Lab2Free.gs`) | Trong script lock: kiểm quyền, `expectedRevision`, roster phải khớp đúng danh sách client đã xem; tạo phiên nếu chưa có; ghi kết quả + chốt CLOSED trong một batch |

Quy tắc đã thực thi:

- Mở màn hình hoặc tạo bản nháp không ghi kết quả chính thức. Buổi chỉ "hoàn tất" khi backend chốt.
- Kết quả có sẵn (QR, nhập tay) là mốc ban đầu của bản nháp, không bị ghi đè âm thầm. Chỉ gửi những sinh viên khác mốc đó. Thay đổi bản ghi đã có thì ghi `AttendanceAudit` với lý do "Điểm danh nhanh".
- Backend không tin sĩ số client: roster phải trùng khớp roster server, nếu không trả `ROSTER_CHANGED`. Ai đó sửa trong lúc giảng viên đang chỉnh thì trả `ATTENDANCE_CONFLICT`.
- Gửi lại sau khi mất phản hồi: nếu buổi đã chốt và kết quả trùng thì trả `alreadySaved`, không ghi thêm. Kết quả khác thì trả `ATTENDANCE_ALREADY_FINALIZED` (phải sửa từng người kèm lý do).
- Mất mạng hoặc lỗi lưu: giữ bản nháp; lần thử lại gửi đúng nội dung cũ để backend đối chiếu (trùng → đã lưu, khác → báo đã hoàn tất và giữ bản nháp). Không tự coi buổi do người khác chốt là bản lưu của mình.
- Rời màn khi chưa lưu: chọn **Tiếp tục chỉnh / Giữ bản nháp / Bỏ bản nháp**. Bản nháp lưu theo giảng viên + lớp + ngày + slot (+ schedule/exception), nên hai ca cùng lớp trong ngày không lẫn nhau. Bản nháp chỉ khôi phục khi roster và revision không đổi.
- Trạng thái có chữ + icon + màu. Chạm một dòng để đổi Có mặt ↔ Vắng; nút ⋮ để chọn Đi trễ hoặc Vắng có phép. Tổng số luôn hiện ở thanh dưới.

### F02 — Nhắc tránh quên điểm danh

| Thành phần | File | Ghi chú |
|---|---|---|
| Lập lịch nhắc (thuần) | `lib/lab2/attendance_reminders.dart` | Nhắc trước giờ bắt đầu ("Sắp đến giờ dạy") và trước giờ kết thúc ("Điểm danh chưa hoàn tất"); bỏ qua buổi hoàn tất hoặc bị hủy |
| Thông báo trên máy | `lecturer_reminders.dart` | `syncAttendance` tách vùng thông báo; nhắc việc và nhắc điểm danh không xóa lẫn nhau (bỏ `cancelAll` khi đồng bộ nhắc việc). Chạm thông báo mở đúng `/quick` của buổi |
| Trong app | `today.dart` → `PendingAttendanceSection` | Buổi **đã hết giờ** nhưng chưa hoàn tất. Vẫn hiện khi tắt quyền thông báo, kèm nút bật lại |

Lịch nhắc được tính lại mỗi khi Hôm nay cập nhật dữ liệu (cho hôm nay và ngày mai). Buổi vừa hoàn tất, bị hủy hoặc đổi lịch sẽ tự rút khỏi kế hoạch nhắc.

## Thật / giả lập / phụ thuộc

| Hạng mục | Trạng thái |
|---|---|
| UI, bản nháp, quy tắc client | Thật, có test |
| Backend `getQuickAttendanceContext`, `submitQuickAttendance` | Có code + test trên giả lập Sheets (node). **Chưa deploy** lên Apps Script thật |
| Thông báo Android | Thật (flutter_local_notifications). Chỉ nhắc khi app đã được mở để lập lịch; không có nhắc từ server (FCM) |
| Kiểm tra lại trạng thái ngay lúc thông báo bật | Không có (giới hạn của thông báo cục bộ); chạm vào sẽ mở kết quả hiện tại nếu buổi đã xong |

## Giả định chờ nhóm chốt (handoff §11)

| Câu hỏi | Đang dùng |
|---|---|
| Được điểm danh nhanh trong khoảng nào | Theo cửa sổ phiên hiện có: 15 phút trước giờ học đến hết giờ học. Sau giờ học, màn hình báo "xử lý theo quy định điểm danh muộn", không tự mở quyền ghi lùi giờ |
| Mốc nhắc | 10 phút trước bắt đầu, 10 phút trước kết thúc (`attendanceReminderBeforeStart/End`) |
| Đi trễ / Có phép tính thế nào | Giữ nguyên chính sách hiện có, không thay đổi |

## Triển khai backend

Cập nhật `AttendanceSafety.gs` và `Lab2Free.gs` lên project Apps Script hiện hành, deploy lại trên **cùng URL**. Không đổi schema Sheet. Trước khi deploy, app hiện "Cần cập nhật Apps Script…" (`ATTENDANCE_BACKEND_UPDATE_REQUIRED`) khi mở Điểm danh nhanh.

## Kiểm thử đã chạy (19/10/2026)

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub`: 180/180 qua, gồm `quick_attendance_draft_test.dart` (7) và `quick_attendance_test.dart` (16): lớp 40 người vắng 2, lớp đi đủ, hoàn tác + lọc, lỗi lưu, thử lại, xung đột, khóa gửi lặp, buổi đã hoàn tất, kết quả QR có sẵn, rời màn, 360 dp chữ 200%, lập lịch nhắc.
- `node --test backend/test/*.cjs`: 66/68 qua; 5 test mới đều qua. Hai test lỗi (`Desktop create captures roster…`, `RSS and Atom parse…`) **đã lỗi sẵn trên code gốc** (thiếu `jsdom` trong `web_checkin/node_modules` và test phụ thuộc ngày), không liên quan thay đổi này.
- Chưa chạy được trên thiết bị với backend thật: đăng nhập Google trên máy này đang lỗi SHA-1 (28444), và backend chưa deploy action mới.
