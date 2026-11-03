# Flutter handoff - source hiện hành, 02/11/2026

Phạm vi: Mobile giảng viên. Tài liệu được đối chiếu mã nguồn, **chưa xác minh link/node Figma của bản Lab 2 đã nộp**. Các ID dưới đây giữ theo `ux/user-flow.md`; không coi tên token đề xuất là ID biến Figma thật. Web sinh viên là client bổ sung dùng API chung.

## S00 - Đăng nhập Google
- **Layout:** SafeArea, nội dung cuộn, panel căn giữa và giới hạn chiều rộng.
- **Components:** brand, mô tả tài khoản, nút Google, thông báo lỗi, loading/busy.
- **States:** khởi tạo Firebase, signed out, đang đăng nhập, bị từ chối, lỗi/hủy, signed in.
- **Interactions:** Google chooser; busy chặn submit lặp; không suy ra quyền từ email phía UI.
- **Navigation:** GoRouter guard -> loading/login/home dựa profile lecturer; logout trả login.
- **UI constraints:** chữ Việt dài, 360/412 dp, text scale; source `lib/lab2/app.dart`, `repository.dart`.

## S01/S02 - Hôm nay và lịch dạy (F01)
- **Layout:** shell bốn tab; danh sách buổi theo ngày/học kỳ, lịch ngày/tuần.
- **Components:** academic term selector, teaching period card, điều hướng ngày, trạng thái buổi, nhắc.
- **States:** tải, có buổi, không có buổi, dữ liệu cũ, lỗi/mất quyền, buổi hủy/dời/đã chốt.
- **Interactions:** chọn buổi rồi mở/tiếp tục phiên hoặc điểm danh nhanh; không tự tạo attendance khi xem.
- **Navigation:** từ Home/Lịch -> dialog buổi -> phiên, quick attendance, sổ tay; Back giữ phạm vi ngày.
- **UI constraints:** lớp/môn/phòng/slot luôn nhận biết được; source `today.dart`, `timetable.dart`, `timetable_card.dart`.

## S03 - Phiên điểm danh (F01/F02)
- **Layout:** thông tin buổi, chuyển QR/Sinh viên, counters, danh sách và thao tác chốt.
- **Components:** QR có thời hạn, search/filter, status có chữ/icon, dialog xác nhận chốt, stale/error.
- **States:** đang mở, QR hết hạn, dữ liệu cũ, phiên đóng, tải lại, lỗi, mất quyền.
- **Interactions:** tìm sinh viên, rotate QR hợp lệ, sửa trạng thái có lý do, chốt có xác nhận; backend quyết định expiry.
- **Navigation:** từ đúng occurrence; Back không chốt phiên; mất quyền dừng đọc roster.
- **UI constraints:** không lộ QR/token khi stale hoặc hết hạn; source `live_attendance.dart`, `attendance_actions.dart`.

## S03E - Điều chỉnh sinh viên (F02)
- **Layout:** dialog/form với tên/MSSV xác định đúng người, trạng thái và lý do.
- **Components:** lựa chọn PRESENT/LATE/ABSENT/EXCUSED riêng, reason field, hủy/lưu, lỗi.
- **States:** pristine/dirty, input không hợp lệ, saving, thành công, timeout/chưa rõ kết quả, mất quyền.
- **Interactions:** chặn save lặp, giữ lý do khi lỗi; chưa rõ kết quả phải đối chiếu trước khi gửi lại.
- **Navigation:** thành công mới đóng form; hủy/Back xử lý draft guard; trả đúng danh sách/bộ lọc.
- **UI constraints:** thông báo lỗi dễ hiểu, bàn phím không che hành động; source `attendance_actions.dart`.

## S06/S07 - Sổ tay và việc cá nhân (F03)
- **Layout:** nội dung gắn class/date/slot, phần chuẩn bị và tiếp nối; trợ lý liệt kê việc.
- **Components:** text fields, autosave indicator, nhắc Android, tổng kết tuần, export/report upload.
- **States:** chưa có, đã lưu local, dirty, lưu lỗi, quyền nhắc bị từ chối, upload/progress/error/receipt.
- **Interactions:** tự lưu trên cùng thiết bị, khôi phục draft theo user/buổi; upload Excel do user chủ động.
- **Navigation:** từ thẻ buổi hoặc Workspace; mở lại phải đúng identity của buổi.
- **UI constraints:** không hứa cloud sync cho sổ tay local; source `lecturer_workspace.dart`, `lecturer_weekly_report.dart`.

## S08/S09 - Cập nhật và thư viện
- **Layout:** môn được phân công, news/research/saved, bộ lọc, danh sách bài có nguồn/ngày.
- **Components:** filter chips, source/date/search, article, saved note, remote-disabled state.
- **States:** loading, empty, partial/stale, lỗi nguồn, đã lưu, Remote Config tạm tắt.
- **Interactions:** tải feed theo page size remote, xem nguồn, lưu/ghi chú/bỏ lưu bằng service.
- **Navigation:** tab Cập nhật -> bài/thư viện -> nguồn HTTPS; không mở URL tùy ý từ push.
- **UI constraints:** nguồn và thời điểm giữ nguyên provenance; source `subject_updates.dart`, `article_library.dart`.

## S11 - Tài khoản / cloud / notifications
- **Layout:** thông tin user, giao diện, học kỳ, công cụ, Thông báo và Dịch vụ đám mây.
- **Components:** theme selector, permission action, lịch sử push, remote settings, vùng demo có cờ.
- **States:** permission denied/granted, không có history, loading/error/settings/default, logout.
- **Interactions:** xin quyền chủ động, chạm push đi route whitelist; crash thử chỉ khi bật cờ + xác nhận.
- **Navigation:** route guard bao toàn bộ cloud/notification; Firebase UID tách biệt ID giảng viên Sheets.
- **UI constraints:** không log token, không cho tài khoản khác xem history/receipt; source `lib/cloud/*`.

## Hai bảng mapping

| Token thiết kế đề xuất (Figma chưa xác minh) | Flutter thực tế |
|---|---|
| color/brand | CampusColors.brand #F37021 |
| color/action | light #B54708, dark #FFB181 |
| spacing/xs-sm-md-lg-xl | CampusSpace: 4/8/12/16/24 |
| gutter/page | CampusSpace.page: 20 |
| radius/control-card-sheet | CampusRadius: 8/12/16 |
| typography/body | Be Vietnam Pro + ThemeData/TextTheme |

| Component thiết kế đề xuất | Widget/source |
|---|---|
| Primary action | AppPrimaryButton |
| Search | CampusSearchField |
| Card | CampusCard / TeachingPeriodCard |
| Confirmation | campusConfirm |
| Loading / Empty / Error | CampusLoadingState / EmptyState / ErrorState |
| Cloud upload | reportUploadProvider -> ReportUploadController -> ReportStorageService |
| Remote settings | cloudSettingsProvider -> CloudSettingsController -> RemoteSettingsService |

Cần bổ sung node/link Figma thật vào bảng trước khi nộp. Các widget tests đang pass không thay thế phép đo tương phản, TalkBack, usability hoặc E2E mọi màn hình.
