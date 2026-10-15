# Bố cục và hiệu ứng UI

## Phạm vi đã triển khai

- Hôm nay: giữ buổi đang/sắp dạy nổi bật. Các buổi còn lại nằm trong mục mở rộng có số lượng, giúp phần việc đến hạn phía dưới dễ tiếp cận; vẫn mở được từng buổi và sổ tay.
- Lịch dạy: thời gian đứng trước slot, vạch màu theo nhóm nội dung, giảm padding cho chế độ compact; trạng thái hủy, trùng giờ và thao tác hiện hành vẫn hiển thị.
- Lớp: mã lớp nổi bật, môn và học kỳ/sĩ số phân cấp rõ; toàn bộ thẻ nhận thao tác chạm và ripple.
- Shell: fade nhẹ khi đổi tab, vẫn giữ IndexedStack để bảo toàn trạng thái. Giới hạn nội dung chính 760dp trên cửa sổ rộng.
- Điểm danh: fade khi đổi QR/Sinh viên; hàng sinh viên chỉ được làm nổi sau thay đổi status/notes từ dữ liệu đã tải, không chạy lại vì mỗi lần polling.
- Nhật ký: nhãn lưu và tiêu đề giai đoạn chuyển nhẹ. Nội dung form, controller và cơ chế autosave giữ nguyên.
- Công việc: phần cấu hình nhắc mở/thu nhẹ; bổ sung nhãn thời gian nhắc. Hoàn thành việc có phản hồi sau khi lưu và nút hoàn tác; hoàn tác chỉ áp dụng khi việc còn tồn tại và trạng thái chưa bị thay đổi tiếp.
- Chuyển trang Android/desktop dùng fade thống nhất; nền tảng Apple giữ transition mặc định.

## Quy tắc chuyển động

CampusEntrance chỉ vẽ child hiện tại, không giữ child cũ trong hiệu ứng thoát. QR hết hạn/mất quyền hoặc dữ liệu bị thay thế được gỡ ngay trong frame cập nhật. Trigger đổi không tạo key mới cho subtree, giữ State và vị trí cuộn. Hiệu ứng nội dung 180ms, thay đổi kích thước/màu 220ms; transition trang dùng thời lượng route của nền tảng.

Tôn trọng MediaQuery.disableAnimations và accessibleNavigation: nội dung hiện ngay, chuyển kích thước/màu tức thời. Không thêm thư viện animation.

## Kiểm tra

Kiểm thử bao gồm giữ nội dung nhập và vị trí cuộn khi chạy hiệu ứng, giảm chuyển động, gỡ nội dung nhạy cảm ngay, làm nổi thay đổi và hủy timer, mở các buổi còn lại, hoàn tác việc sau khi lưu. Giữ các regression về QR hết hạn, mất quyền, lỗi mạng và chốt phiên.

Render bằng fixture kiểm thử: build/phase3-ui, build/assistant-ui, build/ui-previews. Đã xem lịch 360dp, lớp và Today; bộ render kiểm tra cả chữ lớn, dark mode và ngang. Dữ liệu minh họa chỉ trong test.

Chưa kiểm tra chuyển động trên thiết bị thật, TalkBack hay hiệu năng frame bằng profiler. Chưa triển khai navigation rail/tablet hai cột.

Kết quả cuối: 152/152 test qua; analyze sạch; build APK debug thành công; 18 test render/luồng UI qua; git diff --check qua.
