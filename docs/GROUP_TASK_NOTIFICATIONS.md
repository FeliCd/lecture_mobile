# Giao việc nhóm và thông báo — 04/11/2026

## Source đã thực hiện

- Mobile: Lớp → Nhóm học tập → chọn nhóm đã lưu → Giao việc cho nhóm. Nhập tên, yêu cầu, hạn theo giờ Việt Nam; xác nhận trước khi gửi. Hiện số người nhận, đã đọc, email chờ gửi/đã được dịch vụ email chấp nhận/cần kiểm tra.
- Student Web: repo `https://github.com/LuanOn123/FapAttendanceWeb`, local `C:/Users/ADMIN/Desktop/FapAttendanceWeb`. Mục **Thông báo giao việc** tổng hợp tất cả lớp; có badge chưa đọc, lọc chưa đọc, phân trang, xem nội dung. Link `/#tasks` mở thẳng mục này sau đăng nhập. Poll 30 giây khi trang hiển thị; không phải push khi đóng trình duyệt.
- Backend chung: `GroupTasks.gs`, schemas trong `Lab2Free.gs`, router trong `StudyGroups.gs` và `StudentPortal.gs`. Không thay nguồn dữ liệu điểm danh.

## Quyền và giao dịch

Chỉ giảng viên sở hữu lớp được tạo việc. Backend lấy người nhận từ group plan và email từ `Students.schoolEmail`; không nhận danh sách email từ client. Kiểm version group plan và enrollment trước khi ghi. Chụp người nhận tại lúc giao: thành viên mới không tự nhận việc cũ; người bị chuyển nhóm/mất enrollment không đọc được thông báo cũ, email còn chờ bị bỏ qua.

Task, thông báo từng người, hàng đợi email và audit được ghi trong cùng Sheets batch. Request key + fingerprint chống tạo trùng khi mất response; mobile giữ cùng key khi thử lại trong màn đang mở. Chưa có outbox mobile bền vững qua đóng/khởi động lại app: sau trường hợp đó phải kiểm danh sách việc đã giao trước khi tạo lại.

API mobile gọi qua `groupCall`; web gọi qua `portalCall` với Firebase ID token hiện hành:

| Method | Quyền / dữ liệu |
| --- | --- |
| createGroupTask | Giảng viên; classId, groupId, version, title, description, dueAt ISO UTC, requestKey |
| listGroupTasks | Giảng viên; classId, groupId tùy chọn; trả thống kê, không trả email từng người |
| listMyTaskNotifications | Sinh viên; before tùy chọn; 50 tin/trang, unreadCount tổng, older cursor |
| readTaskNotification | Sinh viên; notificationId; kiểm lại quyền và trả thời điểm đọc server |

Đọc danh sách không tự đánh dấu đã đọc. Chỉ khi sinh viên mở việc và server nhận acknowledgement mới tính đã đọc. Email đã gửi không có nghĩa email đã tới inbox hoặc sinh viên đã đọc thư.

## Triển khai để dùng thật

1. Cập nhật toàn bộ gói Apps Script tương thích, bao gồm file mới `GroupTasks.gs`, manifest có scope `https://www.googleapis.com/auth/script.send_mail` và router/schema đã sửa. Giữ nguyên Spreadsheet ID, project Firebase và deployment URL đang dùng.
2. Owner chạy `setupGroupTasks()` để thêm `PortalGroupTasks` và `PortalTaskNotifications`. Hàm này không gửi email.
3. Script Properties: đặt `STUDENT_WEB_TASKS_URL=https://fap-sinhvien.web.app/#tasks` nếu đó là URL target student hiện hành (kiểm `.firebaserc` của web trước khi đặt). Link không chứa ID token hay thông tin sinh viên.
4. Owner chạy `installGroupTaskEmailTrigger()` và cấp quyền gửi email. Tạo tối đa một trigger của owner hiện tại, chạy mỗi 5 phút. Không để nhiều owner cùng cài trigger.
5. Cập nhật deployment Apps Script bằng new version, giữ `/exec` cũ.
6. Web dùng `.env.local` với `VITE_PORTAL_API_URL` cùng backend mobile. Chạy `npm test`, `npm run build`; khi triển khai dùng target `hosting:student` của repo web, không thay Hosting QR hoặc Firestore rules.
7. Tạo việc trên lớp test; kiểm một sinh viên thuộc nhóm nhận thông báo, người ngoài nhóm không thấy; mở việc cập nhật badge/đã đọc. Chạy worker/đợi trigger để kiểm email thật và thống kê mobile.

