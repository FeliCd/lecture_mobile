# Công nghệ gửi tin nhắn nhóm

Mobile và Desktop giảng viên cùng Student Web gửi và đọc qua Apps Script. Google Sheets lưu lịch sử, mã chống gửi trùng và trạng thái đã nhận, đã xem. Google Drive lưu tệp đính kèm riêng tư. Desktop Windows dùng giao diện hai cột và tải tin từ API chung.

Khi tin mới đã lưu, Apps Script dùng Firebase Cloud Messaging HTTP v1 để báo cho thành viên hiện tại trong nhóm và giảng viên phụ trách, bỏ qua người gửi. Thông báo chỉ có lời nhắc chung và định danh hội thoại. Khi mở, API kiểm lại quyền trước khi trả nội dung. Gửi lại cùng mã yêu cầu trả về tin đã lưu và bỏ qua lần báo mới. Nếu FCM gặp lỗi, tin đã lưu vẫn đọc được và các client vẫn định kỳ tải lại. Trạng thái nhận và xem lấy từ biên nhận của client.

## Bật trên môi trường triển khai

1. Dùng cùng dự án Firebase cho Android, Student Web và thuộc tính `GROUP_FCM_PROJECT_ID`. Bật Firebase Cloud Messaging API trong dự án Google Cloud phát hành yêu cầu. Tài khoản thực thi Apps Script cần quyền `cloudmessaging.messages.create` trong dự án Firebase đích.
2. Cập nhật Apps Script từ `backend/apps_script`, gồm `GroupPush.gs` và scope `firebase.messaging` trong manifest. Chạy `setupStudentPortal()` để thêm bảng `PortalGroupPushDevices`, cấp lại quyền cho tài khoản thực thi rồi tạo phiên bản deployment mới.
3. Đặt Script Property `GROUP_FCM_PROJECT_ID`. Đặt thêm `GROUP_FCM_WEB_URL` bằng origin HTTPS của Student Web để bấm thông báo mở lớp tương ứng.
4. Trong Student Web, bật FCM Registration API cho dự án Firebase nếu cần, cấu hình `VITE_GROUP_PUSH_VAPID_KEY` bằng khóa Web Push công khai rồi build lại. Sinh viên mở chat và chọn **Bật thông báo chat**. Giảng viên Android cấp quyền trong màn **Thông báo**.
5. Dùng lớp thử để gửi một tin từ Desktop sang Student Web và một tin từ Student Web sang Android. Kiểm tra cả thông báo nền, thao tác mở, tải đúng hội thoại, gửi lại cùng mã và tài khoản ngoài nhóm.

Mỗi tài khoản có một đăng ký gần nhất cho nền tảng phù hợp. Đăng ký hết hiệu lực sau 30 ngày kể từ lần cập nhật. Các token nằm trong bảng backend riêng, nên chỉ người quản trị được truy cập bảng tính. Các kiểm tra tự động mô phỏng FCM. Việc nhận push thật cần được xác nhận sau khi triển khai.

[Firebase Cloud Messaging HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api) · [Web Push và Firebase](https://firebase.google.com/docs/cloud-messaging/web/get-started) · [OAuth của Apps Script](https://developers.google.com/apps-script/reference/script/script-app#getOAuthToken())
