# Lab 3 - ca nghiệm thu trên Android / ARTEMIS

Đây là kế hoạch, **chưa phải log đã chạy**. Chốt ba flow với bản Lab 2 đã nộp trước khi gắn mã flow cuối cùng. Chỉ dùng user/lớp/tệp test. Ghi build/commit, thiết bị/Android, thời điểm, điều kiện mạng và evidence cho từng lượt. Mỗi ca chạy >=3 lần; kết quả dựa vào UI và dữ liệu Console/backend quan sát được, không chỉ nhãn SUCCESS.

| ID | Điều kiện đầu | Bước thực hiện | Kết quả mong đợi và evidence |
|---|---|---|---|
| T01 | Android có Google Play services, tài khoản GV test đã cấp quyền | Google login -> home -> logout | Đúng danh tính, Console Users có UID, logout chặn route private, UID telemetry được xóa |
| T02 | Chưa đăng nhập | Hủy Google chooser; bật airplane mode rồi thử login | Thông báo rõ, không vào home, không giả thành công; ảnh UI |
| T03 | Có buổi học test hợp lệ | Từ Hôm nay mở/tiếp tục QR -> chốt xác nhận | Đúng lớp/slot, kết quả server, Analytics session_opened/closed, không tạo phiên trùng |
| T04 | Phiên test và SV được phép sửa | Tìm SV -> sửa trạng thái/lý do -> gây lỗi mạng -> thử lại/đối chiếu | Input giữ, không báo thành công sớm, audit đúng, không sửa người khác; non-fatal có operation |
| T05 | Cùng user/thiết bị, buổi test | Ghi sổ tay -> quay lại -> mở đúng buổi; mất mạng | Nội dung đúng buổi, nêu lưu local; điều chỉnh nếu flow Lab 2 nộp là flow khác |
| T06 | Storage đã bật, rules deploy, dữ liệu tổng kết test | Xuất Excel -> lưu Firebase | Tiến độ -> URL/path reports/UID -> file Console, file mở đúng nội dung, upload_completed trong DebugView |
| T07 | Hai UID test, file đã upload | UID khác/anonymous đọc bằng SDK; upload khi offline hoặc denied | Rules từ chối, UI báo lỗi, không hiển thị receipt của user cũ, Crashlytics non-fatal |
| T08 | Push đã xin quyền, token test từ app | Gửi Console khi foreground | In-app banner, đúng một mục lịch sử, nội dung/giờ đúng |
| T09 | App background, cùng user | Gửi Console -> chạm notification | Mở màn whitelist đúng; lịch sử không nhân đôi; kiểm quyền lớp |
| T10 | App đóng bình thường (không Force stop Android) | Gửi Console -> chạm -> cold launch | Mở route đúng sau auth guard, có history; ghi rõ nếu OS không cho headless delivery |
| T11 | Android 13+ chưa cấp quyền | Từ chối -> mở lại app -> xem Thông báo | UI giải thích từ chối; app còn dùng được; bật lại qua Settings và thử push |
| T12 | Demo flag, Console có quyền Remote Config | Publish enabled=false -> refresh -> trang Cập nhật; đổi true/page_size=7 -> refresh và tải feed | UI tắt/bật và request giới hạn 7, không build lại; ảnh Console/trước-sau; offline cache/default |
| T13 | Demo flag, tài khoản test, chưa lưu draft quan trọng | Gửi non-fatal -> Console -> xác nhận crash thử -> restart | Non-fatal và fatal hiện Console, UID Firebase, operation/app_mode key; crash không có trong bản thường |
| T14 | Lớp test >=5 SV có email đúng roster | GV mobile/desktop chọn nhóm -> chỉnh SV -> lưu; web SV refresh | Mỗi SV đúng một nhóm, cùng nhóm giữa client; nhóm của lớp/GV khác bị chặn |
| T15 | Hai SV cùng nhóm, một SV nhóm khác | Gửi chat + TXT/PDF <=500KB; retry timeout; tải về | Cùng nhóm đọc được, retry không nhân đôi; khác nhóm không đọc được; quá dung lượng/tệp không hỗ trợ bị chặn |
| T16 | Có lịch sử chat và tệp nhóm | GV chuyển SV -> SV gọi chat/download cũ -> refresh | Quyền nhóm cũ bị thu hồi, không đọc tệp bằng ID tùy ý, nhóm mới hiển thị đúng |

## Mẫu log từng lần chạy

```text
Case ID:
Run: 1 / 2 / 3
Date/time (Asia/Saigon):
Build/commit:
Device / Android / app state:
Preconditions verified:
Steps performed:
Observed UI + backend/Console values:
Expected vs actual:
PASS / FAIL / BLOCKED:
Evidence file / screenshot / log:
Issue and retest reference:
```

Pass rate = số PASS / tổng lượt đã thực hiện; ghi riêng blocked/not-run, không tính như PASS. Log ARTEMIS phải giữ output gốc và kết quả quan sát sau thao tác. Một lượt flutter test không thay cho 3 lượt E2E.

Exploratory 15-30 phút: đặt charter “đổi lớp/nhóm, mạng chập chờn, đổi account và resume”; ghi thời gian thực, thao tác, vấn đề, ảnh và kết luận, không viết sẵn quan sát giả.

AI PR review: giữ PR URL/head commit/tool; tối thiểu 5 finding với file/dòng, >=2 nhóm (ví dụ correctness/security); accept/adjust/reject và lý do; >=3 finding accepted có commit sửa. Tài liệu UX review hoặc danh sách lỗi do tự tạo không thay bằng chứng PR review.
