# Cập nhật ba nền tảng — 06/11/2026

Mobile + Desktop dành cho giảng viên; Student Web dành cho sinh viên. Các nghiệp vụ vẫn dùng Apps Script/Sheets chung.

## Mobile

- Đăng xuất cố gắng hoàn thành từng cleanup: reminders, cache, Firebase, Google, push, logout event và telemetry identity. Một bước lỗi không chặn bước sau; lỗi tổng hợp vẫn báo chưa hoàn tất để thử lại. Push cleanup cũng tách history, auto-init, token và listener.
- Mở lớp → **Bảng điểm** (biểu tượng bảng điểm trên thanh tiêu đề). Quản lý cột/thang điểm, điểm từng sinh viên, nhận xét, lưu nháp, xem trước/công bố và thu hồi. Số 0 không bị coi là thiếu; nhập được `8,5`.
- Gọi `lab2Call` → `name: portalCall` → `{method, data}` bằng Firebase ID token hiện tại. Backend kiểm Google provider, hồ sơ lecturer, quyền lớp và khóa ghi trước khi gọi `portalCall_`. Chỉ cho phép getGradebook/saveGradebook/publishGrades/revokeGrades.
- Lưu nháp không sửa publication. Bản công bố bất biến tiếp tục phục vụ Student Web; công bố mới mới đổi snapshot. Conflict giữ bản sửa, yêu cầu tải lại; mất phản hồi công bố giữ nguyên requestKey/payload để retry và khóa sửa điểm.
- Quay lại khi còn bản sửa sẽ hỏi xác nhận. Khi đang gửi thì chặn đóng màn. Màn bảng điểm hiện chỉ bật trong chế độ backend chung; chưa thêm nhập Excel trên mobile.

## Desktop

Nhóm học tập → mở một nhóm đã lưu → **Giao việc cho nhóm**. Tạo việc/hạn giờ Việt Nam, xác nhận đúng nhóm/số thành viên, xem trạng thái đọc trên web và hàng đợi email trường. Không tự gửi email từ desktop; backend làm việc này. Retry lỗi mạng dùng lại mã gửi; nhóm chưa lưu/chưa xử lý bản nháp thì khóa lối mở giao việc.

## Student Web

Kiểm tra plan nhóm mỗi 15 giây và khi quay lại tab. Khi không có bản nháp, tự nhận nhóm mới và tải lại hội thoại, kể cả trước đó chưa được xếp nhóm. Nhóm thay đổi lúc đang soạn tin/đọc file/gửi chưa rõ kết quả: giữ bản nháp, dừng chat nhóm cũ, yêu cầu kiểm tra trước khi đổi. Chỉ bỏ bản nháp khi sinh viên xác nhận. Response của lớp cũ bị bỏ; khi quyền bị thu hồi, ẩn tin nhắn/danh sách thành viên cũ.

## Tính FE/PE trên cả ba bản

Có **điểm tối thiểu FE/PE theo đề cương** do người dùng nhập. Mặc định 0 nghĩa là không áp dụng ngưỡng riêng, không gán một ngưỡng chung cho mọi môn. Công cụ tìm điểm theo bước 0,1 thỏa tổng >5 và ngưỡng bài thi. Nếu điểm bài thi đã biết dưới ngưỡng thì báo rõ; xóa điểm bài đó để dự đoán lại. Cặp điểm PE dưới ngưỡng được đánh dấu không hợp lệ.

Điểm/trọng số vẫn nhập tay, chưa có dữ liệu syllabus chính thức để tự điền. Chuyên cần và quy tắc khác kiểm riêng; không khẳng định “chắc chắn qua môn”. Công cụ không sửa bảng điểm thật.

## Triển khai

1. Cập nhật **đầy đủ backend canonical** từ repo Mobile `backend/apps_script`, giữ Spreadsheet và deployment URL của nhóm. Không deploy riêng gói backend Desktop lên backend chung.
2. Backend đã có bảng điểm thì dùng nguyên schema. Nếu chưa thiết lập, owner chạy `setupStudentPortal()`; giao việc dùng `setupGroupTasks()` và worker email đã cấu hình. Tạo deployment version mới để bật mobile grade route.
3. Build lại Mobile/Desktop và deploy Student Web theo cấu hình chính thức hiện có.
4. Dùng lớp/tài khoản test kiểm tra desktop/mobile cùng grade version, save draft → web giữ publication cũ → publish → web tải bản mới; tạo việc desktop → đúng thành viên nhận/read; đổi nhóm Sheets → web tự nhận khi không có nháp.

Chỉ kiểm tra local bằng unit/widget/backend test trong đợt sửa này. Chưa deploy cloud, công bố điểm thật, tạo việc thật hoặc gửi email tới sinh viên. Android build/native và Console cần cấu hình chính thức, không suy ra từ test giả lập.
