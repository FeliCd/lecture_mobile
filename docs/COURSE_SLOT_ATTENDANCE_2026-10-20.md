# Thống kê nghỉ theo slot cả môn — 20/10/2026

## Quy tắc đã áp dụng

- Một buổi học theo ngày + slot là một slot, bất kể dài bao nhiêu phút hay quét QR bao nhiêu lần.
- Tỷ lệ nghỉ = (Vắng + Vắng có phép) / tổng slot cả môn × 100%.
- Được nghỉ tối đa `floor(tổng slot × 20%)`. Chỉ **vượt** giới hạn mới hiển thị cấm thi; đúng 20% vẫn trong mức cho phép.
- Ví dụ môn có 20 slot: nghỉ 3 = 15%, còn nghỉ được 1; nghỉ 4 = 20%, đã chạm giới hạn; nghỉ 5 = 25%, cấm thi theo quy tắc người dùng cung cấp.
- Tổng slot được nhập riêng cho mỗi lớp/môn/học kỳ theo kế hoạch thật. Không mặc định mọi môn là 20 slot, không dùng số slot đã điểm danh làm mẫu số.
- Kết quả phải được chốt/xác nhận. Slot đang mở, bản nháp, reset, hủy và tự đóng nhưng chưa xác nhận được bỏ qua.
- Gộp các bản ghi của cùng ngày + slot để tránh đếm trùng. Dữ liệu thiếu/mâu thuẫn giữ trạng thái chưa rõ kết quả, không tự coi là vắng hoặc có mặt.
- Chưa có tổng slot hoặc tổng nhỏ hơn số slot đã chốt: không hiển thị tỷ lệ/cấm thi suy đoán.

## Giao diện

1. Vào **Lớp học → chọn lớp → Sinh viên → mở Chuyên cần → Thiết lập**.
2. Nhập tổng slot môn học, ví dụ 20 cho lớp PRM232 nếu kế hoạch chính thức là 20 slot.
3. Danh sách sinh viên hiển thị số slot nghỉ, tỷ lệ trên cả môn, mức tối đa và số slot còn có thể nghỉ.
4. Bộ lọc **Nghỉ từ 3 slot**, **Nghỉ liên tục** (từ 2 slot đã chốt gần nhất), **Cần theo dõi**, sắp vượt và vượt 20% giúp quản lý sinh viên.
5. Điểm danh nhanh hiển thị dòng nhỏ như **Đã nghỉ 3/20 slot (15%) · Còn được nghỉ 1 slot · Nghỉ 3 slot liên tục**. Dòng này dựa trên kết quả đã lưu; thao tác bật/tắt trong bản nháp không tự cộng vào lịch sử.
6. Nghỉ có phép nối tiếp chuỗi nghỉ. Có mặt, đi trễ hoặc bản ghi thiếu/mâu thuẫn ngắt chuỗi. Slot hủy không được tính vào chuỗi.
7. Thống kê chi tiết dùng tỷ lệ của cả môn kể cả khi đang lọc các buổi trong 30/90 ngày.

## Backend và triển khai

- Apps Script thêm bảng phụ `Lab2ClassAttendanceConfig` (`classId`, `totalSlots`, `updatedBy`, `updatedAt`), không thay cột Classes/Sessions/Attendance hiện hữu.
- Snapshot lớp và context điểm danh nhanh có `totalSlots`; attendance session có cờ `attendanceCompleted` để loại kết quả tự đóng chưa được giảng viên xác nhận.
- `setClassAttendanceConfig` chỉ cho giảng viên được phân công lớp lưu số nguyên 1–1000; từ chối tổng nhỏ hơn số slot đã chốt. Đọc workbook cũ chưa có bảng cấu hình vẫn hoạt động; lần lưu cấu hình đầu tiên tạo bảng phụ.
- Nhánh Cloud Functions có endpoint tương ứng lưu `classes.totalSlots` cho chế độ Firestore.
- Gói source Apps Script: `artifacts/course-slot-attendance-backend-2026-10-20.zip`, gồm toàn bộ `.gs` hiện tại để giữ đồng bộ các helper.
- Để áp dụng trên hệ thống thật: cập nhật các file `.gs` cùng tên trong project Apps Script hiện tại, giữ manifest/Script Properties; có thể chạy `setupLab2Free()` để tạo bảng phụ. Sau đó **Deploy → Manage deployments → Edit → New version → Deploy**, giữ URL hiện tại. Health cần có capability `courseSlotAttendance`.
- Cài APK mới và tải lại dữ liệu. Mở lại/tải lại điểm danh nhanh sau khi đổi tổng slot trên thiết bị khác.
- Trong lần sửa này chưa deploy Apps Script hoặc ghi dữ liệu lớp/sinh viên trên hệ thống thật.

## Kiểm tra

- Kết quả cuối: toàn bộ **232 Flutter tests đạt**, **75 Apps Script backend tests đạt**, **5 Cloud Functions unit tests đạt**; TypeScript build và Flutter analyze đạt; APK debug với `config/lab2.free.json` build thành công.
- Unit tests bao phủ 3/4/5 slot trên 20, mẫu số cả môn ngay đầu kỳ, có phép, môn không chia hết cho 5, tổng thiếu/sai, dữ liệu trùng/mâu thuẫn, nhiều slot cùng ngày và chuỗi nghỉ.
- Widget tests bao phủ nhập tổng slot, lỗi backend, dòng nhắc trong điểm danh nhanh với chữ 200% trên màn hình 360px và khả năng tìm sinh viên trước phần thống kê chi tiết.
- Backend tests bao phủ quyền giảng viên/sinh viên/lớp khác, dữ liệu không hợp lệ, tổng nhỏ hơn số buổi đã chốt, workbook cũ chưa có bảng và snapshot/context đọc đúng cấu hình.
- Log toàn bộ Flutter tests: `artifacts/attendance-slot-full-tests.log`.
