# UI đợt 2 — Lớp học và Điểm danh

Ngày 15/10/2026. Triển khai hai mục P1 của UI_RESEARCH_PHASE2.md; các mục lịch dạy, danh sách sinh viên gọn và tablet tiếp tục là đề xuất.

## Trang lớp

- AppBar dùng mã lớp. Khối ngữ cảnh chung hiện môn, học kỳ và sĩ số nếu có, giữ ở cả bốn tab; thông tin lớp dài có tooltip. Không đổi dữ liệu thiếu thành sĩ số 0.
- Nhập sinh viên và ngoại lệ lịch/sửa sinh viên nằm trong menu có nhãn Công cụ lớp; ngoại lệ lịch vẫn chỉ hiện trong shared mode.
- Thẻ tổng quan không lặp lại danh tính lớp khi đã có khối ngữ cảnh chung. Các nơi sử dụng thẻ độc lập giữ thông tin như trước.
- Lỗi đọc lớp hoặc lớp không tồn tại không giữ lại header/công cụ với dữ liệu cũ. Controller và stream được phân biệt theo tài khoản/lớp; màn hình chỉ nhận profile giảng viên.

## Phiên điểm danh

- Hai chế độ Mã QR / Sinh viên; bộ chọn ghim khi cuộn. Mỗi chế độ giữ vị trí cuộn riêng; tìm kiếm và bộ lọc được giữ khi đổi chế độ. Phiên đã đóng mở mặc định phần sinh viên.
- AppBar hiện lớp/slot; khối chung có môn, phòng, trạng thái phiên, thời gian còn lại và tổng đã điểm danh trên số đủ điều kiện. Tổng mới hiển thị dấu — nếu thiếu dữ liệu thay vì giả định 0.
- Có nút phóng to/thu gọn QR ngay trong trang, không tạo modal giữ token cũ. Khi QR hết hạn, lỗi kết nối hoặc mất quyền, QR vẫn ẩn theo điều kiện hiện hành.
- Nút chốt phiên giữ ở đáy màn hình trong cả hai chế độ. Giữ xác nhận, chặn thao tác khi đang ghi/tải/lỗi và giữ editor có lý do/audit. Mất quyền vẫn xóa roster/token và dừng polling tự động.
- Không đổi API, thời hạn phiên/QR, cơ chế xác thực hoặc backend.

## Kiểm tra và giới hạn

- Kết quả cuối: `flutter analyze --no-pub` sạch; `flutter test` qua 138/138; `git diff --check` qua; build APK debug thành công. Bộ render riêng qua 8/8.
- Test mới kiểm tra giữ tìm kiếm/bộ lọc giữa hai chế độ, dữ liệu cũ không cho sửa/hiện QR, trạng thái ban đầu của phiên đóng, xác nhận chốt trước khi gọi API, ngữ cảnh lớp xuyên tab, lỗi/mất quyền và lớp không tồn tại.
- Render và kiểm tra 360×900, chữ 1.0x và 2.0x; 844×390, chữ 2.0x; 800×1000, chữ 1.8x; có sáng/tối. Ảnh giả lập tại `build/phase2-ui/`, không phải dữ liệu giảng viên thật.
- Các test regression cũ đọc roster được cập nhật để chọn chế độ Sinh viên trước. Không bỏ các kiểm tra QR hết hạn, polling hoặc mất quyền.
- Log tại `artifacts/phase2-ui-analyze.log`, `phase2-ui-tests.log`, `phase2-ui-focused.log`, `phase2-ui-visual.log`, `phase2-ui-build.log`.
- Chưa thử camera/QR scan thật, TalkBack, mất mạng trên thiết bị thật hoặc Google login cho đợt này. APK debug không có define chỉ dùng xác nhận biên dịch; cần cấu hình shared theo README để chạy backend thật.
