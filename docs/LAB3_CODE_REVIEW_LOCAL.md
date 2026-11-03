# Review local sau cải tiến - 02/11/2026

Đây là review source local, không phải minh chứng AI review trên PR. Chưa có PR URL hoặc commit sửa để đáp ứng đủ điều kiện nộp của thầy.

| Phát hiện | Nhóm | Quyết định và sửa | Kiểm chứng |
|---|---|---|---|
| Giờ chat phụ thuộc timezone máy làm người nhận hiểu sai thời gian | Correctness | Accept: chatTime/chatDate dùng Asia/Ho_Chi_Minh | Web test format thời gian |
| Lỗi tải nhóm có thể giữ giao diện chờ mãi vì chưa có plan | Error handling | Accept: loadingPlan tách khỏi dữ liệu; lỗi có tải lại | Web test lỗi thoát skeleton |
| Cho chọn tệp rỗng dù backend từ chối | Validation | Accept: chặn size bằng 0 và quá 500 KB trước khi đọc | Đối chiếu validation client/server |
| Chưa có cách bỏ tệp đã chọn trong composer | UX | Accept: preview tên/kích thước, nút bỏ tệp, generation guard FileReader | Kiểm tra giao diện desktop/mobile |
| FCM auto-init có thể tạo lại token sau logout | Privacy | Accept: tắt auto-init trước deleteToken; từng lỗi SDK được xử lý riêng | Analyzer và cloud service tests; chưa thay kiểm chứng Console |
| IntersectionObserver của pane chưa đủ chứng minh tin đang trên màn hình khi pane nằm dưới fold/sticky header | Privacy / Correctness | Accept: kiểm rect với viewport thực và header, document visible/focus trước read ACK | Web test visibleMessageRect và ACK không tự read |

Nguồn: `C:/PRM/fu-grade-web/src/lib/chat.js`, `src/pages/StudyGroups.jsx`, `src/pages/StudyGroups.test.jsx` và `C:/PRM/lecture_mobile/lib/cloud/push_notifications.dart`.

Để nộp: đưa thay đổi vào PR thật, chạy công cụ review theo lớp, lưu nguyên finding/nhận xét/accept-adjust-reject, tạo commit sửa tương ứng và điền link bằng chứng. Không coi bảng này là đã hoàn thành tiêu chí PR.
