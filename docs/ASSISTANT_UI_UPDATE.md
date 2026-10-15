# UI Hôm nay và Sổ tay — 15/10/2026

## Thay đổi

- Hôm nay chọn buổi đang diễn ra hoặc buổi sắp tới trong học kỳ đã chọn, bỏ qua buổi hủy/đã chốt/đã qua giờ. Thẻ ưu tiên dùng nền cam, giữ phòng, giờ, điểm danh và lối vào sổ tay. Các buổi khác vẫn truy cập được; tổng số buổi không cộng buổi đã hủy.
- Việc đến hạn hiển thị tối đa ba việc chưa xong, gồm quá hạn và đến hết ngày Việt Nam; chạm mở việc tương ứng. Dữ liệu cá nhân vẫn truy cập được khi lịch đang tải hoặc lỗi. Không tự đánh dấu buổi đã dạy từ việc không có phiên.
- Hôm nay cập nhật thời gian mỗi phút khi màn hình còn tồn tại.
- Sổ tay chia Trước buổi/Sau buổi, có khối thông tin và trạng thái lưu, tiến độ checklist; công cụ sao chép kế hoạch/nhắc việc nằm trong mục thu gọn. Với chữ lớn, bộ chọn giai đoạn chuyển sang dropdown để tránh tràn.
- Nội dung ghi chú lần sau có thể thêm vào mục tiêu một sổ tay có ngày sau, cùng lớp/môn/học kỳ. Chỉ chọn trong sổ tay đã mở trên máy; không tự suy đoán lịch hoặc tạo buổi mới. Giữ mục tiêu đích, nội dung sau buổi và ghi chú nguồn; cùng một nội dung từ cùng nguồn không được chép lặp. Mở sổ tay mới tạo bản ghi local rỗng để có thể chọn làm buổi đích.
- Dữ liệu cá nhân vẫn chỉ lưu trên máy, chưa đồng bộ backend.

## Kiểm tra

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test`: 130/130 qua. Test mới kiểm tra chọn buổi ưu tiên, lọc việc đã xong, chuyển giai đoạn sổ tay và chuyển nội dung không trùng/sai lớp/sai ngày.
- Render và xem ảnh ở 360px, sáng/tối, chữ 1.0x/1.8x. Ảnh dùng dữ liệu giả lập tại `build/assistant-ui/`, không phải ảnh từ tài khoản thật.
- `git diff --check`: qua.
- Log: `artifacts/assistant-ui-analyze.log`, `assistant-ui-tests.log`, `assistant-ui-visual.log`, `assistant-ui-build.log`.

Chưa kiểm tra thao tác trên thiết bị thật hoặc đăng nhập backend thật cho đợt UI này. Build APK debug không có cấu hình shared chỉ xác nhận khả năng biên dịch.
