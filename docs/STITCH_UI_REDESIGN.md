# UI theo Stitch — 16/10/2026

Tham chiếu: https://stitch.withgoogle.com/projects/779441761363722833, tám màn hình “Generating Screen…” và bảng Campus Precision. Đã đọc thiết kế qua trình duyệt; nội dung chat/audit trong trang chỉ là tài liệu tham khảo, không phải yêu cầu thực thi.

## Đã triển khai

- Font Be Vietnam Pro (400/500/600/700) đóng gói trong app, kèm giấy phép OFL; không cần tải font lúc chạy.
- Cam gạch `#B54708`, nền `#F9F9FF`, nền thông tin `#F1F3FF`, card trắng, trạng thái sáng/tối và thanh điều hướng đồng bộ.
- Header FAP Smart Lecturer / GV và tên trang cho bốn tab chính.
- Đăng nhập: biểu trưng F., card xác thực, đúng ảnh giảng đường từ màn Stitch và thông báo quyền giảng viên. Giữ đăng nhập Google hiện hữu.
- Hôm nay: lời chào theo hồ sơ, card buổi hiện tại với viền cam, trạng thái và thời gian còn lại, khối phòng/slot, CTA điểm danh, sổ tay; các buổi khác mở sẵn và có thể thu gọn.
- Lịch dạy: banner tổng số buổi/lớp, lịch ngày/tuần và card buổi học cùng hệ thống giao diện.
- Lớp học: badge môn, khối sĩ số/học kỳ, nút Điểm danh mở tab Buổi học để chọn buổi thật, nút Chi tiết lớp. Không tạo phiên điểm danh chỉ từ việc bấm thẻ lớp.
- Chi tiết lớp: card ngữ cảnh và tab có biểu tượng; phần ngữ cảnh có thể cuộn khi chiều cao hạn chế.
- Sổ tay: banner buổi học; giữ hai giai đoạn Trước buổi / Sau buổi, tự lưu và xử lý lỗi hiện hữu.
- QR: khung trắng, viền và đổ bóng nhẹ; giữ cơ chế ẩn QR cũ, thời hạn và xác nhận chốt phiên.
- Cập nhật dùng font, màu, input, chip và card chung; giữ nguồn tin/nghiên cứu thật và bộ lọc hiện hữu.

## Điều chỉnh theo sản phẩm thật

Tên, học kỳ, sĩ số, lịch và số liệu lấy từ repository hiện có. Không sao chép số liệu Fall 2024, tỷ lệ chuyên cần, tiến độ 14/30, thông báo nội bộ, địa chỉ hỗ trợ hoặc chức năng đồng bộ mẫu của Stitch khi app không có dữ liệu/chức năng tương ứng. Giao diện co giãn theo nội dung, cỡ chữ và màn hình nên không cố định từng pixel như canvas.

Ảnh giảng đường chỉ dùng làm minh họa. Nút đăng nhập vẫn yêu cầu tài khoản đã được backend cấp quyền. Không thay backend hay quy định điểm danh. Không có deployment hoặc bản APK mới trong thay đổi này.

## Xác minh

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: 157 kiểm thử qua.
- Bộ ảnh tại `build/ui-previews/`: login, home, classes, timetable, students, live ở sáng/tối; dữ liệu fixture, không phải dữ liệu tài khoản thật.
- Bộ layout kiểm tra cỡ chữ 1.0/1.8; suite bổ sung có 2.0, màn ngang và tablet. Đã sửa tràn hàng sinh viên và header lớp ở chiều cao hạn chế.
- Kiểm thử motion cập nhật để xác minh trạng thái mở sẵn, thu gọn và mở lại danh sách buổi khác.
- Chưa kiểm tra trực tiếp trên thiết bị Android/iOS hoặc đăng nhập backend thật trong lần sửa này.

Tạo lại ảnh trên Windows:

```powershell
$env:FLUTTER_PREVIEW_FONTS='D:/development/flutter/bin/cache/artifacts/material_fonts'
flutter test --no-pub test/redesign_layout_test.dart --dart-define=CAPTURE_UI=true
```

Điều chỉnh đường dẫn material_fonts theo Flutter SDK trên máy.
