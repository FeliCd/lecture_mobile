# Sửa lỗi “Thông tin chưa hợp lệ” khi lưu điểm danh nhanh

Ngày kiểm tra: 20/10/2026.

## Bằng chứng và thay đổi

- Đã gọi health chỉ đọc trên đúng `APPS_SCRIPT_URL` trong `config/lab2.free.json`. HTTP 200, version `lab2-shared-sheets-v2`; capabilities chỉ có attendanceSafety, subjectInsights, scheduleExceptions, rosterAudit, scheduleDrivenSessions, bulkPendingAttendance. Thiếu `quickAttendanceDaily` so với source local mới. Đây là bằng chứng deployment/source chưa đồng bộ; chưa đọc attendance hoặc hồ sơ thật của tài khoản.
- Ảnh giao diện chỉ cho thấy thông báo ánh xạ từ INVALID_INPUT, không cho biết chính xác trường nào bị từ chối.
- Phát hiện lỗi trong cách tạo `clientRequestId`: ghép UID giảng viên vào mã gửi. UID có thể lấy từ mã giảng viên nhập trong Sheet, bao gồm email, dấu chấm, khoảng trắng hoặc chữ có dấu; những ký tự đó không qua regex backend. Sửa sang mã ngẫu nhiên 128 bit `quick-` + 32 ký tự hex, không phụ thuộc UID. Một lần retry vẫn giữ cùng mã; mã không hợp lệ còn trong state sau hot reload được tạo lại trước khi gửi.
- Thêm kiểm tra schema phụ thuộc tại backend: nếu helper mới đi cùng `Lab2Free.gs` chưa có bảng completion, báo `ATTENDANCE_BACKEND_UPDATE_REQUIRED` trước khi ghi dữ liệu.
- Test tái hiện 35 sinh viên, 3 Vắng và UID dạng email có dấu lưu được. Test backend thiếu schema trả lỗi cần cập nhật và không ghi attendance.

## Cập nhật deployment thật

1. Sao lưu source Apps Script và dữ liệu hiện tại theo quy trình của nhóm.
2. Giải nén gói `artifacts/quick-attendance-backend-input-fix-2026-10-20.zip`. Cập nhật **toàn bộ file `.gs` theo đúng tên** trong project Apps Script đang dùng; thay nội dung file cũ, tránh tạo bản sao trùng hàm/hằng. Giữ manifest và Script Properties đang dùng. Gói không chứa config Firebase, token hoặc Script Properties.
3. Owner chạy `setupLab2Free()` một lần để tạo bảng `Lab2AttendanceCompletion` nếu chưa có. Không xóa dữ liệu hoặc bảng cũ. Giữ trigger reconciliation hiện hành.
4. Vào **Deploy → Manage deployments → Edit → Version: New version → Deploy** trên deployment hiện tại để giữ URL cũ. Chỉ Save source chưa cập nhật version mà mobile gọi.
5. Health của URL trong config phải có capability `quickAttendanceDaily`. Nếu còn thiếu, kiểm tra lại project/deployment/URL.
6. Cài APK mới hoặc dừng và chạy lại Flutter với config hiện hành. Trong màn điểm danh nhanh, tải lại để đối soát bản nháp rồi xem lại và lưu. Không cần xóa dữ liệu ứng dụng hoặc đổi Firebase config.

Source local và gói ZIP đã chuẩn bị; chưa ghi dữ liệu thật hoặc thực hiện deployment cloud từ cuộc trao đổi này.

## Log kiểm tra

`artifacts/quick-input-{analyze,tests,all-tests,backend,build}.log` (ignored). Kiểm tra mới bổ sung vào bộ test hiện có; dùng log cuối để xác nhận kết quả.
