# Kiểm tra thông báo điểm danh — 20/10/2026

## Thay đổi

- Nhắc giữa buổi, trước cuối buổi 5 phút, sau cuối buổi 10 phút và 21:00 giờ Việt Nam; tối đa 4 lần/buổi. Bỏ mốc đã qua, trùng nhau hoặc sang ngày mới. Buổi quá ngắn không có nhắc trước cuối buổi sớm hơn giữa buổi.
- Dùng kênh Android `lecturer_attendance`, mức ưu tiên cao, âm thông báo mặc định và mẫu rung 500–500–800 ms (ngắt 200 ms). Kênh đã tồn tại tiếp tục dùng cài đặt của Android/người dùng; cập nhật app không ép thay đổi kênh.
- Thêm quyền VIBRATE rõ ràng trong manifest.
- Trong phần Nhắc điểm danh, bấm biểu tượng thông tin rồi **Thử âm thanh và rung** để gửi thông báo ngay bằng cùng kênh với lịch thật.
- Buổi đã hoàn tất/hủy được gỡ lịch nhắc khi ứng dụng nhận dữ liệu mới. Giờ yên lặng có sẵn vẫn được áp dụng.

## Kết quả đã xác nhận

- 49 unit/widget tests: đạt (`attendance_follow_up_test`, `quick_attendance_test`, `lecturer_workspace_test`). Bao gồm quyền bị từ chối, cô lập tài khoản, gỡ lịch, giữ nhắc việc cá nhân, nhắc sát nửa đêm, buổi ngắn, nhiều slot, chống trùng và giao diện chữ lớn trên màn hình nhỏ.
- 1 integration test trên Android `emulator-5554`: đạt. Thông báo thử xuất hiện trong danh sách thông báo đang hiển thị; kênh có importance high, sound và vibration bật; lịch hẹn được lưu và hủy thành công qua plugin Android thật.
- `flutter analyze` các file thay đổi và test liên quan: không có lỗi/cảnh báo.

## Giới hạn kiểm chứng

- Chưa đo tiếng loa hoặc cảm nhận rung trên điện thoại thật.
- Integration test xác nhận gửi ngay và lưu/hủy lịch; chưa chờ một lịch tự phát khi khóa màn hình/Doze, khởi động lại hoặc app bị đóng.
- Lịch dùng `inexactAllowWhileIdle`: Android có thể giao trễ, không cam kết đúng từng phút.
- Quyền bị tắt, kênh im lặng, âm lượng, Không làm phiền và tiết kiệm pin có thể ảnh hưởng. Không có cơ chế bảo đảm giảng viên chắc chắn chú ý.
- Lịch dựa trên dữ liệu đã tải. Nếu chốt trên thiết bị khác trong lúc điện thoại không đồng bộ, lịch cũ có thể còn nhắc. Cần mở app để cập nhật.
- Hiện hỗ trợ thông báo cục bộ trên Android; chưa triển khai iOS/web.

## Thử tiếp trên điện thoại thật

1. Cài bản mới; đăng nhập giảng viên và tải lịch.
2. Vào **Cài đặt nhắc điểm danh → biểu tượng thông tin → Thử âm thanh và rung**. Xác nhận có thông báo, tiếng và rung.
3. Nếu không có tiếng/rung: nhấn giữ thông báo, mở cài đặt kênh Nhắc điểm danh; kiểm tra âm thanh, rung, âm lượng và Không làm phiền.
4. Để một buổi chưa hoàn tất đi qua các mốc nhắc với app ở nền/màn hình khóa; ghi lại giờ nhận thực tế.
5. Chạm thông báo để mở đúng lớp/ngày/slot; hoàn tất điểm danh, chờ app đồng bộ rồi xác nhận các mốc còn lại không tiếp tục nhắc.