## Hàng đợi email

Worker `sendGroupTaskEmails()` chỉ xử lý PENDING, tối đa 30 thư/lượt và dừng sau giới hạn thời gian. Kiểm quota MailApp trước khi gửi, còn thiếu quota thì giữ PENDING. Dùng ScriptLock chung để tránh chạy trùng và kiểm lại enrollment/nhóm/email trước khi gửi. Gửi từng người riêng, không lộ danh sách địa chỉ.

Trạng thái: PENDING → SENDING → SENT. Lỗi gửi không rõ kết quả → UNKNOWN; mất tiến trình sau claim có thể còn SENDING. Các trạng thái này cần owner xem Executions và mail đã gửi, không tự động đưa về PENDING vì có thể gửi trùng. Chuyển nhóm/email thay đổi/mất enrollment → SKIPPED. Không khẳng định exactly-once delivery vì Sheets và MailApp không có giao dịch chung.

Hạn mức email và quyền do Google áp dụng: [MailApp](https://developers.google.com/apps-script/reference/mail/mail-app), [Apps Script quotas](https://developers.google.com/apps-script/guides/services/quotas). Chu kỳ trigger không phải cam kết gửi đúng từng giây; quota có thể làm thư chờ lâu hơn.

## Giới hạn phạm vi

Giai đoạn này giao việc và báo cho sinh viên, chưa có nộp bài/chấm điểm, theo dõi tiến độ hay tự nhắc deadline. Chưa dùng FCM cho phía sinh viên. Dữ liệu cũ không tự tạo thông báo hoặc gửi thư hồi tố.

## File trong chat nhóm

Mobile và Student Web: mở Nhóm học tập → Gửi file → chọn tệp → kiểm tên/dung lượng → Gửi kèm file. Có thể gửi chỉ file hoặc thêm lời nhắn; có nút bỏ/đổi file trước khi gửi. Mỗi tin một tệp PDF/TXT/PNG/JPG/JPEG/DOCX/XLSX/CSV, tối đa 512000 byte (500 KB); không nhận tệp rỗng, tên quá 120 ký tự hoặc tên có đường dẫn.

Mobile đọc stream có giới hạn trước khi mã hóa, khóa thao tác khi đang chọn/gửi và xác nhận bỏ nháp khi chuyển nhóm/chia lại. Web hủy FileReader cũ khi đổi lớp/unmount/tải lại nhóm. Khi kết quả gửi không rõ, giữ cùng payload và request key để thử lại. Đây là file đính kèm tin chat; API giao việc chưa nhận file riêng.

Backend file dùng API hiện có `sendGroupMessage`/`downloadGroupFile`; lưu trong Drive riêng tư, tải qua server sau kiểm quyền nhóm. Owner phải chạy `setupStudyGroups()` để cấu hình `GROUP_FILES_FOLDER_ID`, cấp scope Drive và triển khai source tương thích trước khi dùng thật. Không tạo link Drive công khai. Phần UI mới hiện chỉ ở local hai repo.

Các thay đổi đang ở local của hai repo; chưa commit/push/deploy hoặc gửi email tới sinh viên thật. Kết quả kiểm thử local không thay thế xác nhận trên cloud.

## Kiểm tra local

- Backend: 129 ca pass, gồm quyền, transaction, gửi trùng, lỗi gửi/ghi receipt, phân trang, đổi nhóm và kiểm tra file.
- Student Web: 23 UI/hook tests + 4 migration tests pass; production Vite build thành công.
- Mobile: analyzer phần nhóm/giao việc/file sạch; 9 ca nhóm/giao việc/file và toàn bộ 264 Flutter tests pass.
- Build Android cấu hình Firebase thật hiện bị chặn bởi thiếu file ignored `android/app/google-services.json`. Không thay bằng cấu hình tự chế. Lấy file Android app `vn.edu.fpt.lecturer_companion` từ Firebase project `fap-attendance-88920` trước khi build lại. Chưa cài APK mới hoặc test giao việc/email thật.
