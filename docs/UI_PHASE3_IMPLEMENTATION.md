# UI đợt 3 — Lịch dạy và danh sách sinh viên

Triển khai phần P2 của UI_RESEARCH_PHASE2.md. Đây là đợt cải thiện hai luồng hiện có; các màn hình khác tiếp tục dùng design system hiện hành.

## Thay đổi

- Lịch dạy: đặt điều hướng tuần/ngày và Hôm nay trước các công cụ; nút nhập lịch thành thao tác phụ. Bộ lọc vẫn giữ học kỳ và môn đang chọn; thêm Xóa lọc môn chỉ xóa môn, giữ học kỳ. Nhãn ngày tăng từ 11 lên 13, bổ sung semantics ngày và số buổi.
- Sinh viên: thay thẻ lớn chứa mọi số đếm bằng hàng có tên, MSSV, tỷ lệ vắng, cảnh báo chữ và icon. Chạm hàng mở dialog lịch sử hiện có, bổ sung số lượt từng trạng thái và cơ sở tính để giữ đầy đủ thông tin.
- Chữ phụ trong tổng quan tăng lên 13–14. Nhãn ngưỡng trong màn này lấy từ AttendancePolicy đang dùng; thiếu cấu hình vẫn hiển thị trạng thái chờ cấu hình.
- Giữ tính toán, sắp xếp, bộ lọc, luồng dữ liệu và hành vi nghiệp vụ hiện hành.

## Kiểm tra

- flutter analyze --no-pub: không có lỗi/cảnh báo.
- flutter test: 146 test qua. Bổ sung kiểm tra lịch sử sinh viên, nhãn policy, xóa lọc môn giữ học kỳ và bố cục ở 360/375/390/412/430dp, ngang 844×390, sáng/tối, chữ đến 200%.
- flutter build apk --debug: thành công. Đây là kiểm tra biên dịch; không xác nhận đăng nhập/backend production.
- Render bằng fixture kiểm thử trong build/phase3-ui; kiểm tra trực quan lịch 360dp và hàng sinh viên chữ 200% dark mode. Fixture chỉ nằm trong test.
- git diff --check: qua.

Chưa nghiệm thu trên thiết bị thật, TalkBack hay với giảng viên thực tế. Chưa triển khai bố cục tablet hoặc thay đổi các luồng khác.
