# Danh mục màn và điểm nghiệm thu

Đối chiếu source ngày 15/10/2026. Danh mục này hỗ trợ nghiên cứu và truy vết, chưa thay bộ Figma/handoff hoặc xác nhận mọi màn đã đạt accessibility.

| Screen | Source | Thông tin / hành động cần giữ | Trạng thái phải kiểm tra |
|---|---|---|---|
| S00 Đăng nhập | [app.dart](../lib/lab2/app.dart) | Google, điều kiện tài khoản lecturer | Busy, hủy đăng nhập, lỗi cấu hình OAuth, chưa cấp quyền |
| S01 Hôm nay | [today.dart](../lib/lab2/today.dart) | Học kỳ, đúng buổi/phòng, lịch sử thu gọn, đến hạn, Trợ lý | Có buổi / hết lịch / không có lịch / lỗi nguồn / không có việc |
| S02 Lịch dạy | [timetable.dart](../lib/lab2/timetable.dart) | Ngày/tuần, học kỳ/môn, room, status, xóa lọc | Không có kết quả, trùng giờ, hủy/dời, lỗi tải |
| S03 Phiên | [live_attendance.dart](../lib/lab2/live_attendance.dart) | Nhận diện lớp/slot, QR/Sinh viên, tìm/lọc, chốt | OPEN, QR expiry, CLOSED, stale, denial, lỗi ghi |
| S03E Sửa attendance | [attendance_actions.dart](../lib/lab2/attendance_actions.dart) | Đúng người, trạng thái, lý do, Lưu/Hủy | Invalid, busy, lỗi giữ input, Back/bỏ bản nháp |
| S04 Danh sách lớp | [classes.dart](../lib/lab2/classes.dart) | Mã lớp, môn/kỳ, sĩ số, tìm/lọc | Rỗng, không khớp lọc, lỗi tải |
| S05 Chi tiết lớp | [classes.dart](../lib/lab2/classes.dart), [overview](../lib/lab2/class_attendance_overview.dart) | Header lớp, bốn tab, roster, tỷ lệ và công cụ | Missing data/policy, denial, tên dài, lịch sử |
| S06 Sổ tay | [lecturer_workspace.dart](../lib/lab2/lecturer_workspace.dart) | Đúng lớp/ngày/slot, trước/sau buổi, trạng thái lưu local | Autosave, lỗi, khôi phục, không nhầm buổi, bàn phím |
| S07 Trợ lý | [lecturer_workspace.dart](../lib/lab2/lecturer_workspace.dart) | Việc, hoàn thành/hoàn tác, hạn, ghi chú, tổng kết | Rỗng, local error, từ chối quyền nhắc, dữ liệu tài khoản khác |
| S07T / S07R | [lecturer_workspace.dart](../lib/lab2/lecturer_workspace.dart), [report](../lib/lab2/lecturer_weekly_report.dart) | Form việc; xem/xuất tổng kết theo quyền | Hạn không hợp lệ, lỗi lưu, xuất file, thiếu snapshot |
| S08 Cập nhật | [subject_updates.dart](../lib/lab2/subject_updates.dart) | Môn được phân công, nguồn/ngày/link, bộ lọc | Loading, stale, error, không có kết quả |
| S09 Thư viện | [article_library.dart](../lib/lab2/article_library.dart) | Lưu bài/ghi chú cá nhân, tìm, bỏ lưu | Không có bài, lỗi ghi, bảo vệ input, xác nhận bỏ lưu |
| S10 Công cụ / nhập | [class_tools.dart](../lib/lab2/class_tools.dart), [import_page.dart](../lib/lab2/import_page.dart) | Preview/validation, lý do chỉnh dữ liệu, quyền | File lỗi, trùng, busy, draft guard, denied |
| S11 Tài khoản | [app.dart](../lib/lab2/app.dart) | Danh tính, giao diện, đăng xuất | Chữ lớn, sáng/tối, hủy dữ liệu nhắc khi logout |

## Checklist nghiệm thu đề xuất

- Trên 360 và 412dp: tên lớp/môn/người dài, chữ hệ thống 100%/200%, sáng/tối; mở bàn phím ở form dài.
- Kiểm vùng chạm ít nhất 48dp; rà chữ nội dung tối thiểu 14sp và tương phản theo chuẩn môn; chưa có số đo đủ để đánh dấu đạt toàn app.
- Trên ≥600dp/ngang: xác nhận giới hạn chiều rộng hiện có; bố cục hai cột/navigation rail vẫn là đề xuất, không mô tả như tính năng đã có.
- TalkBack: đọc đúng lớp/người/trạng thái; không chỉ dựa vào màu; thứ tự focus và nhãn icon rõ.
- Với keyword mới: người dùng tự tìm được Trợ lý, Sổ tay, ngày/kỳ, biết “đã chốt” khác QR hết hạn. Chỉ bổ sung giải thích tại nơi họ bị vướng.
- Mất mạng/timeout/denial: không hiển thị QR cũ khi không hợp lệ; không báo lưu thành công sớm; chỉ cho sửa khi UI/backend cho phép.
- Ghi chú local: người dùng hiểu nơi lưu, không được hứa khôi phục đa thiết bị. Không dùng fixture để khẳng định đồng bộ cloud.

Kết quả checklist phải gắn người thực hiện, ngày, build/ref, thiết bị, evidence và issue. Các dòng trên hiện là kế hoạch kiểm tra, chưa tick hoàn thành.

